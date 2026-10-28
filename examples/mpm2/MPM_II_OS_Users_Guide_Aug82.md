# Digital Research MP/M II — Operating System User's Guide (commands and utilities)

Source: `mpm2ug.pdf` (*MP/M II Operating System, User's Guide*, © 1981 Digital Research,
Second Edition, August 1982), 196 PDF pages. The PDF is an **OCR text layer** with no page
images, except the two ED figures. It has many OCR errors: `OA>` for `0A>`, `TD` and `TS` for
`^D` and `^S`, `l0k` for `10k`, `riot` for `not`. This file corrects the errors that are clear
from the context, and the Quirks list the ones that are not. The page numbers of the contents,
of the index and of the text do not agree (DSKRESET is p.29 in the contents, p.34 on the page
and PDF page 43). Because of that, this file cites section numbers only.

MP/M II is DRI's multi-user, multi-tasking operating system for the 8080, 8085 and Z80. The guide
is for the person at a console. It assumes that MP/M II already runs on the machine. It covers
the prompt, the command line, file names and the search for files, and each utility a user runs.
The XIOS, the loader and GENSYS are in the *System Implementor's Guide*
([`MPM_II_System_Implementors_Guide_Aug82.md`](MPM_II_System_Implementors_Guide_Aug82.md)). The
BDOS calls are in the *Programmer's Guide*, which this folder does not have.

This file keeps the syntax, the options, the messages and the rules of each command. It leaves
out the tutorial text, the ASCII table (App. A) and most of the examples. Section 11 below says
what is different on the machines of this folder.

---

## 1. Quick reference

| What | Value | Where |
|---|---|---|
| Prompt | `<user><drive>>`, for example `0A>`. The user number is 0–15, the drive A–P. | §1.3 |
| Start user number | The same as the console number: console 1 starts in user 1 | §1.3, §5.3 |
| Start drive | A: after a cold boot. Type `E:` to change it. | §1.3 |
| Consoles | Console 0 shows the long boot message. Up to 8 system consoles, numbered 0–7. | §1.2, §5.3 |
| Command line | Up to 100 characters. One command for each line. Upper and lower case are the same. | §2.1 |
| Command keyword | The queue name of a resident system process (RSP), or a `.PRL` or `.COM` file | §2.1, §3.5.1 |
| File types run | `PRL` first, then `COM` (8 searches, Table 3-2 below) | §3.5.1 |
| File specification | `d:filename.typ;password` | §3.1 |
| Wildcards | `?` (one character), `*` (the rest of the name or the type). Never in a drive or a password. | §3.2 |
| Option list | `[...]` after the command (global) or after a file (local). One or two letters of an option are enough. | §4.3 |
| Change a disk | `DSKRESET d:` first. Without it, MP/M II sets the drive to read-only. | §5.1 |
| Stop the display | `^S`, then `^Q` to continue or `^C` to abort | §2.3 |
| Run two programs on one console | Start one, `^D` to detach it, start the next. `^D` or `ATTACH` gets it back. | §2.4, §8.2 |
| Comment line | `;` in column one | §3.1.5 |
| Date and time | `TOD mm/dd/yy hh:mm:ss`. Zero until set. Set it again after each power-up or reset. | §10.1 |
| Batch | `SUBMIT file p1 p2 ...`, with `$1`… in `file.SUB` | §10.6 |
| Record | 128 bytes. A file takes at least one block, 1K on a single-density 8" floppy. | §6.4.2, App. I |

## 2. Sign-on and system generation (Section 1)

GENSYS sets these values, and the user sees their effect (§1.1):

- the size and the layout of memory, the number of consoles and of printers
- the **system drive**: MP/M II looks there for a command that is not on the default drive
- the **temporary file drive**, which holds the `$n$.SUB` files of SUBMIT
- the maximum of locked records and of open files, for each process and in total
- the utilities that are resident: an RSP, or an RSP with a BRS (banked part). A resident
  utility runs with no file on the disk.
- the **day-file option**

The loader prints the memory segment table on console 0, then `MP/M II V2.0` and the copyright
on every console (§1.2). The sample in Figure 1-2 is an Altos with a 4-bank memory, an 8" floppy
as A: and a hard disk as E:, the system drive.

**Day-file option** (§1.4). After each command, MP/M II prints the time (24-hour clock), the
drive and the file it loaded, and the user number if it is not the default:

```
3D>DIR
15:53:32 D:DIR      PRL (User 0)
```

For a command that is an RSP or is built in (`ATTACH`), no file is loaded, so the line is
`15:55:10 Msg Qued`.

## 3. The command line (Section 2)

`TYPE B:DOCUMENT.LAW` has a **keyword** (`TYPE`), a **tail** (`B:DOCUMENT.LAW`) and a carriage
return. MP/M II sends the line when you press RETURN, or when the line reaches 100 characters
(§2.1).

### 3.1 Line editing (Table 2-1, App. C)

| Key | Action |
|---|---|
| `RUB`, `DEL` | Delete the character at the left. The deleted character is echoed. |
| `BACKSPACE`, `^H` | Move back one character and erase it |
| `^U` | Cancel the line. Prints `#` and starts a new line. |
| `^X` | Delete all the characters of the line |
| `^R` | Type the line again, clean (useful after `RUB`) |
| `^E` | Go to a new line on the screen. The line is not sent. |
| `RETURN`, `^M`, `^J` | End the line |
| `^Z` | End of file, end of a string, field separator |

### 3.2 Control characters (Table 2-3, App. C)

| Key | Action |
|---|---|
| `^P` | Echo all console output on the printer. A second `^P` stops it. Prints `Printer busy` if another process has the printer. |
| `^S` | Stop the output. After `^S`, only `^Q` and `^C` work. Any other key rings the bell. |
| `^Q` | Continue after `^S`. Ignored at other times. |
| `^C` | Ask `ABORT (Y/N)?` for the program attached to this console |
| `^D` | Detach the running program from this console. With no program running, attach the next detached program that waits for this console. |

Some programs, word processors in particular, take every control character for their own use.
In such a program `^C` does not abort. Use the program's exit command, or `ABORT` from another
console (§2.3).

### 3.3 Detach and attach (§2.4, §8.2)

1. Start a program on a console.
2. Type `^D`. The program detaches, and the prompt comes back.
3. Start another program. Continue until no memory segment is free.
4. Type `^D` or `ATTACH name` to attach a program again. `^D` attaches them in the order they
   were detached. `ATTACH` takes the named one.

