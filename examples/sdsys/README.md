# The SD Systems SBC-200: a Z80 single-board computer

The **SD Systems SBC-200** was a complete computer on one S-100 board. It has a 4 MHz Z80
processor, an Intel 8251 serial console, a Z80-CTC baud generator, a parallel port, RAM and
sockets for boot PROMs. The board is the bus master of the machine. It shipped with the
**SD/MS monitor** in EPROM. With a VersaFloppy controller it booted SDOS or CP/M.

This directory has five machine files:

| Machine file | What it is |
|---|---|
| `sbc200.toml` | The SBC-200 and its monitor, on a serial console. |
| `sdos.toml` | The same machine with a VersaFloppy II. It boots **SDOS**. |
| `cpm.toml` | The same machine with 64K of RAM. It boots **SD Systems CP/M 2.2**. |
| `sbc200v.toml` | The SBC-200 and its monitor, on a **VDB-8024** video console. |
| `sdosv.toml` | The video machine with a VersaFloppy II. It boots **SDOS**. |

```
cd examples/sdsys
altairsim sbc200.toml
(press Enter)   ->   .
```

`sbc200.toml` is a small change to the built-in `sbc200` machine (`altairsim sbc200`). It has
the 4 MHz Z80, the 8251 console at ports 7C and 7D, the **MSMONR21** monitor in EPROM at E000
and the SD **DDBIOS** disk BIOS at F000. RAM fills the rest of the 64K.

## Press Enter to get the prompt

**The monitor prints nothing until you press Enter. This is correct for the real board.** The
SBC-200 connects the receive-data line of the 8251 to its /DSR input. MSMONR21 uses this to
**detect your baud rate**. After a reset it waits, and then it measures the start bit of the
first character you type (a carriage return). It reads status bit 7 in a tight loop. When you
press Enter, the monitor matches your speed and prints its `.` prompt.

The simulator models this line in emulated processor time. The original ROM detects the baud
rate on the console without any change. If the machine seems to stop at startup, press Enter.

## The monitor

At the `.` prompt, MSMONR21 is a full Z80 monitor. It can display and change memory, fill,
move and search memory, read and write I/O ports, set breakpoints, single-step and do hex
arithmetic. These commands are a good start:

```
.D E000 E01F        display the monitor ROM, in hex and ASCII
.E 8000             examine and change memory at 8000
.H 1234 0100        hex arithmetic: the sum, then the difference
```

Type `.` to stop a command and return to the prompt.

## Boot SDOS

`sdos.toml` adds a **VersaFloppy II** floppy controller. Drive A holds a bootable SDOS master
disk. At the monitor prompt, type `C` and press Enter to cold-boot the operating system:

```
cd examples/sdsys
altairsim sdos.toml
(press Enter)   ->   .
C (Enter)       ->   cold-boot SDOS from drive A
```

```
32K SD-OS Version 1.8B
DELTEC ENTERPRISES LLC

[A]
```

`[A]` is the SDOS prompt. The other disk commands of the monitor also work. `R` and `W` read and
write sectors of 128 or 256 bytes. `Z` formats a diskette.

The disk is `SDOS-18B-SSDDR-256-32K-MASTER.DSK`. It is an 8″ single-sided, double-density image
with 256-byte sectors (26 sectors on each of 77 tracks). It is made for a 32K system. The
machine mounts it **read/write**, so SDOS can save files. To restore the master after a change,
run `git checkout` on the file.

## Boot CP/M 2.2

`cpm.toml` boots **SD Systems CP/M 2.2** from the same VersaFloppy II. It uses two parts of the
SBC-200 that SDOS does not use:

```
cd examples/sdsys
altairsim cpm.toml
(press Enter)   ->   .
C (Enter)       ->   cold-boot CP/M from drive A
```

```
64k CP/M vers 2.2 for MS-610
COMPUTING INFORMATION SCIENCES

A>
```

