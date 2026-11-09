# CP/M and MDOS on a Vector Graphic with Micropolis floppies

```
altairsim cpm14-lifeboat.toml

*B
CP/M ON VECTOR MZ
46K VERSION 1.411
COPYRIGHT (C) 1978 LIFEBOAT ASSOCIATES

A>DIR
```

These machines are **Vector Graphic** computers with the Vector Graphic **Micropolis Disk
Controller** and 5.25″ Micropolis drives. Each machine has a Z80 processor. Four machines start
from the built-in `vgmz` machine, a Vector Graphic MZ with a serial console. Two machines start
from the built-in `vg3vip` machine, a Vector 3 VIP with a **Flashwriter II** video board.

The machines run **CP/M 1.4** and **CP/M 2.2** from Lifeboat Associates, the **CP/M 2.20A** of
Vector Graphic, and **MDOS 3.0** and **MDOS 4.0**, the disk operating system of Micropolis.

## Start a machine

1. Type `altairsim <file>.toml` in this directory.
2. Wait for the prompt of the Vector Graphic Monitor. Monitor 2.0C shows `*`. Monitor 4.0c and
   Monitor 4.1 show `Mon>`. The table below gives the prompt of each machine.
3. Press `B`. The Monitor boots the disk in drive 0.

The CP/M prompt is `A>`. The MDOS prompt is `>`.

The two `vg3vip` machines show the console on the screen of the Flashwriter II, in a video
window. Type into the video window. The terminal shows only the monitor.

Press `Ctrl-E` to go back to the monitor at any time. Type `RUN` to continue. CP/M gets
`Ctrl-C`, because `Ctrl-C` is a warm boot in CP/M.

## The files

| File | What it is |
|---|---|
| `cpm14-lifeboat.toml` | **Lifeboat CP/M 1.4** for a 46K system. `base = "vgmz"`: 48K of RAM, Monitor 2.0C at `C000` and the controller at `D800`. Prompt `*`. |
| `cpm22-lifeboat-56k.toml` | **Lifeboat CP/M 2.2** (2.20B) for a 56K system. `base = "vgmz"`, changed to a 56K MZ: 56K of RAM, Monitor 4.0c at `E000`, the controller at `F800` and a **Bitstreamer II** console at ports `02` and `03`. Prompt `Mon>`. |
| `mdos30.toml` | **Micropolis MDOS 3.0**. `base = "vgmz"`. Prompt `*`. |
| `mdos40.toml` | **Micropolis MDOS 4.0**. `base = "vgmz"`. Prompt `*`. |
| `cpm22-56k.toml` | **Vector Graphic CP/M 2.20A** for a 56K system. `base = "vg3vip"`: a ZCB processor board with Monitor 4.1, 56K of RAM and a Flashwriter II console. Prompt `Mon>`, on the video screen. |
| `mdos40-56k.toml` | **Micropolis MDOS 4.0** for a 56K system. `base = "vg3vip"`. Prompt `Mon>`, on the video screen. |
| `CPM14-LIFEBOAT-VGMZ-46K.DSK` | The Lifeboat CP/M 1.4 system disk. |
| `CPM22-LIFEBOAT-VGMZ-56K.DSK` | The Lifeboat CP/M 2.2 system disk. |
| `CPM22-VGVIP-56K.DSK` | The Vector Graphic CP/M 2.20A system disk. |
| `MDOS30-VGMZ-48K.DSK` | The MDOS 3.0 system disk. |
| `MDOS40-VGMZ-48K.DSK` | The MDOS 4.0 system disk for a 48K MZ. |
| `MDOS40-VGVIP-56K.DSK` | The MDOS 4.0 system disk for a 56K VIP. |

Each disk has one side: 77 tracks of 16 hard sectors, and 275 bytes in each sector. The file is
338,800 bytes. The controller has no I/O ports. The controller decodes a 1K block of memory that
holds its boot PROM and its registers. A 48K machine has the block at `D800`, and a 56K machine
has the block at `F800`.

**The disks have no undo.** Drive 0 is mounted read/write, as on a real machine. The guest writes
to the disk for each file you create. In a clone, `git checkout` puts the disk image back. In a
copy that you received, nothing does. To test writes, copy the folder first. You can also
add `readonly = true` to the drive.