A detached program runs until it needs the console. Then it waits for the console. After two
`^D`, MP/M II prints `Attach: Tmpn`, where n is the console number. This is a prompt: type a
command, or RETURN for the normal prompt. `^X` can fail until you type RETURN (§8.2).

### 3.4 The utilities (Table 2-2)

| Name | Action | Name | Action |
|---|---|---|---|
| ABORT | Abort a process | PIP | Copy files |
| ATTACH | Attach a program to its console (built in) | PRINTER | Show or set the printer number |
| ASM | Assembler | PRLCOM | `.PRL` to `.COM` |
| CONSOLE | Show the console number | RDT | Relocatable debugger |
| DDT | Debugger | REN | Rename files |
| DIR | Directory | RMAC | Relocating macro assembler |
| DSKRESET | Reset drives | SCHED | Run a command at a date and time |
| DUMP | Show a file in hex | SDIR | Directory with options |
| ED | Editor | SET | Passwords, time stamps, attributes |
| ERA | Erase files | SHOW | Disk status, label |
| ERAQ | Erase with a query for each file | SPOOL | Print files in the background |
| GENHEX | `.COM` to `.HEX` | STAT | File and disk status |
| GENMOD | `.HEX` to `.PRL` | STOPSPLR | Stop the spooler |
| GENSYS | Make `MPM.SYS` | SUBMIT | Run a batch file |
| LIB | Library of `.REL` files | TOD | Show or set the date and time |
| LINK | Link `.REL` files | TYPE | Show a text file |
| LOAD | `.HEX` to `.COM` | USER | Show or set the user number |
| MPMSTAT | Show the internal status | XREF | Cross-reference of RMAC output |
| MPMLDR | Load MP/M II | | |

The guide describes 20 of them. ASM, DDT, RDT, GENHEX, GENMOD, LIB, LINK, LOAD, PRLCOM, RMAC
and XREF are in the *Programmer's Guide*, and GENSYS and MPMLDR in the *System Guide*. App. F
gives the syntax of all of them (§6.1–§6.10 below has it for the 20).

## 4. Files (Section 3)

### 4.1 File specification (§3.1)

`d:filename.typ;password`. A name or a type must be present. The other parts are optional. Valid
forms: `filename`, `filename.typ`, `d:filename`, `d:filename.typ`, `filename.typ;password`,
`d:filename.typ;password`. The guide calls any of these a **filespec**.

| Part | Rule |
|---|---|
| `d:` | One letter and a colon. Without it, the default drive. |
| filename | 1–8 letters, digits and the special characters that Table 3-1 does not list |
| `.typ` | 0–3 characters. Commands must be `.PRL` or `.COM`. App. B lists the common types. |
| `;password` | 1–8 characters. Made upper case by the standard utilities. An application can keep lower case. |

ED, ERA, ERAQ, PIP, REN and TYPE take a password in the file name of their tail. A command line
can need two passwords: `TYPE;XYZ B:CAT.ASM;XYZ` (one for the program file, one for the data
file). For a program that takes no password in its tail, set `SET [DEFAULT=XYZ]` first.

A missing or wrong password gives:

```
Bdos Err On d: Password Error
Bdos Function: NNN File: FILENAME.TYP
```

**Special characters** (Table 3-1). Do not put these in a file specification:

| Character | Use |
|---|---|
| `<` `=` `,` tab, space, RETURN | Separate the items of a line |
| `:` | After the drive |
| `.` | Before the type |
| `;` | Before the password. In column one, a comment line. |
| `*` `?` | Wildcards |
| `<` `>` `&` | Reserved for I/O redirection (⚠ see Quirks) |
| `[` `]` | Around an option list |
| `(` `)` | Around a list of modifiers in an option list |
| `/` `$` | Reserved for options |

### 4.2 Wildcards (§3.2)

`?` matches one character in the same place. `*` fills the rest of the name or the type with `?`.
`APP?.TXT` matches `APPA.TXT` and `APP.TXT`, but not `APP14.TXT`. DIR, SDIR, ERA, ERAQ, STAT,
PIP, REN and SET take wildcards. A wildcard drive (`DIR ?:*.BAK`) gives `Bad entry`.

### 4.3 Attributes (§3.3, §7.4)

| Attribute | Values | Effect |
|---|---|---|
| Directory/System | `DIR` or `SYS` | A `SYS` file is hidden from `DIR`, and other users can find it in user 0 (§4.5 below) |
| Read only | `RO` or `RW` | An `RO` file cannot be written, erased or renamed |
| Archive | on or off | `PIP [A]` sets it. A write to the file clears it. STAT and SDIR show `A`. |
| F1–F4 | on or off | For applications. MP/M II does not use them. STAT and SDIR show the digit. |

A drive is also `RO` or `RW`. MP/M II sets a drive to `RO` when the disk changed without a
`DSKRESET`. After that, a write to the drive fails, and an edit in progress can be lost (§3.3,
§5.1).

### 4.4 XFCB (§3.4)

An **Extended File Control Block** is an extra directory entry for one file. It holds the file's
password and two time stamps: the update time, and either the create time or the access time.
SET makes it (Section 7 below).

### 4.5 How MP/M II finds a file (§3.5)

**A command** (§3.5.1). MP/M II first looks for a queue of an RSP with that name. If there is
none, it searches the disk in this order (Table 3-2):

| Search | Type | User | Drive |
|---|---|---|---|
| 1 | PRL | default | default or given |
| 2 | PRL | 0 | default or given |
| 3 | COM | default | default or given |
| 4 | COM | 0 | default or given |
| 5 | PRL | default | system |
| 6 | PRL | 0 | system |
| 7 | COM | default | system |
| 8 | COM | 0 | system |

- A file found in user 0 or on the system drive must have the `SYS` attribute. The exceptions:
  in user 0, a `DIR` file is found on the default drive, and on the system drive a `DIR` file
  is found in the default user.
- With a drive in the command, MP/M II does searches 1–4 on that drive only.
- With a drive or a password in the command, MP/M II does not look for an RSP. Type the name of
  an RSP command alone.
- If nothing is found, MP/M II prints the name and `?`.