`A>` is the CP/M prompt. Type `DIR` to show the directory. CP/M differs from SDOS in two ways:

- **The keyboard is interrupt-driven.** The console driver of the CP/M CBIOS reads input only
  through a Z80 mode-2 vectored interrupt. The RxRDY line of the 8251 triggers channel 1 of the
  Z80-CTC on the SBC. The CTC gives the vector byte `0x82`, which points to the keyboard
  handler. SDOS polled the keyboard, so it booted without interrupts. CP/M cannot. Each key you
  type at `A>` arrives through this interrupt.
- **The onboard PROM switches out.** This machine has a full **64K** of RAM. The monitor (E000)
  and the DDBIOS (F000) are in the boot-PROM sockets of the SBC, and they hide the RAM under
  them. When the CP/M cold boot has loaded the system into high memory, it does `OUT 7F,3`.
  This removes the PROM from the memory map, and the 64K of RAM under it becomes the memory of
  CP/M. In `sbc200.toml` and `sdos.toml`, the ROMs are on the memory board, and nothing
  switches out.

The disk is `SD-CPM22R4-SSDDR-256-64K.DSK`. It has the same 8″ double-density format with
256-byte sectors as the SDOS master. It is made for a 64K system. The machine mounts it
**read/write**. A CP/M that is made for 32K loads below the PROM, so it does not need the
switch-out.

## A video console instead of a serial terminal

`sbc200v.toml` is the same machine with the **SD Systems VDB-8024** video board as its console.
The 8251 serial port is not the console. The machine boots the video build of the monitor
(**SDMONV21**). The monitor prints its `.` prompt on an 80x24 screen. You do not press Enter
first, because the VDB is a parallel-handshake terminal. It has no baud rate to measure.

```
cd examples/sdsys
altairsim sbc200v.toml
.               <- the monitor prompt, ON THE VIDEO SCREEN
```

With SDL3, the screen is a window with the character font of the board. Keys that you type in
the window or in the terminal both reach the monitor. The commands are the same as on the
serial machine. The video screen shows the text. The terminal does not.

`sdosv.toml` boots **SDOS on the video console**. It is the video version of `sdos.toml`. It
mounts `SDOS-18B-SSDDV-256-32K.DSK`, the video build of the SDOS master, in drive A.

```
cd examples/sdsys
altairsim sdosv.toml
.               <- the monitor prompt, ON THE VIDEO SCREEN
C (Enter)       <- cold-boot SDOS from drive A
[A]             <- SDOS is running; type in the video window
```

**The video keyboard is interrupt-driven.** The monitor polls the VDB keyboard. It starts and
takes the `C` command without an interrupt. SDOS does not poll. The video CBIOS of SDOS reads
the console under a Z80 mode-2 interrupt. The keyboard strobe of the VDB is strapped to S-100
line **VI2** (`interrupt = "vi2"` on the board). The Z80-CTC of the SBC-200 changes this into
the mode-2 vector `0x02`, and the keyboard handler of the CBIOS reads the byte. Without the
interrupt, the monitor works but a booted operating system never sees a key. The serial
console of CP/M uses the same path with the vector `0x82`.

## Test it

`tests/test-sdsys.sh` boots `sbc200.toml`, `sdos.toml` and `cpm.toml`. It checks the monitor
prompt, the SDOS banner and prompt, and the CP/M banner, prompt and a directory entry. The two
video machines write to the video screen. The test does not boot them.

## What is not here yet

The serial console, the video console, the VersaFloppy disk, the keyboard interrupt of SDOS and
CP/M (on the 8251 and on the VDB-8024) and the memory switch-out of the SBC-200 all work. The
simulator models the Z80-CTC only as far as these keyboard interrupts need. Its baud-generator
and timer channels cannot be seen at full speed. The reset auto-start jump is replaced by
`startup = ["RUN E000"]`. The real board starts the PROM at the reset vector and releases it with
`IN 7F`.
