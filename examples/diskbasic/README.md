# Altair Disk Extended BASIC 4.1 on an 8" floppy

```
altairsim diskbasic.toml

MEMORY SIZE? 
LINEPRINTER? C
HIGHEST DISK NUMBER? 0
HOW MANY FILES? 
HOW MANY RANDOM FILES? 

37033 BYTES FREE
ALTAIR BASIC REV. 4.1
[DISK EXTENDED VERSION]
COPYRIGHT 1977 BY MITS INC.
OK
```

**Altair BASIC Rev 4.1, Disk Extended Version** (MITS, 1977) runs on an 8" Pertec FD-400 floppy
drive behind an 88-DCDD board. The DBL boot PROM at `FF00` loads it. The startup of the machine
file is `RUN FF00`. On a real disk Altair, the operator did the same: EXAMINE `FF00`, then RUN.

This BASIC has a filesystem: files, a directory, `SAVE` by name, and the `DSKINI` command. The
cassette BASIC in `../basic` does not have these.

Press `Ctrl-E` to go back to the monitor at any time. Type `RUN` to continue.

## The startup dialogue

BASIC asks five questions. One question has an answer that you cannot guess.

| Question | Answer |
|---|---|
| `MEMORY SIZE?` | Return. BASIC uses all of the memory. |
| `LINEPRINTER?` | **`C`**. BASIC accepts only `C`, `O` or `Q`. |
| `HIGHEST DISK NUMBER?` | `0`. This machine has one drive in use, and the numbers start at zero. |
| `HOW MANY FILES?` | Return |
| `HOW MANY RANDOM FILES?` | Return |

**Answer `LINEPRINTER?` with `C`, `O` or `Q`.** If you type anything else, BASIC asks the question
again and shows no error. A blank line or an `N` makes the machine look stopped, but it is not.

`C` is the 88-C700 line printer. You can answer `C` when the machine has no printer board. The
answer only tells BASIC where `LPRINT` sends its output. BASIC writes nothing until you use
`LPRINT`. To make `LPRINT` go somewhere, add an 88-C700 board. The command
`altairsim -x 'SHOW MACHINE' lineprinter` shows a machine that has one.

MITS wrote the answers for Rev 4.1 in the *Basic Versions* table.

## Delete a character with `_`

The Backspace key does not work in this BASIC. To delete the last character that you typed, type
`_` (underscore). This is how a Teletype did it. For example, `PRINT 5Q_` prints `5`.

## See the programs on the disk

1. Type `MOUNT 0`.
2. Type `FILES`.

BASIC does not read the disk until you mount it.

## The files

| File | What it is |
|---|---|
| `diskbasic.toml` | The machine: `base = "default"` plus the floppy in drive 0. |
| `Disk BASIC 4.1.dsk` | The bootable system disk. |

**Copy the disk image before you experiment.** Drive 0 is mounted for reading and writing, as on a
real machine. `SAVE` and `DSKINI` both write to it. In a clone, `git checkout` puts the image back.
A downloaded copy has no way to undo a change.

**Put quotes around the filename.** The filename has spaces in it. Without quotes, `MOUNT` reads
`BASIC` as an option and refuses.

Three drives are empty. To fill one, type `MOUNT dsk0:drive1 "my-data.dsk"` at the monitor. Then
raise the answer to `HIGHEST DISK NUMBER?`, so that BASIC can see the drive.