**A data file** (§3.5.2, Table 3-3). Two searches: the default user, then user 0, on the default
or the given drive. A file in user 0 must be `SYS`, unless the default user is 0. A file opened in
unlocked mode is not looked for in user 0. If the program does not find the file, it prints
`File not found`.

**Checklist** (§3.5.3, App. E):

- A disk of a different density from the drive gives `Bad Sector`.
- A `RO` file can be read, but not written.
- A `RO` drive can be read, but not written. The usual cause is a disk change without `DSKRESET`.
- After `^S`, the keyboard waits for `^Q`.
- `Reloc seg not free`: type `^D` to attach a detached process. When it ends, its segment is free.
  An unseen `^D` can cause this too.
- A drive in the command limits the search to the default user and user 0 of that drive.
- Password modes: READ needs the password to read. WRITE needs it to write. DELETE needs it to
  erase or rename. NONE has no password.
- With password protection on in the drive's label, the protected files need their passwords.
- To find a lost file, use `SDIR [USERS=ALL, DRIVES=ALL] TWO.TEX`.

## 5. Command syntax in the guide (Section 4)

- `d:`, `n`, `filename`, `typ`, `filespec` and `programname` stand for real values (§4.2).
- `^` is the control key. `<cr>` is RETURN.
- A **global option** follows the command: `SDIR [SIZE]`. A **local option** follows a file:
  `SET B:*.*[RO,SYS]` (§4.3).
- An option can have a **modifier**: `SDIR [DRIVE=B]`. A modifier of more than one element goes in
  parentheses: `SDIR [USER=(0,1,2)]`.
- Options go in one pair of brackets, with commas or spaces between them.

## 6. The utilities

### 6.1 DSKRESET, USER, CONSOLE (Section 5)

**DSKRESET** (§5.1)

```
DSKRESET
DSKRESET d:
DSKRESET d:,d:,d: ...
```

Without a tail, it resets all the drives. MP/M II resets all the drives at power-up. DSKRESET
refuses a drive that has an open file, and names the console and the program:

```
0A>DSKRESET B:
Disk reset denied, Drive B: Console 2 Program PIP
```

Reset the drive **before** you take out the disk. Then no other user has a file open on it. A
disk taken out while a process uses a file can damage that file. A changed disk that was not
reset becomes read-only at the first write (§5.1). App. F adds that DSKRESET with no tail does
not reset the default drive (⚠ see Quirks).

**USER** (§5.2)

```
USER          shows "User Number = n"
USER n        n = 0..15, changes the prompt
```

Each file has the user number that made it. DIR, ERA, REN and TYPE use the default user only.
PIP `[Gn]` reads or writes another user. A file from CP/M 1.4 is in user 0. A `SYS` file in user 0
is open to all users.

**CONSOLE** (§5.3). `CONSOLE` prints `Console = n`. The console number does not change with
`USER`. ABORT and STOPSPLR take a console number, and some messages show it.

### 6.2 DIR (§6.1)

```
DIR
DIR d:
DIR filespec
DIR filespec, filespec
DIR filespec [SYS]
DIR filespec [Gn]
```

- No tail, or a drive alone, is `*.*`.
- `DIR` lists the files with `DIR` only. If `SYS` files exist, it prints `System Files Exist`.
  `[SYS]` lists the `SYS` files.
- `[Gn]` lists user n (0–15).
- `[SYS]` and `[Gn]` apply to all the file specifications of the line.
- A key other than `^S` during the listing stops DIR.
- No match prints `File not found`.

### 6.3 SDIR (§6.2, §6.3)

```
SDIR [options] filespec, filespec ...
```

SDIR is DIR and the passive part of STAT together. It takes up to 10 file specifications. It has
global options only, in one list, which can be at any place in the line. `d:` means `d:*.*`.
SDIR changes nothing on the disk or in memory. `SDIR [HELP]` shows examples.

Three formats:

| Format | Shows |
|---|---|
| **Full** (default) | Name, kilobytes, records, attributes. With a directory label, also the protection mode and the two time stamps. Without a label, two files on each line. Sorted. |
| **Size** `[SIZE]` | Name and kilobytes |
| **Short** `[SHORT]` | Four names on each line, `SYS` files included, not sorted. It does not keep the names in memory, so it never runs out of memory. |

Full and size end with two total lines: kilobytes, records and files, then the number of 1K
blocks and `Used/Max Dir Entries`. With one file found, there are no totals.

The kilobytes column is the space the file takes on the disk. The records column is the length in
128-byte records. The 1K-block total is the space on a disk with 1K blocks (a single-density
floppy).

Options (Table 6-1). The default is `[RO,RW,SYS,DIR,SORT,FULL,XFCB]`:

| Option | Shows |
|---|---|
| `SYS` / `DIR` | Only the files with `SYS` / without `SYS` |
| `RO` / `RW` | Only the read-only / read-write files |
| `XFCB` / `NONXFCB` | Only the files with / without an XFCB. `SHORT` is ignored with them. |
| `USER=n`, `USER=ALL`, `USER=(0,1,...)` | Those users |
| `DRIVE=d`, `DRIVE=ALL`, `DRIVE=(A,B,...)` | Those drives. `ALL` is the logged-in drives. `DISK` is the same as `DRIVE`. |
| `FULL`, `SIZE`, `SHORT` | The format |
| `LENGTH=n` | A heading every n lines (5–65536) |
| `FF` | A form feed first, and every `LENGTH` lines. For `^P` copies. |
| `MESSAGE` | Name each drive and user it searches, and say `File not found` where it finds none |
| `NOSORT` | The order on the disk. `SHORT` sets it. |
| `EXCLUDE` | The files that do **not** match the file specifications |
| `HELP` | Examples |

A "logged-in" drive is one that has been used since the last DSKRESET.

### 6.4 STAT (§6.4)

```
STAT                      free space of every logged-in drive, and RO/RW
STAT d:                   "Bytes Remaining On d: nnnk"
STAT d:=RO                set the drive read-only
STAT filespec             size and attributes
STAT filespec [SIZE]      also the computed size
STAT filespec [RO] [RW] [SYS] [DIR]
STAT d:DSK:  /  STAT DSK: the disk parameters
STAT d:USR:  /  STAT USR: the active user and the users that have files
STAT VAL:                 a summary of the commands
```

A drive set with `STAT d:=RO` stays read-only until `SET d:[RW]` (§6.4.1).

