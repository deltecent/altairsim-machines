#!/usr/bin/env python3
# Build an MP/M II 2.1 disk for an Altair with an 88-DCDD, an 88-2SIO and an 88-VI/RTC, or
# a CompuPro System Support 1 in place of the 88-VI/RTC.
#
#   make-mpm2-disk.py [--keep] [--xios RESXIOS|SS1XIOS] OUT.DSK
#
# --xios names the XIOS source on BUILD.DSK. RESXIOS (the default) is for the 88-VI/RTC
# (mpm2.toml), and SS1XIOS is for the System Support 1 (mpm2-ss1.toml).
#
# OUT.DSK is an 8" 88-DCDD MP/M II system disk. The DBL PROM boots it straight into MP/M II:
# BOOT on track 0 loads MPMLDR from the system tracks, and MPMLDR loads MPM.SYS.
#
# The script does the steps of "Build the system disk" in README.md, on the machine of
# build.toml, with the disks of this folder: CPM22.DSK on A:, BUILD.DSK on B:, and then a
# blank disk on B:. A person can do the same steps on an Altair with two 8" drives.
# The script types each command and checks what CP/M prints. Every disk step runs in CP/M.
# R, W and HDIR on CPM22.DSK move files between the host and the disks, through the host
# bridge (hb0) of the build machine. On a real Altair, PCGET and PCPUT do the same.
#
# The simulator is the altairsim on PATH, or the one that $ALTAIRSIM names.
#
# Every step runs in the simulator, through `altairsim <machine> --mcp`:
#
#   1. The machine of build.toml boots a copy of CPM22.DSK on A:, with a copy of BUILD.DSK
#      on B:. On B:, RMAC and LINK make RESXIOS.SPR from the XIOS source. ASM makes
#      LDRBIOS.HEX, and DDT puts it into MPMLDR.COM. ASM makes BOOT.HEX, the cold start
#      loader. GENSYS makes MPM.SYS. Its answers are in GENSYS_ANSWERS below. ASM and LOAD
#      make AFORMAT.COM.
#      PIP copies the new files to A:.
#   2. A blank disk takes the place of BUILD.DSK on B:, and AFORMAT formats it. PIP copies
#      MPM.SYS first, so that it is at the front of the disk. R copies the commands of DRI
#      disk 1 (the .PRL and .COM files) from MPMII_1/ to it. PIP copies MPMLDR.COM, which
#      replaces the one of DRI, and AFORMAT.COM. STAT makes the commands read-only and
#      gives them the system attribute, so the users of the other consoles can run them.
#   3. DDT puts BOOT and MPMLDR.COM into the SYSGEN image at 0900h, and SYSGEN writes it
#      to the system tracks of B: (section 1.5.1 of the MP/M II System Implementor's
#      Guide).
#   4. W copies BOOT.HEX, MPMLDR.COM and MPM.SYS of A:, and MPMLDR.COM and MPM.SYS of the
#      new disk, to the work directory. The system tracks of the new disk must hold BOOT
#      and MPMLDR.COM, and its MPM.SYS must be the one on A:. The DBL PROM boots the disk
#      into MP/M II.
#
# Exit status: 0 when OUT.DSK is written, 1 when a step fails. --keep keeps the work
# directory, with the transcript of every session in it.
#
# Revision history
# 1.0  23 October 2026  P. Linstruth
#      First version

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile

SIM = os.environ.get("ALTAIRSIM") or shutil.which("altairsim")
SRC = os.path.dirname(os.path.abspath(__file__))
BUILD_TOML = os.path.join(SRC, "build.toml")
CPM22_DSK = os.path.join(SRC, "CPM22.DSK")
BUILD_DSK = os.path.join(SRC, "BUILD.DSK")
DISK1 = os.path.join(SRC, "MPMII_1")
# The commands of DRI disk 1 in MPMII_1/, by type: the 32 files of Figure 1-1 of the
# MP/M II User's Guide. The .SPR, .RSP and .BRS files are only for GENSYS, which has
# put them into MPM.SYS. The folder also holds MPMII_1.IMD.
DISK1_TYPES = ("PRL", "COM")
# GENSYS asks its questions in an order that depends on the answers. Each prompt is
# matched by its text. A prompt that is not in this list stops the build. A list of
# answers is for a prompt that GENSYS asks more than once, and is used in order.
#
# Top page FE: the machine has RAM to FEFFh and the DBL PROM at FF00h. Two consoles
# (2SIO ports A and B). No banks, no Z80. RST 6 for the MP/M debugger: RST 5 is the RTC.
# No SPOOL, because the machine has no printer, and no SCHED.
#
# The memory segments: the first entry is the operating system, from 7600h, and GENSYS
# gives it. The two user segments share 0000h-75FFh equally, 3Bh pages each, one for
# each console. PIP.PRL needs 32h pages with its buffers, so either console can run PIP
# while the other console runs a command. A .COM file runs only in the segment at 0000h.
# SDIR.PRL needs 4Dh pages and does not fit in a segment.
#
# SS1XIOS is one page longer than RESXIOS (it reads the clock), so the operating system
# starts at 7500h and each user segment is 3Ah pages (SEGMENTS).
GENSYS_ANSWERS = [
    (r"Use SYSTEM\.DAT for defaults", "N"),
    (r"Top page of operating system", "FE"),
    (r"Number of TMPs", "#2"),
    (r"Number of Printers", "#1"),
    (r"Breakpoint RST", "06"),
    (r"Enable Compatibility Attributes", "N"),
    (r"Add system call user stacks", "Y"),
    (r"Z80 CPU", "N"),
    (r"Number of ticks/second", "#60"),
    (r"System Drive", "A:"),
    (r"Temporary file drive", "A:"),
    (r"Maximum locked records/process", "#16"),
    (r"Total locked records/system", "#32"),
    (r"Maximum open files/process", "#16"),
    (r"Total open files/system", "#32"),
    (r"Bank switched memory", "N"),
    (r"Number of user memory segments", "#2"),
    (r"Dayfile logging at console", "N"),
    (r"Accept new system data page entries", "Y"),
    (r"ABORT +RSP \(N\)", "Y"),
    (r"MPMSTAT +RSP \(N\)", "Y"),
    (r"SCHED +RSP \(N\)", "N"),
    (r"SPOOL +RSP \(N\)", "N"),
    (r"Base,size,attrib", None),    # SEGMENTS, by the XIOS
    (r"Accept new memory segment table entries", "Y"),
]
SEGMENTS = {
    "RESXIOS": ["", "00,3B,00", "3B,3B,00"],
    "SS1XIOS": ["", "00,3A,00", "3A,3A,00"],
}


class BuildError(Exception):
    pass


class Guest:
    """One `altairsim <machine> --mcp` session. Every call is logged."""

    def __init__(self, machine, log):
        self.log = open(log, "w")
        self.p = subprocess.Popen([SIM, machine, "--mcp"], stdin=subprocess.PIPE,
                                  stdout=subprocess.PIPE, text=True, bufsize=1)
        self.n = 0
        self._call("initialize", {"protocolVersion": "2024-11-05", "capabilities": {},
                                  "clientInfo": {"name": "make-mpm2-disk", "version": "1"}})
        self._send({"jsonrpc": "2.0", "method": "notifications/initialized"})

    def _send(self, msg):
        self.p.stdin.write(json.dumps(msg) + "\n")
        self.p.stdin.flush()

    def _call(self, method, params):
        self.n += 1
        self._send({"jsonrpc": "2.0", "id": self.n, "method": method, "params": params})
        while True:
            line = self.p.stdout.readline()
            if not line:
                raise BuildError("altairsim exited")
            msg = json.loads(line)
            if msg.get("id") == self.n:
                break
        if "error" in msg:
            raise BuildError("%s: %s" % (method, msg["error"]))
        return msg["result"]

    def _tool(self, name, args):
        res = self._call("tools/call", {"name": name, "arguments": args})
        text = "".join(c.get("text", "") for c in res.get("content", []))
        self.log.write("--- %s %s\n%s\n" % (name, json.dumps(args), text))
        self.log.flush()
        why = re.search(r"\[stopped: (\w+)\]\s*$", text)   # the run tool's last line
        if not why:
            return text, None
        return text[:why.start()], why.group(1)

    def mon(self, command):
        text, _ = self._tool("monitor", {"command": command})
        return text

    def run(self, until, input=None, start=None, timeout_ms=60000):
        """Type `input`, run until `until` is printed, and return what was printed.
        Anything else that stops the run is an error."""
        args = {"until": until, "timeout_ms": timeout_ms}
        if input is not None:
            args["input"] = input
        if start is not None:
            args["from"] = start
        text, why = self._tool("run", args)
        if why != "match":
            raise BuildError("waiting for %r after %r: stopped (%s)\n%s"
                             % (until, input, why, text[-800:]))
        return text

    def run_any(self, input, timeout_ms=60000):
        """Type `input` and run until the guest waits for the keyboard."""
        args = {"input": input, "until": "\x00never\x00", "timeout_ms": timeout_ms}
        return self._tool("run", args)

    def close(self):
        self.p.stdin.close()
        self.p.wait()
        self.log.close()


