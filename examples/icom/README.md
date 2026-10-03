# CP/M and FDOS on an iCOM FD3712/FD3812 8″ floppy

```
altairsim cpm22.toml

48K CP/M 2.2 v1.0
for iCOM FD3712 and Altair

A>DIR
```

These machines have the **iCOM FD3712/FD3812** 8″ floppy controller. They run CP/M in single
density and in double density. They also run both revisions of iCOM's own FDOS disk operating
system. Each machine boots when you start it. The startup of each machine file is `RUN F000` for
CP/M and `RUN C000` for FDOS. On a real machine, you did the same: you examined the PROM address
and pressed RUN.

The iCOM controller is a **command and handshake** controller. The Tarbell and VersaFloppy
controllers shift bits. The iCOM controller buffers a whole sector instead. The processor moves
the bytes through two ports (`C0h` and `C1h`). The disk driver of the operating system runs from
a **boot PROM** in high memory: `F000` for CP/M and `C000` for FDOS.

The single-density **FD3712** disk is 77 × 26 × 128 = 256,256 bytes. The double-density
**FD3812** disk has mixed density. Track 0 is single density. Tracks 1 to 76 are double density.
The disk is 509,184 bytes.

Press `Ctrl-E` (STOP) to go back to the monitor at any time. Type `RUN` to continue. CP/M gets
`Ctrl-C`, because `Ctrl-C` is a warm boot in CP/M. The FDOS prompt is `!`. The two FDOS revisions
have different commands. **FDOS-III** takes word commands: `LIST` shows the directory. The
original **FDOS-I** takes single-letter directives: `L` shows the directory, `A` assembles, and
`P` prints.

## The files

| File | What it is |
|---|---|
| `cpm22.toml` | FD3712 **single-density CP/M 2.2**. `base = "icom"` plus the disk in drive 0. |
| `cpm22-3812.toml` | FD3812 **double-density CP/M 2.23** (Lifeboat). Uses the FD3812 boot PROM and the double-density disk. |
| `fdos-iii.toml` | iCOM's own **FDOS-III** disk operating system. Uses the FDOS boot PROM at `C000` and boots to the `!` prompt. |
| `fdos-i.toml` | iCOM **FDOS-I**, the original revision. Uses the same `C000` PROM as FDOS-III. Adds a RAM board (`C500` to `FFFF`), because FDOS-I loads its resident executive into high memory. Boots to `!`. Use single-letter directives (`L` for the directory). |
| `CPM22v1.0-3712-48K.DSK` | The single-density CP/M system disk. |
| `CPM22-3812-48K.dsk` | The double-density CP/M system disk. |
| `FDOS-III-2SIO.DSK` | The FDOS-III system disk. |
| `FDOS-I-2SIO.DSK` | The FDOS-I system disk. |
| `R.COM`, `W.COM`, `HDIR.COM` | The host bridge utilities. They copy files between the host folder and a CP/M disk. The single-density CP/M disk already has them, and `cpm22.toml` adds the host bridge board that they need. |

**The disks have no undo.** Drive 0 is mounted read/write, as on a real machine. The guest writes
to the disk for each file you create. In a clone, `git checkout` puts the disk image back. In a
copy that you received, nothing does. To test writes, copy the folder first. Or add
`readonly = true` to the drive.

The boot PROMs are Mike Douglas disassemblies. The disk images are from deramp.com (iCOM Floppy
Systems). The machines read and write existing disks. They cannot make a **blank** format. This is
the same as the other controllers in this repository. All the disks here are already formatted.
