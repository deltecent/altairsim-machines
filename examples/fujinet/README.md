# A FujiNet on CP/M 2.2b

The **FujiNet** is a small WiFi adapter that plugs into a serial port. This machine is an
Altair 8800 with **CP/M 2.2b**. The adapter is on the second channel of the **88-2SIO**
serial board. Four CP/M tools use the network device of the FujiNet. They list a directory on a
**TNFS** server, copy files to and from it, and fetch a file from a web address.

```
cd examples/fujinet
altairsim fujinet.toml
```

The machine boots CP/M from drive A. You land at the `A>` prompt:

```
56K CP/M 2.2b v2.3

For Altair 8" Floppy

A>
```

## Name your serial device first

`fujinet.toml` names the serial device of one computer. Change the `connect` line at the end
of the file to the device of your computer:

| Host | Value of `connect` |
|---|---|
| macOS | `serial:/dev/cu.usbserial-XXXXXXXX` (use `cu.`, not `tty.`) |
| Linux | `serial:/dev/ttyUSB0` or `serial:/dev/ttyACM0` |
| Windows | `serial:COM3` (Device Manager > Ports shows the number) |

On Linux, add your user to the `dialout` group. If the name is wrong, altairsim lists the
serial ports that it can see.

The baud rate of the machine is 76800. The baud rate of the FujiNet must be the same. Set
`baud` in the `[Serial]` section of `fnconfig.ini` on the adapter, or on its web page. After
you change it, turn the adapter off and on.

## No adapter

FujiNet-PC is the FujiNet firmware for a desktop computer. Use its RS232 build with an empty
`[Serial] port=` setting. Change the `connect` line of the machine file to a socket:

```
connect = "socket:localhost:1985"
```

## The machine

`fujinet.toml` is a small change to the `default` machine:

| Part | Setting |
|---|---|
| Processor | 8080, 2 MHz |
| Memory | 56K of RAM |
| Console | 88-2SIO channel A, ports 10H and 11H |
| FujiNet | 88-2SIO channel B, ports 12H and 13H, 76800 baud |
| Drive A | `FUJINET.DSK`, CP/M 2.2b and the FujiNet tools |
| Drive B | `PRN.DSK`, the printed listings of the tools |

The guest has no clock. It counts instructions. At full speed, its time-outs end in a few
microseconds of real time, and the tools decide that the FujiNet does not answer. For this
reason, the machine file sets the processor to its real 2 MHz.

Both disks are mounted **read/write**. CP/M writes to them. Copy an image before you change
it, or restore it with `git checkout`.

## The tools

The tools on drive A are `FUJIDIR`, `FUJIGET`, `FUJIPUT` and `WGET`. They are by **trgeuy**.
The source, the manual for the tools and the bring-up notes for a real adapter are at
<https://github.com/trgeuy/fujinet-cpm22>.

| Command | What it does |
|---|---|
| `FUJIDIR N1:TNFS://<server>/*.COM` | List the files on a TNFS server. |
| `FUJIGET N1:TNFS://<server>/FILE.EXT FILE.EXT` | Copy a file from the server to the current drive. |
| `FUJIPUT FILE.EXT N1:TNFS://<server>/FILE.EXT` | Copy a file from the current drive to the server. |
| `WGET FILE.EXT` | Fetch a file from a web address to the current drive. `WGET` asks for the address at a `URL:` prompt, so that the case of the address stays the same. |

Type the name of a tool with no argument to print its usage. The FujiNet must have a
WiFi connection before a tool can reach a server.

## The disks

Drive A has `FUJIDIR`, `FUJIGET`, `FUJIPUT` and `WGET` as `.ASM`, `.HEX` and `.COM` files.
`WGETURLS.TXT` lists the web addresses of the source files. Drive A also has the CP/M tools
`ASM`, `LOAD`, `MAC`, `DDT`, `ED`, `PIP`, `STAT`, `SUBMIT`, `XSUB`, `DUMP`, `SYSGEN` and
`MOVCPM8`, and the small tools `LS`, `CRC`, `SURVEY`, `PCGET`, `PCPUT`, `ACOPY`, `AFORMAT` and
`NSWP`. The host bridge utilities `R`, `W` and `HDIR` are there too. They copy files between the
CP/M disk and the host folder.

Drive B has `FUJIDIR.PRN`, `FUJIGET.PRN`, `FUJIPUT.PRN` and `WGET.PRN`.

`MAKE.SUB` assembles and loads the four tools again:

```
A>SUBMIT MAKE
```

## What the machine file does

- `startup = ["RUN FF00"]` starts the boot PROM. The machine boots at once.
- `bsdel = "bs"` in `[console]` makes the Backspace key of your terminal erase a character at
  the `A>` prompt.
- The `.DSK` files are 337,664 bytes. That is 96 bytes more than an 8″ floppy, because the
  XMODEM transfer that read them off a real machine added padding. The 88-DCDD board accepts
  this size.

Press `Ctrl-E` to return to the `altairsim>` monitor. CP/M keeps `Ctrl-C` for its warm boot.