def check_assembly(text, what):
    """RMAC and ASM print each line that has an error. A clean run prints only the
    banner, the next free address, the use factor and END OF ASSEMBLY."""
    if "END OF ASSEMBLY" not in text:
        raise BuildError("%s did not finish:\n%s" % (what, text))
    lines = [l for l in text.replace("\r", "").split("\n") if l.strip()]
    body = [l for l in lines[1:] if not re.match(
        r"^(CP/M (RMAC )?ASSEM.*|[0-9A-F]{4}|[0-9A-F]{3}H USE FACTOR|END OF ASSEMBLY|[A-Z]>)$",
        l.strip())]
    if body:
        raise BuildError("%s reported errors:\n%s" % (what, "\n".join(body)))


def w_host(g, cpmfile, hostfile):
    """Copy a file from a disk to the work directory with W."""
    text = g.run("\r\nA>", "W %s %s\r" % (cpmfile, hostfile), timeout_ms=600000)
    if "records," not in text or re.search(r"cannot|no such|error", text, re.I):
        raise BuildError("W %s failed:\n%s" % (cpmfile, text))


def build(work, xios):
    """Steps 1 to 3: build MPM.SYS, the loader and BOOT on BUILD.DSK, then make the new
    system disk on B:."""
    a = os.path.join(work, "a.dsk")
    b = os.path.join(work, "build.dsk")
    new = os.path.join(work, "new.dsk")
    shutil.copy(CPM22_DSK, a)
    shutil.copy(BUILD_DSK, b)
    # The host bridge sees the work directory only. R reads the files of DRI disk 1 from
    # MPMII_1/ in it, and W writes the files for step 4 to A/ and NEW/. The CCP makes the
    # names upper case.
    disk1 = os.path.join(work, "MPMII_1")
    os.makedirs(disk1)
    count = {}
    for n in sorted(os.listdir(DISK1)):
        t = n.rsplit(".", 1)[-1].upper()
        if t in DISK1_TYPES:
            shutil.copy(os.path.join(DISK1, n), disk1)
            count[t] = count.get(t, 0) + 1
    for d in ("A", "NEW"):
        os.makedirs(os.path.join(work, d))
    g = Guest(BUILD_TOML, os.path.join(work, "2-build.log"))
    try:
        g.mon("SET CONSOLE UPPER=OFF")
        g.mon('SET hb0 hostdir="%s"' % work)
        for drive, dsk in (("drive0", a), ("drive1", b)):
            text = g.mon('MOUNT dsk0:%s "%s"' % (drive, dsk))
            if "mounted" not in text:
                raise BuildError("MOUNT %s failed:\n%s" % (dsk, text))
        g.run("\r\nA>", start=0xFF00)
        # BUILD.DSK holds both XIOS sources. The build needs the space of the other one.
        for other in VERIFY_TICK:
            if other != xios:
                text = g.run("\r\nA>", "ERA B:%s.ASM\r" % other)
                if "NO FILE" in text:
                    raise BuildError("%s.ASM is not on BUILD.DSK" % other)
        g.run("\r\nB>", "B:\r")

        # The tools are on A:, and the files they make go to B:. $PZ SZ: no listing and
        # no symbol file, so that every file fits on B:.
        # GENSYS reads the XIOS from RESXIOS.SPR, whatever the name of its source.
        check_assembly(g.run("\r\nB>", "A:RMAC %s $PZ SZ\r" % xios, timeout_ms=600000),
                       "RMAC " + xios)
        text = g.run("\r\nB>", "A:LINK RESXIOS=%s[OS]\r" % xios, timeout_ms=600000)
        if "USE FACTOR" not in text or "UNDEFINED" in text.upper():
            raise BuildError("LINK %s failed:\n%s" % (xios, text))

        # Section 1.2 of the MP/M II System Implementor's Guide: overlay the LDRBIOS at
        # 1700h, then save 26 pages (0100h-1AFFh).
        check_assembly(g.run("\r\nB>", "A:ASM LDRBIOS.BBZ\r", timeout_ms=600000),
                       "ASM LDRBIOS")
        g.run("\r\n-", "A:DDT MPMLDR.COM\r")
        g.run("\r\n-", "ILDRBIOS.HEX\r")
        text = g.run("\r\n-", "R\r")
        m = re.search(r"NEXT\s+PC\s+([0-9A-F]{4})", text)
        if not m or not 0x1780 <= int(m.group(1), 16) <= 0x1A00:
            raise BuildError("DDT did not load LDRBIOS.HEX below 1A00h:\n" + text)
        g.run("\r\nB>", "G0\r")
        g.run("\r\nB>", "SAVE 26 MPMLDR.COM\r")

        check_assembly(g.run("\r\nB>", "A:ASM BOOT.BBZ\r", timeout_ms=600000), "ASM BOOT")

        gensys(g, [(p, SEGMENTS[xios] if a is None else a) for p, a in GENSYS_ANSWERS])

        check_assembly(g.run("\r\nB>", "A:ASM AFORMAT.BBZ\r", timeout_ms=600000),
                       "ASM AFORMAT")
        text = g.run("\r\nB>", "A:LOAD AFORMAT\r")
        if "BYTES READ" not in text:
            raise BuildError("LOAD AFORMAT failed:\n" + text)

        for n in ("MPM.SYS", "MPMLDR.COM", "BOOT.HEX", "AFORMAT.COM"):
            text = g.run("\r\nB>", "A:PIP A:=%s[V]\r" % n, timeout_ms=600000)
            if re.search(r"ERROR|FULL", text):
                raise BuildError("PIP A:=%s failed:\n%s" % (n, text))

        # Step 2: a blank disk takes the place of BUILD.DSK, and AFORMAT formats it. Ctrl-C
        # makes CP/M log it in.
        g.run("\r\nA>", "A:\r")
        text = g.mon('MOUNT dsk0:drive1 "%s" CREATE' % new)
        if "mounted" not in text:
            raise BuildError("MOUNT %s CREATE failed:\n%s" % (new, text))
        g.run("Ready (Y/N)?", "AFORMAT B:\r")
        text = g.run("Format another (Y/N)?", "Y", timeout_ms=600000)
        if re.search(r"FAIL|Retry", text):
            raise BuildError("AFORMAT B: failed:\n" + text)
        g.run("Put CP/M disk in A:\r\nReady (Y/N)?", "N")
        g.run("\r\nA>", "Y")
        g.run("\r\nA>", "\x03")
        # The commands of DRI disk 1 go on after MPM.SYS. The new MPMLDR.COM then replaces
        # the one of DRI. R writes to the current drive.
        pip_b(g, "MPM.SYS")
        g.run("\r\nB>", "B:\r")
        for t in DISK1_TYPES:
            text = g.run("\r\nB>", "A:R MPMII_1/*.%s\r" % t, timeout_ms=600000)
            if text.count(" -> ") != count[t] or re.search(r"cannot|no such|error", text, re.I):
                raise BuildError("R MPMII_1/*.%s failed:\n%s" % (t, text))
        g.run("\r\nA>", "A:\r")
        pip_b(g, "MPMLDR.COM")
        pip_b(g, "AFORMAT.COM")
        # MP/M II starts console n in user n. A command in user 0 runs from every user
        # only when it has the system attribute. Section 7.6 of the MP/M II User's Guide
        # also makes the commands read-only. AFORMAT.COM is one more .COM file.
        for t, n in (("PRL", count["PRL"]), ("COM", count["COM"] + 1)):
            for attr, said in (("$R/O", "set to R/O"), ("$SYS", "set to SYS")):
                text = g.run("\r\nA>", "STAT B:*.%s %s\r" % (t, attr), timeout_ms=600000)
                if text.count(said) != n:
                    raise BuildError("STAT B:*.%s %s did not set %d files:\n%s"
                                     % (t, attr, n, text))

        # Step 3: section 1.5.1 of the guide, for the SYSGEN of the Altair CP/M. Its image
        # starts at 0900h, one 128-byte sector after another from track 0 sector 0. The
        # DBL PROM reads BOOT from sectors 0 and 2, and MPMLDR starts at sector 3 (0A80h).
        # MPMLDR.COM and 0A80h overlap, so it moves through 3000h.
        g.run("\r\n-", "DDT MPMLDR.COM\r")
        for c in ("M100,1AFF,3000", "M3000,49FF,A80", "IBOOT.HEX", "R900", "M980,9FF,A00"):
            g.run("\r\n-", c + "\r")
        g.run("\r\nA>", "G0\r")
        g.run("(or RETURN to skip)", "SYSGEN\r")
        g.run("(or RETURN to reboot)", "\r")
        g.run("then type RETURN", "B")
        g.run("Function complete\r\nDestination drive name (or RETURN to reboot)", "\r")
        g.run("\r\nA>", "\r")
        text = g.run("\r\nA>", "STAT B:\r")
        g.run("\r\nA>", "\r")

        # Step 4 reads these files on the host.
        for n in ("BOOT.HEX", "MPMLDR.COM", "MPM.SYS"):
            w_host(g, "A:" + n, "A/" + n)
        for n in ("MPMLDR.COM", "MPM.SYS"):
            w_host(g, "B:" + n, "NEW/" + n)
    finally:
        g.close()
    space = re.search(r"Bytes Remaining On B: *(\d+k)", text)
    return new, space.group(1) if space else "?"