`STAT d:DSK:` (Table 6-2):

| Line | Meaning |
|---|---|
| 128 Byte Record Capacity | Records the disk can hold |
| Kilobyte Drive Capacity | Kilobytes the disk can hold |
| 32 Byte Directory Entries | Files the directory can hold |
| Checked Directory Entries | Entries checked at each access to detect a changed disk. Usually the same as the directory entries for a floppy, 0 for a fixed disk. |
| Records/ Directory Entry | Records that one directory entry can point to |
| Records/ Block | The smallest space a file takes |
| Sectors/ Track | 128-byte sectors on each track |
| Reserved Tracks | Tracks for the system |

The file listing (§6.4.2) has the columns `Recs  Bytes  FCBs  Attributes  Name`, and with
`[SIZE]` a `Size` column first. The total line gives the kilobytes, the FCBs, the number of files
and the number of 1K blocks. In the Attributes column: `Dir`/`Sys`, `RW`/`RO`, `X` for an XFCB,
`A` for archived, and `1`–`4` for F1–F4.

Limits: the `Recs` and `Bytes` columns are correct up to 65,535. For a file larger than 8 MB,
use `[SIZE]`. STAT lists at most 512 files.

A random file with gaps can have a computed size larger than its records.

In MP/M II, SHOW and SDIR do the passive work of STAT, and SET does the active work.

### 6.5 SHOW (§6.5)

```
SHOW                 RO/RW and free space of each logged-in drive (same as SHOW SPACE)
SHOW d:              the same, for one drive
SHOW DRIVES          the STAT DSK: report     (SHOW d:DRIVE for one drive)
SHOW USERS           the active user and the users that have files
SHOW LABEL           the directory label
SHOW HELP            the options
```

App. F also shows `SHOW E:,F:,E:USERS,F:USERS`.

`SHOW LABEL` has the columns:

| Column | Meaning | Set with |
|---|---|---|
| Directory Label | The label name | `SET [NAME=...]` |
| Passwds Reqd | Password protection on or off | `SET [PROTECT=ON]` |
| Make XFCBs | Each new file gets an XFCB | `SET [MAKE=ON]`, or a time stamp option |
| Stamp Create *or* Stamp Access | The first stamp, and on or off | `SET [CREATE=ON]` / `SET [ACCESS=ON]` |
| Stamp Update | The update stamp, on or off | `SET [UPDATE=ON]` |
| Label Created, Label Updated | Date and time of the label | |

With password protection off, anyone can read, change and erase the protected files of the
drive. Turn it off only when a password is lost. Give the label a password, or anyone can turn
protection off.

### 6.6 SET (Section 7)

```
SET d:[RO]        SET d:[RW]
SET [option=modifier]
SET d:[option=modifier]
SET filespec [option=modifier]
SET filespec [option]
SET [HELP]
```

Without a drive, SET acts on the default drive. Options in one bracket are separated by commas.
More than one file or drive goes on one line with commas between them.

**Drive label options** (§7.2.1, §7.3, §7.4.5). The label is a directory entry. The first label
option makes it, with the name `Label`.

| Option | Effect |
|---|---|
| `[PASSWORD=pw]` | The label password. `[PASSWORD=<cr>]` removes it. |
| `[PROTECT=ON]` / `[PROTECT=OFF]` | File passwords on or off for the drive |
| `[CREATE=ON]` | Create stamps. Turns `ACCESS` off. |
| `[ACCESS=ON]` | Access stamps. Turns `CREATE` off. A read or a write is an access, a directory listing is not. |
| `[UPDATE=ON]` | Update stamps |
| `[MAKE=ON]` / `[MAKE=OFF]` | Make an XFCB for each new file. Each stamp option turns it on. Create stamps need it on. |
| `[NAME=name.typ]` | The label name |
| `[DEFAULT=pw]` | The default password of this console only (§7.2.3) |

When the label has a password, SET asks `Password ?` for each label change. The password is not
echoed. `^X` and `^H` work at the prompt. After each label change, SET shows the label as SHOW
LABEL does.

The label password is the "super password". With it, a user can turn protection off for the drive
and read every file. A lost label password cannot be removed.

**File options** (§7.2.2, §7.3.2, §7.4):

| Option | Effect |
|---|---|
| `[PASSWORD=pw]` | Give the file a password. Protection must be on for the drive. A new password gets mode READ. |
| `[PROTECT=READ]` | The password is needed to read, copy, write, erase or rename |
| `[PROTECT=WRITE]` | The password is needed to write, erase or rename |
| `[PROTECT=DELETE]` | The password is needed to erase or rename |
| `[PROTECT=NONE]` | Remove the password |
| `[TIME]` | Give an existing file an XFCB, for its stamps |
| `[RO]` / `[RW]` | Read-only / read-write |
| `[SYS]` / `[DIR]` | System / directory |
| `[ARCHIVE=ON]` / `[ARCHIVE=OFF]` | The archive attribute |
| `[F1=ON]` … `[F4=OFF]` | The user attributes |

SET prints the password only when it sets a new one. To change the mode of a protected file
without the password in the line, SET asks for it.

**Time stamps** (§7.3). Turn the stamp on for the drive. New files then get stamps. For the files
that already exist, also give each one `[TIME]`. Choose create or access stamps for a drive and
keep it. After a change from access back to create, old access dates show in the Create column.
ED makes a new file and renames the old one to `.BAK`, so an edit changes the create stamp as
well as the update stamp (§7.3.1). Stamps have the date, the hour and the minute.

**Recommended setting for commands** (§7.6). Put the `.PRL` and `.COM` files in user 0 of the
system drive and type:

```
0A>SET *.PRL [RO,SYS], *.COM [RO,SYS]
A:ABORT    PRL set to system (SYS), read only (RO)
...
```

Every user can then run them, and nobody erases them by mistake.

### 6.7 MPMSTAT, ATTACH, ABORT (Section 8)

**MPMSTAT** (§8.1) shows the top of memory, the number of consoles, the breakpoint RST, the
dispatcher options, and lists of processes: ready, waiting on a queue (read or write), delayed,
polling, waiting on a flag, attached to and waiting for each console and printer. It also lists
the queues, the flags that are set, and the memory segments. Names in capitals are commands a
console can type. The display is longer than one screen, so use `^S`.

