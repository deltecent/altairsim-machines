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

## What this example is for

This example has two purposes:

1. **It shows how to build the FujiNet tools on CP/M.** `PULL.SUB` uses `WGET` to fetch the
   source files from GitHub. `MAKE.SUB` assembles them. See [The disks](#the-disks).
2. **It carries the tools on a disk that you can mount.** Mount your own CP/M disk in another
   drive, and copy the tools to it with `PIP`. See
   [Copy the tools to your own disk](#copy-the-tools-to-your-own-disk).

The two disks of this machine are not work disks. Drive A has about 24K free, and drive B has
about 34K free. The free space is enough to build the tools again. Do your own work on your own
disk.

## Name your serial device first

`fujinet.toml` does not name a serial device, because the name is different on each computer.
The `connect` line at the end of the file is a comment. Remove the `#` and put the device of
your computer in the line, or give the device on the command line. The values are:

| Host | Value of `connect` |
|---|---|
| macOS | `serial:/dev/cu.usbserial-XXXXXXXX` (use `cu.`, not `tty.`) |
| Linux | `serial:/dev/ttyUSB0` or `serial:/dev/ttyACM0` |
| Windows | `serial:COM3` (Device Manager > Ports shows the number) |

On Linux, add your user to the `dialout` group.

When the machine starts, `SHOW SERIAL` lists the serial ports that altairsim can see. Copy the
name of the FujiNet port from the list.

To keep the file as it is, give the device with `--set` on the command line:

```
altairsim fujinet.toml --set "sio0:b connect=serial:/dev/cu.usbserial-XXXXXXXX"
```

The baud rate of the machine is 76800. The baud rate of the FujiNet must be the same. Set
`baud` in the `[Serial]` section of `fnconfig.ini` on the adapter, or on its web page. After
you change it, turn the adapter off and on.

## No adapter

FujiNet-PC is the FujiNet firmware for a desktop computer. Use its RS232 build with an empty
`[Serial] port=` setting. Set the `connect` line of the machine file to a socket:

```
connect = "socket:localhost:1985"
```

To keep the file as it is, give the socket on the command line:

```
altairsim fujinet.toml --set "sio0:b connect=socket:localhost:1985"
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
`ASM`, `LOAD`, `PIP`, `EX` and `LS`, and the XMODEM tools `PCGET` and `PCPUT`.

The host bridge utilities `R`, `W` and `HDIR` are on drive A too. They copy files between the
CP/M disk and the host folder. Use `W` to copy the FujiNet tools to your computer. From there,
you can put them on other disk images.

Drive B has `FUJIDIR.PRN`, `FUJIGET.PRN`, `FUJIPUT.PRN` and `WGET.PRN`.

`EX` runs a `.SUB` file. It replaces `SUBMIT` and `XSUB`. `SUBMIT` changes every letter in a
`.SUB` file to a capital letter. A web address with capital letters does not work. `EX` keeps
the case of every letter.

`MAKE.SUB` assembles the four tools again and makes the `.COM` files. `ASM` writes the
listings (`.PRN`) to drive B:

```
A>EX MAKE
```

`PULL.SUB` fetches the current source files of the four tools from the GitHub repository of
trgeuy. It replaces `FUJIDIR.ASM`, `FUJIGET.ASM`, `FUJIPUT.ASM` and `WGET.ASM` on drive A.
`PULL.SUB` needs a FujiNet with a WiFi connection.

To get the new versions of the tools:

1. Type `EX PULL` to fetch the source files.
2. Type `EX MAKE` to assemble them.

## Copy the tools to your own disk

Drive C is empty. Put your own CP/M disk in it, and copy the tools with `PIP`:

1. Press `Ctrl-E` to go to the monitor.
2. Type `MOUNT dsk0:drive2 my-cpm.dsk` to put your disk in drive C.
3. Type `RUN` to go back to CP/M.
4. Type `PIP C:=A:FUJI*.COM` to copy `FUJIDIR`, `FUJIGET` and `FUJIPUT`.
5. Type `PIP C:=A:WGET.COM` to copy `WGET`.

A relative path in `MOUNT` starts at the folder of `fujinet.toml`.

## What the machine file does

- `startup = ["SHOW SERIAL", "RUN FF00"]` lists the serial ports of your computer. Then it
  starts the boot PROM. The machine boots at once.
- `bsdel = "bs"` in `[console]` makes the Backspace key of your terminal erase a character at
  the `A>` prompt.
- The `.DSK` files are 337,664 bytes. That is 96 bytes more than an 8″ floppy, because the
  XMODEM transfer that read them off a real machine added padding. The 88-DCDD board accepts
  this size.

Press `Ctrl-E` to return to the `altairsim>` monitor. CP/M keeps `Ctrl-C` for its warm boot.