def pip_b(g, name):
    """Copy a file from A: to the new disk on B:, and verify it."""
    text = g.run("\r\nA>", "PIP B:=%s[V]\r" % name, timeout_ms=600000)
    if re.search(r"ERROR|FULL", text):
        raise BuildError("PIP B:=%s failed:\n%s" % (name, text))


def gensys(g, answers):
    """Answer each GENSYS question by its text. Print the memory map it ends with."""
    text, _ = g.run_any("GENSYS\r")
    transcript = text
    asked = {}
    for _ in range(80):
        tail = text.replace("\r", "").rstrip("\n").split("\n")[-1]
        if re.search(r"^[A-Z]>$", tail.strip()):
            break
        for pattern, answer in answers:
            if re.search(pattern, tail):
                if isinstance(answer, list):
                    i = asked.get(pattern, 0)
                    if i >= len(answer):
                        raise BuildError("GENSYS asked again:\n" + transcript)
                    asked[pattern] = i + 1
                    answer = answer[i]
                if callable(answer):
                    answer = answer(transcript)
                text, _ = g.run_any(answer + "\r")
                transcript += text
                break
        else:
            raise BuildError("GENSYS asked something this script does not know:\n" + tail)
    else:
        raise BuildError("GENSYS did not finish")
    if re.search(r"error|bad character", transcript, re.I):
        raise BuildError("GENSYS reported an error:\n" + transcript)
    for line in transcript.replace("\r", "").split("\n"):
        if re.match(r"^ \S.{6,}\s[0-9A-F]{4}H\s+[0-9A-F]{4}H", line):
            print("   " + line)


