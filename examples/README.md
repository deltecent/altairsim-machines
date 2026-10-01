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
| [`diskbasic/`](diskbasic/) | **Altair Disk Extended BASIC 4.1** (MITS, 1977) on an 8" floppy behind an 88-DCDD, booted by the DBL PROM. Unlike the cassette BASIC, this one has a filesystem — `SAVE` by name, a directory, `DSKINI`. `MEMORY SIZE?` |
| [`hdsk/`](hdsk/) | **CP/M 2.2** booting off an Altair **88-HDSK "Datakeeper"** hard disk — an outboard controller moving whole sectors over an 88-4PIO — loaded by the HDBL PROM. `A0>` |
| [`fdcplus/`](fdcplus/) | **CP/M 2.2b** on an **FDC+**: from a serial drive server (`fdcplus-type7.toml`) or on the FDC+'s 1.5 MB floppy (`fdcplus-type5.toml`). |
| [`turnkey/`](turnkey/) | The **MITS 8800bt**, an Altair with a Turnkey Module and no front panel, booting CP/M two ways: off an 88-DCDD floppy (`floppy.toml`) or an 88-HDSK hard disk (`hdsk.toml`). |
| [`tarbell/`](tarbell/) | **CP/M 2.2** that boots itself off a **Tarbell** floppy controller and its own 32-byte boot PROM: single density (`tarbell.toml`, `tarbell` #1011) and double density, with and without DMA (`tarbelldd.toml`, `tarbelldd-dma.toml`). |
| [`icom/`](icom/) | **CP/M and FDOS** on an **iCOM FD3712/FD3812** 8″ floppy — single and double density CP/M, and both revisions of iCOM's FDOS. |
| [`cdos/`](cdos/) | **CDOS 2.58**, Cromemco's CP/M work-alike, booted from an 8″ diskette through a **Cromemco 16FDC** on a 4 MHz Z80. |
| [`sdsys/`](sdsys/) | The **SD Systems SBC-200**, a Z80 single-board computer with the SD/MS monitor, booting SDOS, CP/M 2.2, and banked and non-banked CP/M 3 — with a serial or a video console. |
| [`dualide/`](dualide/) | **CP/M 3** off a CompactFlash card on the IDE half of the S100Computers **IDE-AB CF+ESP32** board. |
| [`dualsd/`](dualsd/) | **CP/M 3** off microSD cards on the S100Computers **Dual SD** board, booted from the V2 Z80 board's MASTER monitor. |
| [`dualidesd/`](dualidesd/) | The whole **IDE-AB CF + Dual SD** combination board: all four drives, `A:`/`B:` on CF and `C:`/`D:` on SD, under CP/M 3. |

## Tape, storage and I/O boards

| | What it is |
|---|---|
| [`acr/`](acr/) | Mike Douglas's **MITS Tapes** CP/M disk and **WRTAPE**, the utility that writes any of the MITS distribution BASICs back out through an **88-ACR** — a bootable audio cassette you can then load on `basic4k` / `basic8k` / `ps2`, or on real hardware. |
| [`uio/`](uio/) | The **88-UIO**, two cards in one — console and cassette on a single board — running Altair **8K BASIC 3.2**. |
| [`io4/`](io4/) | The **SSM IO-4 (2P + 2S)** as a console, running the SSM 8080 System Monitor. Explains the console straps. |
| [`pb1/`](pb1/) | The **SSM PB1** 2708/2716 EPROM programmer: SSM's own burner programs from the manual, and the burned chip read back as Intel HEX. |
| [`pmmi/`](pmmi/) | The **PMMI MM-103** modem, with a small 8080 program that turns it into a terminal. |
| [`printing/`](printing/) | An **88-C700 line printer**, and a banner program that prints through it. The README sets up a real printer on your host — a network printer over `socket:`, or a CUPS queue over `printer:` — and a page comes out. Per-OS host setup (macOS, Linux; Windows pending). |

## Graphics and games

| | What it is |
|---|---|
| [`dazzler/`](dazzler/) | A **Cromemco Dazzler**, 64×64 in 16 colors: Li-Chen Wang's **Kaleidoscope**, a pattern that wanders and recolors forever, and **DZMBASIC**, Microsoft BASIC with `DZOP` graphics commands, under CP/M. |
| [`cadzilla/`](cadzilla/) | The **CADzilla** graphics board's HD63484 ACRTC: `DRAWDEMO` shows every drawing command, one screen each, under CP/M. |
| [`sol-20/`](sol-20/) | A Processor Technology **Sol-20** with 1977 cassette games: TREK80, ATC, PAC-MAN and RAIDERS, each loading itself from its tape. |