```
Memory Allocation:
  Base = 8C00H  Size = 7400H  Bank = 00H  Allocated to MP/M II [0]
  Base = 0000H  Size = C000H  Bank = 01H  Allocated to MPMSTAT [1]
  Base = 0000H  Size = C000H  Bank = 02H  * Free *
```

The number in brackets is the console that started the process. The sample processes: `Tmp0`–`Tmpn`
(one for each console), `CLI`, `ATTACH`, `Idle`. The sample queues: `CliQ`, `ATTACH`, `MXList`,
`MXDisk`. The sample flags: `01 Tick`, `02 Clock`.

**ATTACH programname** (§8.2). Attach a detached program to this console. It must be the console
it was detached from. The program can be anywhere in the line of programs that wait.
`Attach failed` means the program was not detached.

**ABORT** (§8.3)

```
ABORT programname        a detached program of this console
ABORT programname n      a program attached to console n
```

`Abort failed` if it cannot. The user number does not matter. An RSP cannot be aborted. Use `^C`
for the program attached to your console, and ABORT for a detached one.

### 6.8 TYPE, ERA, ERAQ, REN (Section 9)

**TYPE** (§9.1)

```
TYPE filespec
TYPE filespec [PAGE]     stop every 24 lines, a key continues
TYPE filespec [Pn]       stop every n lines
```

TYPE expands tabs to every 8 columns. It needs one file, without wildcards. If the password is
missing, TYPE asks for it and does not echo it. `No file` if not found. `^P` before RETURN also
prints the file.

**ERA** (§9.2)

```
ERA filespec
ERA filespec [XFCB]      erase only the XFCBs (passwords and stamps)
```

ERA takes wildcards. It asks `Confirm delete all user files (Y/N)?` for each `*.*`, with a drive
or without. It cannot erase on a read-only drive. If the password is missing, ERA asks for it:

```
0A>ERA B:DOCUMENT.LAW
Not erased: B:DOCUMENT.BAK Password Error
Password ?
```

**ERAQ** (§9.3) is ERA with a query `?` for each file. It also takes `[XFCB]`.

**REN** (§9.4)

```
REN newname.typ = oldname.typ
REN newname.typ = d:oldname.typ
REN newname.typ = d:oldname.typ;password
```

- Both names must be on the same drive.
- Wildcards work if the wildcard parts of both names match: `REN *.TEX=*.WRK`.
- The password goes with the file.
- If the new name exists: `Not renamed: B:ADDPROG.ASM already exists, delete (Y/N)?`
- If the old name does not exist: `No such file to rename`.

### 6.9 TOD, SCHED, PRINTER, SPOOL, STOPSPLR, SUBMIT (Section 10)

**TOD** (§10.1)

```
TOD                         Wed 07/08/81 01:18:24
TOD PERPETUAL  (or TOD P)   show the time until a key
TOD mm/dd/yy hh:mm:ss       "Strike key to set time", then the key sets it
```

**SCHED mm/dd/yy hh:mm command line** (§10.2). SCHED waits for the date and time, then runs the
command. It needs `SCHED.RSP` and `SCHED.BRS` resident and `SCHED.PRL` on the disk. Set the time
with TOD first.

**PRINTER** (§10.3). `PRINTER` shows `List Number = n` for this console. `PRINTER n` sets it.
Printers are numbered from 0. Consoles can share a printer, but one process at a time has it.

**SPOOL** (§10.4)

```
SPOOL filespec
SPOOL filespec, filespec ...
SPOOL filespec [DELETE]     erase each file after it is printed
```

| SPOOL is | Message | Limit |
|---|---|---|
| `SPOOL.PRL` | `MP/M II V2.0 Spooler`, `Enter STOPSPLR to abort the spooler.`, `Enter ATTACH SPOOL to reattach console to spooler`, `***Spooler detaching from console***` | One for each free memory segment. Tail up to 94 characters. |
| An RSP | None | 3 SPOOL commands in the queue in total. Tail up to 60 characters. |

**STOPSPLR** (§10.5). Stop the spooler and empty its queue. `STOPSPLR n` stops the `SPOOL.PRL`
of console n. For the RSP, STOPSPLR from any console stops it. With nothing to stop:
`Spooler not running`.

**SUBMIT** (§10.6)

```
SUBMIT filespec
SUBMIT filespec p1 p2 p3 ...
```

1. Write `name.SUB` with ED, one command on each line.
2. Use `$1`, `$2`… for the parameters. `$$` is one `$`. A line that starts with `;` is a
   comment, and MP/M II echoes it.
3. SUBMIT writes `$n$.SUB` on the temporary file drive, with the parameters put in. n keeps the
   batches of different consoles apart. The file has a special format, so TYPE cannot show it.
4. MP/M II runs the lines and shows each one. At the end it erases `$n$.SUB`.

- A missing parameter becomes nothing. An extra parameter is ignored.
- A SUBMIT inside a `.SUB` file must be the last line (chaining).
- `$INCLUDE name p1 p2 ...` puts another `.SUB` file in place of the line, with its own
  parameters. The `.SUB` type is optional. Up to 4 levels (§10.6.4).
- An error in a line prints a message, and the batch goes on to the next line.
- `^C` asks `Terminate Submit?`. `Y` stops the batch and then asks `ABORT (Y/N) ?` for the running
  program. `N` continues the batch.
- `Error on line nnn no 'SUB' file present` when the `.SUB` file is not found.

### 6.10 PIP (Section 11)

```
PIP
PIP destination [Gn] = source [options], source [options] ...
```

- `PIP` alone prints `MP/M II PIP VERSION 2.0` and the prompt `*`. A blank line returns to
  MP/M II (§11.1).
- The destination needs a drive or a name, or both. The source does too.
- The source and the destination can be the same drive and name only if the user numbers
  differ.
- Many sources, separated by commas, are joined into one destination file in order. They must
  be ASCII, unless `[O]` is given.
- PIP opens the sources read-only, so other users can read them during the copy.
- A locked or protected source is skipped with a message, and the copy goes on.
- `^C` stops PIP. A key stops a copy to a device. For a detached PIP, use ABORT from another
  console.

**How a disk copy works** (§11.2)

1. If the destination exists, PIP checks that it can open it, and stops if it cannot.
2. PIP writes `name.$$$` on the destination drive.
3. At the end, PIP erases the old destination file. If it is `RO`, PIP asks
   `DESTINATION IS R/O, DELETE (Y/N)?`. `N` gives `NOT DELETED` and stops the copy.