# The FCB that BOOT leaves at 005Ch for MPMLDR. BOOT.ASM says why.
BOOT_FCB = b"\0" + b" " * 11 + b"\0" * 4


def read_hex(path):
    """The bytes of an Intel HEX file, as {address: byte}."""
    mem = {}
    with open(path) as f:
        for line in f:
            line = line.strip()
            if not line.startswith(":"):
                continue
            rec = bytes.fromhex(line[1:])
            if rec[3] != 0:
                continue
            addr = rec[1] << 8 | rec[2]
            for i, b in enumerate(rec[4:4 + rec[0]]):
                mem[addr + i] = b
    return mem


def boot_image(hexfile):
    """BOOT must fit in the 256 bytes that the DBL PROM loads, and leave the FCB at
    005Ch as it is."""
    mem = read_hex(hexfile)
    if max(mem) > 0xFF:
        raise BuildError("BOOT is longer than 256 bytes: it ends at %04XH" % max(mem))
    if any(mem.get(0x5C + i) != c for i, c in enumerate(BOOT_FCB)):
        raise BuildError("BOOT changes the FCB at 005CH")
    return mem


# The 88-DCDD disk image: 77 tracks of 32 sectors of 137 bytes. A sector of a system track
# (tracks 0-5) has its 128 bytes of data at offset 3.
SECTOR, SECTORS, SYSDATA = 137, 32, 3


def system_sectors(dsk, first, count):
    """The data of `count` sectors of the system tracks, from track 0 sector `first`."""
    with open(dsk, "rb") as f:
        d = f.read()
    return b"".join(d[n * SECTOR + SYSDATA:n * SECTOR + SYSDATA + 128]
                    for n in range(first, first + count))


