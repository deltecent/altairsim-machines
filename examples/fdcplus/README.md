# CP/M 2.2b on an Altair FDC+

The **FDC+** is a floppy controller. It replaces the 88-DCDD in an Altair and responds to the same
ports, so Altair disk software runs on it. The FDC+ can also read disks from a **drive server**
on a PC through a serial cable. It also has its own floppy format, which holds 1.5 MB.

This directory has two machines:

| Machine file | What it is |
|---|---|
| `fdcplus-type7.toml` | CP/M from an **FDC+ Serial Drive Server**. The FDC+ (drive type 7) gets its tracks from the server through a serial cable. This directory has no disk for it. Set your serial port in the machine file before you start. See "CP/M from an FDC+ drive server". |
| `fdcplus-type5.toml` | CP/M on the FDC+ **1.5 MB floppy** (drive type 5), from `CPM22-48K-HDF.dsk`. See "CP/M on the FDC+ 1.5 MB floppy". |

To start a machine, go to this directory and give the name of the machine file:

```
$ altairsim fdcplus-type5.toml
```

On **Windows**, the command is `altairsim.exe`:

```
> altairsim.exe fdcplus-type5.toml
```

The machine boots itself. You type no `BOOT` command. It stops at the CP/M prompt.

Press `Ctrl-E` (STOP) at any time to go back to the monitor. Type `RUN` to continue. CP/M
receives `Ctrl-C` and does a warm boot.

## The files

| File | What it is |
|---|---|
| `fdcplus-type7.toml` | The serial-drive machine. It is `base = "default"` with an FDC+ in place of the 88-DCDD, and a 10 MHz clock. The file explains why the clock setting is needed. |
| `fdcplus-type5.toml` | The 1.5 MB floppy machine. It is `base = "default"` with an FDC+ at drive type 5 in place of the 88-DCDD, and the disk in drive 0. |
| `CPM22-48K-HDF.dsk` | Mike Douglas's 1.5 MB CP/M 2.2b disk for a 48K machine. It has `MOVCPM`, `COPY`, `PCGET`/`PCPUT`, `MBASIC`, `WM` and games, with 920K free. |

Copy `CPM22-48K-HDF.dsk` before you write to it. The machine mounts drive 0 for reading and
writing, and CP/M saves every new file to `A:`. In a clone of the repository, `git checkout`
restores the disk image. In a copy that you downloaded, nothing restores it.

## CP/M on the FDC+ 1.5 MB floppy

`fdcplus-type5.toml` has the **FDC+** with its drive type switches set to 5. This is a
high-density floppy that holds 1.5 MB, with one 10,240-byte sector on each track.
`CPM22-48K-HDF.dsk` is in drive 0. Start the machine:

```
$ altairsim fdcplus-type5.toml
```

The console shows:

```
48K CP/M 2.2b v1.2
For Altair 1.5Mb Floppy

A>
```

The boot PROM at `FF00` is the standard DBL PROM. DBL cannot read this disk. The FDC+ gives DBL
a sector of its own from the memory of the board. That sector holds a loader, and the loader
reads the real disk. The machine file explains this in more detail.

Do not change the clock. The CP/M for this disk moves each track at a speed that only a 2 MHz
processor matches. At full speed, the board keeps 2 MHz time also. A higher `clock_hz` makes
CP/M fail, as a faster processor does on a real Altair.

## CP/M from an FDC+ drive server

`fdcplus-type7.toml` has the **FDC+** in its serial-drive mode. The disk images are on an **FDC+
Serial Drive Server**, or on any program that uses its protocol, at the other end of a serial
cable. The board gets the images one track at a time. The simulator and a real FDC+ Altair can
use the same images through the same server.

1. Start the server.
2. Mount a bootable 8" Altair CP/M image in drive 0 of the server. This directory has no such
   image. `../cadzilla/cpm22b23-56k-drawdemo.dsk` is one (56K CP/M 2.2b v2.3).
3. Open `fdcplus-type7.toml`. Set `connect` on `fdc0` to your serial port. The file has
   examples for macOS (`serial:/dev/cu.usbserial-XXXX`), Linux (`serial:/dev/ttyUSB0`) and
   Windows (`serial:COM3`).
4. Set `baud` to the rate of the server. The two ends must use the same rate. The rates are 9600,
   19200, 38400, 57600, 76800, 230400, 403200 and 460800.
5. Start the machine:

```
$ altairsim fdcplus-type7.toml
```

If the port does not open, the error lists the serial ports of this computer. If the port opens
but the console shows nothing after the boot, the drive server does not answer. The machine file
turns on the `error` debug flag of the board. The flag reports each fault on the serial line.

The machine file sets `clock_hz = 10000000` and `baud = 230400`. Do not run the processor at full
speed. The CP/M BIOS stops its wait for a sector after a count of loops. The count takes 0.28
seconds at 10 MHz. A track takes 0.19 seconds at 230400 baud, so the track arrives in time. At
full speed, the count takes a few milliseconds, and the track arrives too late. For a slower
serial line, also use a slower clock. At 38400 baud, a track takes about one second. This needs
the real 2 MHz.
