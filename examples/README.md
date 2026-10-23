# altairsim machine examples

**Machines that boot.** Each directory here is self-contained: a `.toml` that describes the
machine, the media it needs lying beside it, and a note saying what you will see. Copy any one of
them anywhere and it still runs — a path inside a machine file resolves against **that file**, not
against the directory you launched from.

Each directory has its own `README.md` (also distributed as `README.pdf`) saying what the machine
is and what to type. Each directory also holds a `<dir>.zip` containing all of its files, so you can
download that one file instead of the files one by one. You do not need both. Launch a machine by
naming its machine file from inside its directory:

```
cd examples/acr
altairsim mitstapes.toml
```

These machines need the [altairsim](https://github.com/deltecent/altairsim) simulator.

## Disk systems

| | What it is |
|---|---|
| [`cdos/`](cdos/) | **CDOS 2.58**, the CP/M 1.4 work-alike of Cromemco, on a **Cromemco 16FDC** with its own boot PROM, from an 8″ mixed-density diskette (`cdos.toml`). `A.` |
| [`cpnet/`](cpnet/) | **CP/NET 1.2** on two Altairs with **88-DCDD** 8″ floppies, joined by port B of each **88-2SIO**: an **MP/M II** server (`server.toml`, or `server-ss1.toml` with a CompuPro **System Support 1** in place of the 88-VI/RTC) and a **CP/M 2.2** requester (`requester.toml`) whose drive B: is drive A: of the server. Start the server first. `0A>` on the server, `A>` on the requester. |
| [`diskbasic/`](diskbasic/) | **Altair Disk Extended BASIC 4.1** on an **88-DCDD** 8″ floppy, loaded by the DBL boot PROM (`diskbasic.toml`). `OK` |
| [`fdcplus/`](fdcplus/) | **CP/M 2.2b** on an **FDC+**: from a serial drive server (`fdcplus-type7.toml`) or on the FDC+'s 1.5 MB floppy (`fdcplus-type5.toml`). |
| [`fujinet/`](fujinet/) | **CP/M 2.2b** on an **88-DCDD** 8″ floppy, with a **FujiNet** WiFi adapter on the second channel of an **88-2SIO**: `FUJIDIR`, `FUJIGET`, `FUJIPUT` and `WGET` reach a TNFS server or a web address (`fujinet.toml`). The example builds the tools from source, and carries them to your own disk. Name your serial device first. `A>` |
| [`hdsk/`](hdsk/) | **CP/M 2.2** booting off an Altair **88-HDSK "Datakeeper"** hard disk — an outboard controller moving whole sectors over an 88-4PIO — loaded by the HDBL PROM. `A0>` |
| [`icom/`](icom/) | **CP/M 2.2** and iCOM's own **FDOS** on an **iCOM FD3712/FD3812** 8″ floppy controller: single-density CP/M (`cpm22.toml`), double-density CP/M (`cpm22-3812.toml`), **FDOS-III** (`fdos-iii.toml`) and **FDOS-I** (`fdos-i.toml`). `A>` for CP/M, `!` for FDOS. |
| [`mpm2/`](mpm2/) | **MP/M II 2.1**, the multi-user system of Digital Research, on an Altair with **88-DCDD** 8″ floppies, an **88-2SIO** with two consoles and an **88-VI/RTC** for the tick (`mpm2.toml`), or a CompuPro **System Support 1** for the tick and the date (`mpm2-ss1.toml`). The disk boots into MP/M II with no CP/M. `0A>` on console 0, `1A>` on console 1 through `telnet localhost 8820`. |
| [`sdsys/`](sdsys/) | **SDOS 1.8B** and **SD Systems CP/M 2.2** on an **SD Systems SBC-200** Z80 single-board computer with a **VersaFloppy II** (`sdos.toml`, `cpm.toml`), the monitor alone (`sbc200.toml`), and a **VDB-8024** video console (`sbc200v.toml`, `sdosv.toml`). Press Enter, then `C`. `[A]` for SDOS, `A>` for CP/M. |
| [`tarbell/`](tarbell/) | **CP/M 2.2** that boots itself off a **Tarbell** floppy controller and its own 32-byte boot PROM: single density (`tarbell.toml`, `tarbell` #1011) and double density, with and without DMA (`tarbelldd.toml`, `tarbelldd-dma.toml`). |

## Tape, storage and I/O boards

| | What it is |
|---|---|
| [`acr/`](acr/) | Mike Douglas's **MITS Tapes** CP/M disk and **WRTAPE**, the utility that writes any of the MITS distribution BASICs back out through an **88-ACR** — a bootable audio cassette you can then load on `basic4k` / `basic8k` / `ps2`, or on real hardware. |
| [`pb1/`](pb1/) | An **SSM PB1** 2708/2716 EPROM programmer board and the SSM 8080 System Monitor: SSM's own burner programs from the PB1 manual burn a chip, and `SAVE` writes it out as an Intel HEX file (`pb1.toml`). `.` |
| [`uio/`](uio/) | **Altair 8K BASIC 3.2** from a cassette through one **88-UIO** board, which is the console and the cassette interface in one (`uio.toml`). `OK` |

## Graphics and games

| | What it is |
|---|---|
| [`cadzilla/`](cadzilla/) | The **CADzilla** graphics board's HD63484 ACRTC: `DRAWDEMO` shows every drawing command, one screen each, under CP/M. |
| [`dazzler/`](dazzler/) | A **Cromemco Dazzler**, 64×64 in 16 colors: Li-Chen Wang's **Kaleidoscope**, a pattern that wanders and recolors forever, **DZMBASIC**, Microsoft BASIC with `DZOP` graphics commands, under CP/M, the **Dazzler games** with joysticks and sound on a Cromemco D+7A, and Cromemco's **GDEMO** graphics demonstration. |
| [`sol-20/`](sol-20/) | A Processor Technology **Sol-20** with 1977 cassette games: TREK80, ATC, PAC-MAN and RAIDERS, each loading itself from its tape. |

## Sound

| | What it is |
|---|---|
| [`d7a/`](d7a/) | **MUSIC3**, a four-voice player of "The Star Spangled Banner" through a **Cromemco D+7A** on a Z80 at 4 MHz (`music3.toml`), and a CP/M machine with **M80** and **L80** that builds it from source (`music3-build.toml`). `A>` for the build machine. |
| [`newtech/`](newtech/) | A **Newtech Model 6 Music Board**, a 6-bit D/A converter and a speaker: Newtech's own player, **MICROPLAY**, plays the score from the manual of the board, Scott Joplin's **"The Entertainer"**. |