4. PIP renames `name.$$$` to the destination name.

If PIP stops halfway, erase the `.$$$` file yourself. Short forms: `PIP B:=A:TOD.PRL`,
`PIP B:TOD.PRL=A:`, `PIP APP1.ASM=B:`. A wildcard source copies each match and prints its
name after `COPYING`. An ASCII file ends at `^Z`. A file whose length is a multiple of 128 has
no `^Z`.

**Passwords and attributes** (§11.3). Only one password can be given for a wildcard copy. PIP
tries it, then the default password. A file that fails is skipped. The destination password:

| Destination | Password of the copy | Mode of the copy |
|---|---|---|
| A name with `;pw` | `pw` | READ |
| A name without a password | None | |
| A drive only | The password of the source | The mode of the source |

The copy keeps `RO`/`RW`, `SYS`/`DIR` and F1–F4.

**Devices** (§11.4, Tables 11-1 and 11-2)

| Name | Device |
|---|---|
| `CON:` | The console. As a source, end each line with RETURN and line feed, and the input with `^Z`. |
| `LST:` | The printer of this console |
| `NUL:` | Source: 40 nulls |
| `EOF:` | Source: one `^Z`. PIP adds a `^Z` to each ASCII copy anyway. |
| `PRN:` | Destination: `LST:` with `[T8NP]`: tabs every 8, line numbers, a page eject first and every 60 lines |

**Options** (§11.5, Table 11-3). They follow the source file. No space between the letter and
its value. `Gn` is the only option a destination takes.

| Option | Effect |
|---|---|
| `A` | Copy only the files with the archive attribute off, then set it. Needs a wildcard. |
| `Dn` | Delete the characters after column n |
| `E` | Echo the data on the console (ASCII) |
| `F` | Remove form feeds. With `P`, new page breaks. |
| `Gn` | Source: read from user n. Destination: write to user n. n = 0–15. |
| `H` | Check Intel hex records and remove the characters between them. Asks to fix a bad record. |
| `I` | Ignore `:00` records. Sets `H`. |
| `K` | Do not list the file names, so PIP can be detached during a long copy |
| `L` | Upper case to lower case |
| `N`, `N2` | Line numbers. `N2` adds zeroes and a tab. |
| `O` | Object file: ignore `^Z` in a join |
| `Pn` | A page eject first and every n lines (60 if n is 1 or not given) |
| `Qs^Z` | Stop after the string s |
| `R` | Read `SYS` files. The copy keeps the attributes. |
| `Ss^Z` | Start at the string s. With `Q`, extract a part. Both strings are copied. |
| `Tn` | Expand tabs to every n columns |
| `U` | Lower case to upper case |
| `V` | Read the destination again and compare. The destination must be a disk file. |
| `W` | Write over an `RO` file without a question. On the last source of a join. |
| `Z` | Clear bit 7 of each byte (ASCII) |

The strings of `Q` and `S` keep lower case only when PIP was started without a tail (from the
`*` prompt).

Examples: `PIP B:=A:*.PRL[VWR]` updates a system disk. `PIP F:[G3]=E:USERFILE.DAT` copies to user
3. `PIP B:=*.*[A]` backs up the changed files.

**Messages** (§11.6, Table 11-4). Errors start with `ERROR:`, and a message can join several of
these:

| Message | Meaning |
|---|---|
| `ALREADY EXISTS` | The temporary file is on the destination already. Erase or rename it. |
| `BAD PARAMETER` | An unknown option |
| `CAN'T DELETE TEMP FILE`, `CLOSE FILE`, `MAKE FILE`, `OPEN FILE` | Part of another message |
| `CHECKSUM ERROR` | A bad checksum in a hex record |
| `CORRECT ERROR, TYPE RETURN OR CTL-Z` | `[H]`: type the record again, or `^Z` to stop |
| `DISK READ`, `DISK WRITE` | A bad sector. Can be the wrong density. |
| `END OF FILE, ^Z, ?` | An early end of file in a hex copy |
| `FCB CHECKSUM` | The destination FCB is damaged. Can be bad memory. |
| `FILE NOT FOUND` | No source file |
| `INCOMPATIBLE MODE` | Another process opened the file in a mode that conflicts (locked or read-only) |
| `INTERNAL LOCK LIMIT EXCEEDED` | More locked records than GENSYS allows |
| `INVALID DESTINATION`, `INVALID SOURCE` | A bad device |
| `INVALID DIGIT` | A bad hex digit (`[H]`) |
| `INVALID DISK SELECT` | The drive does not exist |
| `INVALID FILENAME` | A wildcard in the wrong place |
| `INVALID FORMAT` | A syntax error |
| `INVALID PASSWORD` | A wrong or missing password |
| `INVALID SEPARATOR` | A bad character between the files of a join |
| `INVALID USER NUMBER` | `Gn` outside 0–15 |
| `LIMIT EXCEEDED` | More open files than GENSYS allows |
| `NO DIRECTORY SPACE` | The destination directory is full |
| `NONRECOVERABLE` | A defect on the disk, the wrong density, a disk not put in correctly, or the door open |
| `PRINTER BUSY` | Another process has the printer |
| `QUIT NOT FOUND`, `START NOT FOUND` | The string of `Q` or `S` is not in the source |
| `RECORD TOO LONG` | A hex record longer than 80 characters |
| `REQUIRES MP/M II` | PIP runs on another operating system |
| `R/O DISK`, `R/O FILE` | The destination drive or file is read-only |
| `VERIFY` | `[V]` found a difference |
| `USER ABORTED` | A key during a device copy. Look for `.$$$` files. |

## 7. ED, the editor (Section 12)

```
ED filespec          edit or create the file
ED filespec d:       write the new file on d:. At the end, d: is the default drive.
```

ED asks for a password if the file has one. A new file prints `NEW FILE`. The prompt is `*`,
with the line number before it (`1: *`).

**Files** (§12.1, Figures 12-1 and 12-2). ED reads the source `x.y` into a memory buffer with
`A`, and writes the buffer to the temporary file `x.$$$` with `W`. At the end (`E`), it renames
`x.y` to `x.BAK` and `x.$$$` to `x.y`. `R` reads a `.LIB` file into the buffer. Editing goes one
way: lines written out cannot be edited again without `H`. The disk needs free space at least
as large as the file. If the disk or the directory fills, ED loses the edit.