# The machine that boots the new disk: RAM to FEFFh, the DBL PROM and the board that gives
# the tick, as in mpm2.toml or mpm2-ss1.toml. 2SIO port B is not connected. The processor runs flat out, not at 2 MHz: the
# guest sees the same emulated time, and the boot takes less than a second, not 15.
VERIFY_TOML = """[machine]
name = "mpm2-verify"
base = "default"

[[board]]
id = "mem0"
  [[board.region]]
  type = "ram"
  at   = 0000
  size = 0xFF00
  [[board.region]]
  type  = "rom"
  at    = FF00
  mount = "builtin:dbl"
"""
VERIFY_TICK = {
    "RESXIOS": """
[[board]]
type          = "virtc"
id            = "vi0"
port          = 0xFE
rtc_source    = "line"
rtc_divide    = 1
rtc_interrupt = "vi5"
""",
    "SS1XIOS": """
[[board]]
type = "ss1"
id   = "ss0"
base = 0x50
""",
}


def verify(work, new, xios):
    """Step 4: check the system tracks and MPM.SYS of the new disk, and boot it into
    MP/M II. W of step 3 put the files of A: in A/ and those of the new disk in NEW/."""
    got_a, got_new = os.path.join(work, "A"), os.path.join(work, "NEW")
    for n in ("MPMLDR.COM", "MPM.SYS"):
        with open(os.path.join(got_a, n), "rb") as f1, open(os.path.join(got_new, n), "rb") as f2:
            if f1.read() != f2.read():
                raise BuildError("%s on the new disk is not the file the build made" % n)
    boot = boot_image(os.path.join(got_a, "BOOT.HEX"))
    with open(os.path.join(got_a, "MPMLDR.COM"), "rb") as f:
        ldr = f.read()
    tracks = system_sectors(new, 0, 3)
    if any(tracks[i if i < 0x80 else i + 0x80] != b for i, b in boot.items()):
        raise BuildError("sectors 0 and 2 of track 0 do not hold BOOT")
    if system_sectors(new, 3, len(ldr) // 128) != ldr:
        raise BuildError("the system tracks do not hold MPMLDR.COM")
    print("  ok    the system tracks hold BOOT and MPMLDR.COM")
    print("  ok    MPM.SYS (%d bytes) on the new disk is the one GENSYS made"
          % os.path.getsize(os.path.join(got_new, "MPM.SYS")))

    machine = os.path.join(work, "verify.toml")
    with open(machine, "w") as f:
        f.write(VERIFY_TOML + VERIFY_TICK[xios])
    g = Guest(machine, os.path.join(work, "3-verify.log"))
    try:
        g.mon("SET CONSOLE UPPER=OFF")
        g.mon('MOUNT dsk0:drive0 "%s"' % new)
        text = g.run("\r\n0A>", start=0xFF00, timeout_ms=120000)
        if "MP/M II V2.1 Loader" not in text:
            raise BuildError("the disk did not boot MPMLDR:\n" + text)
    finally:
        g.close()
    print("  ok    the disk boots MP/M II")


def main():
    ap = argparse.ArgumentParser(description="Build an MP/M II disk for the Altair.")
    ap.add_argument("--keep", action="store_true", help="keep the work directory")
    ap.add_argument("--xios", choices=sorted(VERIFY_TICK), default="RESXIOS",
                    help="the XIOS source on BUILD.DSK (default RESXIOS)")
    ap.add_argument("out", help="the 88-DCDD disk image to write")
    args = ap.parse_args()
    if not SIM or not os.access(SIM, os.X_OK):
        sys.exit("make-mpm2-disk: no altairsim on PATH. Set ALTAIRSIM=/path/to/altairsim.")
    for f in (BUILD_TOML, CPM22_DSK, BUILD_DSK, DISK1):
        if not os.path.exists(f):
            sys.exit("make-mpm2-disk: no %s." % f)

    work = tempfile.mkdtemp(prefix="mpm2-")
    ok = False
    try:
        print("1-3. build MPM.SYS (%s), MPMLDR.COM, BOOT and AFORMAT.COM on BUILD.DSK, copy them"
              % args.xios)
        print("     and the commands of MPMII_1/ to a blank disk, and SYSGEN it (build.toml)")
        new, space = build(work, args.xios)
        print("4. check the new disk and boot it")
        verify(work, new, args.xios)
        shutil.copy(new, args.out)
        print("  wrote %s (%s free)" % (args.out, space))
        ok = True
    except BuildError as e:
        print("make-mpm2-disk: %s" % e, file=sys.stderr)
    finally:
        if args.keep or not ok:
            print("  work directory: %s" % work, file=sys.stderr)
        else:
            shutil.rmtree(work)
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()
