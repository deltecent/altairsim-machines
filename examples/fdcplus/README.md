# CP/M 2.2b on an Altair FDC+

The **FDC+** is a floppy controller that replaces the 88-DCDD in an Altair. It answers at the same
ports, so Altair disk software runs on it, but it can also serve disks from a **drive server** on
a PC over a serial cable, and it speaks a 1.5 MB floppy format of its own. Two machines here:

| Machine file | What it is |
|---|---|
| `fdcplus-type7.toml` | CP/M from an **FDC+ Serial Drive Server**: no disk in this folder is used. The FDC+ (drive type 7) gets its tracks from the server over a serial cable. Set your serial port in the file first — see below. |
| `fdcplus-type5.toml` | CP/M on the FDC+'s **1.5 MB floppy** (drive type 5), from `CPM22-48K-HDF.dsk`. The stock DBL boot PROM boots it, although it cannot read the disk — see below. |

**To launch one**, name the machine file from inside this folder:

```
$ altairsim fdcplus-type5.toml
```

On **Windows** the program is `altairsim.exe`:

```
> altairsim.exe fdcplus-type5.toml
```

The machine boots itself — you type no `BOOT` command — and comes up at the CP/M prompt.

`^E` (STOP) takes the keyboard back to the monitor at any point; `RUN` resumes. `^C` belongs to
CP/M (it is warm boot) and CP/M gets it.

## The files

| File | What it is |
|---|---|
| `fdcplus-type7.toml` | The serial-drive machine: `base = "default"` with the 88-DCDD replaced by an FDC+ and a 10 MHz crystal. Read it — it explains why the crystal is not optional. |
| `fdcplus-type5.toml` | The 1.5 MB floppy machine: `base = "default"` with the 88-DCDD replaced by an FDC+ at drive type 5 and the disk in drive 0. |
| `CPM22-48K-HDF.dsk` | Mike Douglas's 1.5 MB CP/M 2.2b disk, for a 48K machine: `MOVCPM`, `COPY`, `PCGET`/`PCPUT`, `MBASIC`, `WM`, and games, with 920K free. |

**There is no undo.** Drive 0 is mounted read/write because that is what a real machine is, and CP/M
writes to `A:` for anything you create. In a clone `git checkout` puts the image back; in a copy
you were handed, nothing does. Copy it first if you are about to test writes in anger.

## CP/M on the FDC+'s 1.5 MB floppy

`fdcplus-type5.toml` has the **FDC+** with its drive type switches at 5: a high-density floppy that
holds 1.5 MB, one 10,240-byte sector to a track. `CPM22-48K-HDF.dsk` is in drive 0. Run it:

```
$ altairsim fdcplus-type5.toml
```

and you get:

```
48K CP/M 2.2b v1.2
For Altair 1.5Mb Floppy

A>
```

The boot PROM at `FF00` is the same DBL as always, and it cannot read this disk. The FDC+ gives
it a sector of its own, from the board's memory, and that sector holds a loader that reads the
real disk. The machine file explains it.

Leave the clock at its default. The CP/M for this disk moves each track at a speed that only a
2 MHz processor matches, and at full speed the board keeps 2 MHz time too. A faster `clock_hz`
breaks it, as a faster processor would on a real Altair.

## CP/M from an FDC+ drive server

`fdcplus-type7.toml` has the **FDC+** in its serial-drive mode. The disk images are on an **FDC+
Serial Drive Server** (or any program that speaks its protocol) at the other end of a serial
cable, and the board gets them a track at a time. The simulator and a real FDC+ Altair can use the
same images through the same server.

1. Start the server, and mount a bootable 8" Altair CP/M image in its drive 0. No such image is
   in this folder; `../cadzilla/cpm22b23-56k-drawdemo.dsk` is one (56K CP/M 2.2b v2.3).
2. Open `fdcplus-type7.toml` and set `connect` on `fdc0` to your serial port. The file has
   examples for macOS (`serial:/dev/cu.usbserial-XXXX`), Linux (`serial:/dev/ttyUSB0`) and
   Windows (`serial:COM3`).
3. Set `baud` to the rate that the server uses: 9600, 19200, 38400, 57600, 76800, 230400,
   403200 or 460800. The two ends must agree.
4. Run it:

```
$ altairsim fdcplus-type7.toml
```

If the port does not open, the error lists the serial ports this computer has. If the port opens
but nothing comes after the boot, the drive server is not answering; the machine file turns on the
board's `error` debug flag, which reports what the line does wrong.

The file sets `clock_hz = 10000000` and `baud = 230400`. The crystal must not be full speed: the
CP/M BIOS gives up on a sector after a count that takes 0.28 seconds at 10 MHz, and a track takes
0.19 seconds at 230400 baud. At full speed the count takes a few milliseconds and no track arrives
in time. On a slower line, slow the crystal down too: at 38400 baud a track takes about one
second, which needs the real 2 MHz.