**Pointers** (§12.2). SP is the next character of the source to read. MP is the end of the
buffer. TP is the next free place in the temporary file. CP is the character pointer, between
two characters in the buffer. A positive count acts after the CP, a negative count before it.

**Command form** (§12.4). An optional count, then a letter, sometimes a string. No count means 1.
`#` means all. `0` means "half the buffer" for `A` and `W`, "this line" for `L`, `P`, `T`.
Several commands can go on one line, left to right:

- The line is up to 128 characters, and a string up to 100.
- A string that another command follows ends with `^Z`. The last string of a line can end with
  RETURN.
- `E`, `H`, `O` and `Q` must be alone on their line.

The upper-case letters of `I`, `F`, `S`, `N` and `J` translate the string to upper case. `U` turns
the translation on for all input. `-U` turns it off. In a string, `^L` is a RETURN and line
feed, and `^I` is a tab. In insert mode, `^P`, `^S` and `^C` do not work. Tab stops are columns
9, 17, 25 and so on. They cannot be changed.

**Commands** (Table 12-2):

| Command | Action |
|---|---|
| `nA` | Append n lines from the source to the buffer. `#A` all, `0A` until half full. |
| `B`, `-B` | Move the CP to the start / the end of the buffer |
| `nC`, `-nC` | Move the CP n characters |
| `nD`, `-nD` | Delete n characters after / before the CP. Deleting the RETURN and line feed joins two lines. |
| `E` | Write everything, rename the files, exit |
| `nFs` | Find the n-th s in the buffer. `F` makes s upper case. `f` finds the exact case. |
| `H` | Write everything, then start a new edit of the same file (head of file) |
| `I` | Insert mode until `^Z` |
| `Is^Z` | Insert s. Ended with RETURN, it also inserts a RETURN and line feed. |
| `nJs^Zi^Zd` | Find s, insert i after it, delete up to d. Without d, end with two `^Z`. |
| `nK`, `-nK` | Kill n lines. `#K` to the end. In the middle of a line, only the rest of the line. |
| `nL`, `-nL`, `0L` | Move the CP n lines, to the start of a line |
| `nMcmds` | Run the commands n times. No n: until an error. It ends with a `BREAK`. It must be last on the line. |
| `n`, `-n` | Move n lines and show the line. RETURN alone is `1`. |
| `n:` | Go to line n |
| `:ncmd` | Do the command up to line n. `5::12T` shows lines 5–12. |
| `nNs` | Find s in the whole file: write the buffer and append more until found |
| `O` | Abandon the changes and start again. Asks `O-(Y/N)?`. |
| `nP`, `-nP`, `0P` | Show the next 23 lines and move the CP there. `0P` shows the page without a move. |
| `Q` | Abandon the new file and exit. Asks `Q-(Y/N)?`. The source does not change. |
| `R`, `Rname` | Read `X$$$$$$$.LIB`, or `name.LIB`, at the CP. A space is not allowed before the name. |
| `nSs^Zi` | Substitute i for s, n times, in the buffer |
| `nT`, `-nT`, `0T` | Type n lines. No move. `T` alone types to the end of the line. |
| `U`, `-U` | Upper-case translation on / off |
| `V`, `-V`, `0V` | Line numbers on / off. `0V` shows `free/total` buffer space. |
| `nW`, `0W` | Write n lines to the temporary file. `0W` writes half the buffer. |
| `nX`, `0X` | Write n lines to `X$$$$$$$.LIB`, appended if it exists. `0X` erases it. |
| `nZ` | Wait n seconds (to abort a macro with a key) |

To move a block: `nX`, then `nK`, then move the CP and `R` (§12.4.8). ED erases
`X$$$$$$$.LIB` when it starts and at `E` or `Q`. A `^C` leaves it on the disk.

Do not edit a `.BAK` file. At `E`, ED erases the `.BAK`, cannot find the file to rename, and
stops without saving. Rename the file first (§12.4.9).

**Errors** (§12.5, Tables 12-3 and 12-4). The form is `BREAK "x" AT c`, where c is the command:

| x | Meaning |
|---|---|
| `#` | Search failed (`F`, `S`, `N`). After `F`, the CP has not moved. After `N`, the source is at its end: use `H`. |
| `?` | Unknown command, or `E`, `H`, `Q`, `O` not alone on the line |
| `O` | The `.LIB` file of `R` is not found |
| `>` | The buffer is full, or a string is too long. After `A`, use `W` to make room. |
| `E` | A key stopped the command |

| Disk message | Meaning |
|---|---|
| `Bdos Error On d: R/O` | The drive is read-only: a disk change without a reset, or set read-only |
| `DISK OR DIRECTORY FULL`, `FILE ERROR` | Fatal. The edit is lost. |
| `FILE IS READ ONLY` | ED shows an `RO` file but cannot change it |

## 8. Error messages (App. D)

BDOS errors print as:

```
Bdos Err on d: Message
Bdos Function: NNN  File: FILENAME.TYP
```

| BDOS message | Meaning |
|---|---|
| `File Opened in Read/Only Mode` | A locked or unlocked open of a file that is open read-only |
| `File Currently Open` | The file is open in a mode other than read-only by another process |
| `Close Checksum Error` | The directory on the disk differs from the one in memory. Usually a disk change without a reset. |
| `Password Error` | A wrong or missing password |
| `File Already Exists` | Make or rename to a name that exists |
| `Illegal ? in FCB` | A wildcard where none is allowed |
| `Open File Limit Exceeded` | More open files than the process may have |
| `No Room in System Lock List` | More locked records than the process may have |
| `Bad Sector` | A disk error: the wrong density, or a disk not put in correctly |
| `Select` | The drive does not exist, or has no disk |
| `R/O` | A write to an `RO` file or drive |

| Command line message (Table D-2) | Meaning |
|---|---|
| `Prg ld err` | A `.COM` file does not fit in the absolute TPA at 0000h |
| `Abs TPA not free` | No segment that starts at 0000h is free |
| `Reloc seg not free` | No segment is large enough for the `.PRL` file |
| `Blank file type rqd` | The command name has a type |
| `Queue full` | The queue of that RSP is full |
| `Bad entry` | A badly formed command |

The `File Currently Open` example of §8.2: while `DUMP E:TYPE.PRL` runs detached, `E:TYPE` on the
same console gives `Bdos Err on E: File Currently Open`, `Bdos Function: 15 File: TYPE.PRL`.

## 9. File types (App. B)

| Type | Meaning |
|---|---|
| `ASM` | Assembler source |
| `BAK` | The old version that an editor keeps |
| `BRS` | The banked part of an RSP |
| `COM` | A command at 0100h |
| `HEX` | Intel hex |
| `IRL` | An indexed library from LIB |
| `LST` | A file to print |
| `PRL` | A page-relocatable command. It runs in any free segment. |
| `PRN` | An assembler listing |
| `REL` | A relocatable module from RMAC |
| `RSP` | A resident system process. It needs no memory segment, so it runs when all are in use. |
| `SPR` | A system page-relocatable file: `BNKBDOS.SPR`, `RESBDOS.SPR`, `XDOS.SPR`, the XIOS |
| `SUB` | A SUBMIT file |
| `TEX` | TEX-80 source |
| `TXT` | Text |
| `XRF` | XREF output |
| `$$$` | A temporary file |
| `$n$` | The SUBMIT file of console n |

## 10. Other appendixes

- **App. F** gives the syntax and examples of 30 commands, ten of them from the other guides:
  `ASM filename.shp` (s = source drive, h = HEX drive or Z, p = PRN drive or X or Z: Z means no
  output, X means the console). `GENHEX file.COM offset`. `GENMOD file.HEX file.PRL $nnnn`
  (`$nnnn` adds memory). `GENSYS $A` (all defaults from `SYSTEM.DAT`). `LIB name[I|M|P]=mod1,...`.
  `LINK name=mod1,...[OS]` makes an `.SPR`. `LOAD file.HEX`. `PRLCOM file.PRL file.COM`.
  `RDT filespec`. `RMAC filename $options`. `XREF filename $P`.
- **App. G** compares the commands of CP/M 1.4, CP/M 2, MP/M 1 and MP/M II. New in MP/M II:
  RMAC, SDIR, SET, SHOW and XREF. LIB and LINK were sold separately before. `SAVE`, `SYSGEN`
  and `MOVCPM` are CP/M only, and `XSUB` is CP/M 2 only.
- **App. H** says which command shows what: size (SDIR, STAT), attributes (DIR, SDIR, STAT),
  stamps and protection (SDIR only), label (SHOW LABEL only), active users (SHOW USERS, STAT USR:).
- **App. I** is a glossary. Two facts in it: a "terminal" that cannot start programs is not a
  console, and MP/M II has up to 8 consoles and 8 such terminals. A drive stays "logged in"
  until a DSKRESET or a reset of the system.

## 11. On the machines of this folder

The guide describes MP/M II V2.0. The disks of this folder are V2.1. These GENSYS choices of
`mpm2.toml` and `mpm2-ss1.toml` change what the guide says:

| Guide | Here |
|---|---|
| Up to 8 consoles | 2 consoles. Console 1 starts in user 1 (`1A>`). |
| Day-file option | Off. No time line after a command. |
| System drive and temporary file drive | Both A: |
| Resident utilities | ABORT and MPMSTAT are RSPs. SCHED and SPOOL are not. §10.2 says that SCHED needs `SCHED.RSP` and `SCHED.BRS` resident, so SCHED does not run here (not tested). SPOOL runs as `SPOOL.PRL`. |
| LIB, LINK, RMAC, XREF | Not on `MPM2.DSK` |
| The sample's segments of 48K (`C000H`) | Two segments of about 15K. SDIR does not fit in a segment. |
| Time stamps | They work. Set the date with TOD after each boot of `mpm2.toml`. `TOD` takes years 78–99. |
| Printer | GENSYS has 1 printer, but the machines have none |

## Quirks worth carrying

- ⚠ **The page numbers do not agree.** The contents and the index give one number, the page
  footer another, the PDF a third. For example, DSKRESET is p.29, p.34 and PDF page 43. This file
  cites sections only.
- ⚠ **The section numbers in the text are wrong in places.** §3.1 says "Section 12, PIP" and
  "Section 11, ED". PIP is Section 11 and ED Section 12. §3.1.5 sends wildcards to "Section 3.3".
  They are §3.2. §6.4.2 sends the block size to "Section 6.3.1". It is §6.4.1. §11.2 sends the
  `W` option to "Section 11.4". It is §11.5. App. E sends SET to "Section 6". It is Section 7.
  The Foreword gives the utilities in "Sections 5 through 13". They are 5 through 12.
- ⚠ **`<` and `>`.** Table 3-1 reserves `< > &` for I/O redirection. The text under it says they
  are "reserved for future use". Neither guide describes redirection.
- ⚠ **DSKRESET and the default drive.** §5.1 says DSKRESET without a tail resets all the drives.
  App. F says it "logs out all or specified drives except for the default drive". (Unresolved.)
- ⚠ **STOPSPLR n.** The syntax in §10.5 has no `n`, but the text and App. F use `STOPSPLR n`.
- ⚠ **ABORT example.** §8.3 aborts `TYPE` on console 1 with `ABORT TYPE 1` typed at a `5B>`
  prompt, and calls that console 3. The prompt shows the user number, not the console.
- ⚠ **§7.6 password.** The example sets `PASS=123` and then says the files need "the password
  23". The OCR may have lost a digit. 123 is the password.
- ⚠ **Exit to "the CCP".** §12.4.9 says `E` and `Q` return control to the CCP. MP/M II has no CCP.
  The console's TMP takes the next command. The text is left over from CP/M.
- ⚠ **"MP/M II V2.0".** The boot message, the spooler and PIP print V2.0 in the guide. The disks
  here print V2.1. PIP's `REQUIRES MP/M II` message speaks of version 2.0.
- ⚠ **OCR in the samples.** The samples show `OA>` for `0A>`, `IA>` for `1A>`, `l` for `1`, `O` for
  `0` in hex (`8DOOH`). This file uses the correct characters. The OCR also writes `TD`, `TS`,
  `TP`, `TQ`, `TX`, `TZ` for `^D`, `^S`, `^P`, `^Q`, `^X`, `^Z`.
- ⚠ **Figure numbers.** Section 1 calls three figures "Figure 11", "Figure 11" and "Figure 13".
  They are Figures 1-1, 1-2 and 1-3.
