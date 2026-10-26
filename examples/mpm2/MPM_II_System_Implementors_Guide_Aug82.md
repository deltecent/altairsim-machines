# Digital Research MP/M II — System Implementor's Guide (XIOS, LDRBIOS, GENSYS)

Source: `MPM_II_System_Implementors_Guide_Aug82.pdf` (*MP/M II Operating System, System
Implementor's Guide*, © 1981 Digital Research), 173 PDF pages, **OCR text layer** (Acrobat Paper
Capture, 2010). The OCR has errors in prose and listings ("Digi tal", `0`/`O` swaps), so every table
and number below was read from the page image. Page numbers are the **printed** ones. Printed
page N is PDF page N+9.

MP/M II is DRI's multi-user, multi-tasking operating system for the 8080, 8085 and Z80. DRI ships
the logical parts finished: the XDOS nucleus, the BDOS (resident and banked parts), the TMP, the
resident system processes and the utilities. A site writes three hardware parts:

- the **XIOS**, which is the BIOS plus the MP/M extensions
- the **LDRBIOS**, a small CP/M 2 BIOS that the loader uses
- the **cold-start loader**

The guide is the specification for those three parts. MP/M II is also the server for CP/NET,
which [`../cpnet/README.md`](../cpnet/README.md) covers.

This file keeps what an XIOS writer needs: the build chain, the boot and disk layout, the BIOS and
XIOS entry points, the interrupt and clock rules, the system data page, the GENSYS questions and
the loader. It leaves out the DISKDEF macro source (App. A), most of the deblocking listing
(App. B) and the full Appendix D listing. Section 7 gives each sample's hardware. The last section
of this file is the full Appendix E listing.

---

## 1. Quick reference for an XIOS writer

| What | Value | Where |
|---|---|---|
| Parts the site writes | `BNKXIOS.SPR` (banked memory) or `RESXIOS.SPR` (no banks), `LDRBIOS`, the cold-start loader | §1, p.1 |
| Precondition | A working CP/M 2 BIOS on the target machine. MPMLDR loads MP/M II through a CP/M 2 BIOS (the LDRBIOS). | §1.1, p.1 |
| Build the XIOS | `RMAC BNKXIOS`, then `LINK BNKXIOS[OS]` gives `BNKXIOS.SPR` | §1.3, p.3 |
| Build the system | `GENSYS` (under CP/M or MP/M II) writes `MPM.SYS`. `GENSYS $A` takes every default. | §5, p.51–57 |
| Load the system | `MPMLDR` reads `MPM.SYS` (user 0) and jumps to it | §6, p.59 |
| LDRBIOS origin | `ORG 1700H`. Needs only console output, `SELDSK` and disk reads from one drive. | §1.2, p.2 |
| LDRBIOS top | Below `1A00H` if MPMLDR must fit on two floppy system tracks (⚠ see Quirks) | §1.2, p.2 |
| First LDRBIOS call | `SELDSK`. Put device initialization there. | §1.2, p.2 |
| BIOS vector | 17 jumps, `BIOS+00H`–`BIOS+30H` (§3 below) | §2.1, p.15 |
| XIOS vector | 8 jumps right after it, `BIOS+33H`–`BIOS+48H` (§4 below) | §3.1, p.39 |
| First development step | Polled I/O and no interrupts. The system runs without a clock interrupt. Add interrupts last. | §1.3, p.3 |
| System tick | Flag #1 at each tick while `STARTCLOCK` is in effect. 60 Hz (16.67 ms) is recommended. At 50 Hz, use 20 ms. | §3.4, p.44 |
| One-second flag | Flag #2, once each second, always | §3.4, p.44 |
| Only call from an interrupt handler | XDOS function 133, Flag Set. End the handler with a jump to `PDISP`. | §3.3, p.44 |
| Consoles | Up to 16 character devices. Up to 8 are system consoles with a TMP. | §2.2, p.16; §5.2.3, p.53 |
| Printers | Up to 16 list devices | §2.2, p.16 |
| Disks | Up to 16 drives, A–P | Table 2-1, p.19 |
| Flags | 32 under MP/M II | §3.3, p.44 |
| Disk retries | 10 before an error is returned | §2.2, p.16 |

## 2. Alteration procedure (Section 1)

### 2.1 Put a LDRBIOS into MPMLDR.COM (§1.2, p.2–3)

1. Assemble `LDRBIOS.HEX` at `ORG 1700H`.
2. `DDT MPMLDR.COM`. DDT shows `NEXT 1780`, `PC 0100`.
3. `ILDRBIOS.HEX`, then `R`. The LDRBIOS part of the loader is overlaid. DDT shows `NEXT 1A00`.
4. `G0` returns to the CCP.
5. `SAVE 26 XMPMLDR.COM`. Test it, then rename it to `MPMLDR.COM`.

Make sure that the LDRBIOS never writes to the disk during a read.

### 2.2 Debug an XIOS under CP/M (§1.4, p.4–6)

1. Load DDT and list location `0005`. The jump goes to the base of DDT (`C800` in the example).
2. Run GENSYS under CP/M. Set the top page below DDT, with at least 256 bytes for patches (`C6` in
   the example). Give MP/M II a breakpoint RST other than DDT's, which is RST 7. The guide
   suggests RST 6.
3. `DDT MPMLDR.COM`. Put `$B` at `005D`–`005E` (in the default FCB at `005C`) with `I$B`. MPMLDR
   then breaks to DDT after it loads `MPM.SYS`. A fourth character gives the CP/M debugger's
   RST: `I$B6`. The default is 7.
4. `G`. The loader prints the memory map. Note the addresses of the XIOS and of `SYSTEM.DAT`.
5. `X` shows the PC at the RST. MP/M II starts at the next byte (`09F3` in the example).
6. Start it with `G09F3,<breakpoint>`. The example breaks on the XIOS list entry, `C30F`, when
   `XIOSJMP TBL` is at `C300H`.

DDT runs with interrupts enabled. Keep console #0 polled while you debug, because DDT gets no
input through an interrupt-driven console #0 handler. The guide recommends a debug build of the XIOS
with console #0 polled.

### 2.3 Boot MP/M II directly (§1.5, p.6–10)

The cold-start loader and MPMLDR go on the first two tracks of an 8" disk. Change the CP/M 2
cold-start loader to load at `0100H` and run at `0100H`. The examples are for the Intel MDS-800,
whose boot ROM loads track 0 sector 1 at `3000H`.

- **With SYSGEN:** in DDT, `IMPMLDR.HEX`, `R880`, then `IBOOT.HEX`, `RD900` (the boot lands at
  `0900H`). `G0`, then `SYSGEN` with no source and a destination drive.
- **Without SYSGEN:** write a GETSYS at `0100H` that reads the boot to `3300H` and MPMLDR to
  `3380H`. Write a PUTSYS at `0200H` that writes memory from `3380H` back to tracks 0 and 1.
  The guide prints skeletons of both (§1.5.3, p.9–10). They read sectors 1–26 of tracks 0 and 1,
  128 bytes each.

### 2.4 Disk organization (§1.8, Table 1-2, p.12–13)

Two tracks of 26 sectors of 128 bytes, IBM 3740 single density:

| Track | Sectors | Memory | Contents |
|---|---|---|---|
| 0 | 1 | boot address | Cold-start loader |
| 0 | 2–25 | `0100H`–`0CFFH` | MPMLDR |
| 0–1 | T0 26, T1 1–19 | `0D00H`–`16FFH` | LDRBDOS |
| 1 | 20–26 | `1700H`–`1A7FH` | LDRBIOS |

If the controller has no built-in load of track 0 sector 1, start the load at track 0 sector 2.

### 2.5 MPM.SYS file format (§1.6, Table 1-1, p.11)

| Record | Contents |
|---|---|
| 1 | First 128 bytes of the system data page |
| 2 | Second 128 bytes of the system data page |
| 3–n | The operating system, in reverse order, top down |

Byte `000` of the system data page gives its page in memory. The rest of the system goes directly
below it. Bytes `120`–`121` hold n. Byte `011` (XDOS base page) gives the execution address. A
custom loader can place `MPM.SYS` without MPMLDR.

## 3. The BIOS part (Section 2)

### 3.1 Jump vector (§2.1, p.15)

| Offset | Entry | MP/M II use |
|---|---|---|
| `00H` | `COMMONBASE` | Start of the part that must be in common memory. Calling it ends the process. |
| `03H` | `WBOOT` | XDOS terminate process (function 0) |
| `06H` | `CONST` | Console status. Console number in **D**. `0FFH` = ready. |
| `09H` | `CONIN` | Console input from console **D**. Parity bit 0. |
| `0CH` | `CONOUT` | Character in **C** to console **D** |
| `0FH` | `LIST` | Character in **C** to list device **D** |
| `12H` | `PUNCH` | Not used |
| `15H` | `READER` | Not used |
| `18H` | `HOME` | Track 0 |
| `1BH` | `SELDSK` | Drive in **C** (0–15). **E** bit 0 = 0 on the first select. Returns the DPH address in HL, or `0000H`. |
| `1EH` | `SETTRK` | Track in **BC** |
| `21H` | `SETSEC` | Translated sector in **BC** |
| `24H` | `SETDMA` | DMA address in **BC**. **`0FFFFH` means flush the blocking buffer.** |
| `27H` | `READ` | Returns **A** = 0 or 1 |
| `2AH` | `WRITE` | Write type in **C**. Returns **A** = 0, 1, or 2 (read-only). |
| `2DH` | `LISTST` | List status of device **D**. Not used by the standard utilities. |
| `30H` | `SECTRAN` | Logical sector in **BC**, table in **DE**, physical sector in HL |

Rules that differ from CP/M 2.2 (Table 2-1, p.17–23):

- Every character entry takes a **device number in D** and must be re-entrant.
- Every entry except the disk entries must be above `COMMONBASE`, in common memory.
- `READ` and `WRITE` also get the **absolute record number**: the high byte in B and the low two
  bytes in DE.
- A flush (`SETDMA 0FFFFH`) that fails pops its return address and returns an error in A:
  1 = non-recoverable, 2 = read-only.
- On an error, the BDOS prints `BDOS ERR ON x: BAD SECTOR`. The process's error mode decides
  whether it ends or gets an error code.
- The first `SELDSK` only gets the `DIRBUF` address. It needs no disk I/O.
- The standard skew is 6. Keep a single-density IBM version with skew 6 for exchanging disks.

### 3.2 Disk tables (§2.3, p.24–33)

The Disk Parameter Header (16 bytes, one for each drive) is `XLT, 0000, 0000, 0000, DIRBUF, DPB,
CSV, ALV`. The Disk Parameter Block is `SPT(16) BSH(8) BLM(8) EXM(8) DSM(16) DRM(16) AL0(8)
AL1(8) CKS(16) OFF(16)`. These are the CP/M 2.2 tables. Table 2-4 (BSH/BLM) and Table 2-5 (EXM)
were read from the page image:

| BLS | BSH | BLM | EXM, DSM < 256 | EXM, DSM > 255 | Directory entries per block |
|---|---|---|---|---|---|
| 1,024 | 3 | 7 | 0 | N/A | 32 |
| 2,048 | 4 | 15 | 1 | 0 | 64 |
| 4,096 | 5 | 31 | 3 | 1 | 128 |
| 8,192 | 6 | 63 | 7 | 3 | 256 |
| 16,384 | 7 | 127 | 15 | 7 | 512 |

- `CKS` = (DRM+1)/4 for removable media. **`CKS = 8000H` marks a drive as permanent**, with no
  directory check. That is an MP/M II addition.
- The ALV area is (DSM/8)+1 bytes.
- `DISKDEF dn,fsc,lsc,[skf],bls,dks,dir,cks,ofs,[k16],[prm]`. The optional `prm` marks a
  permanent drive. The standard 8" drive is `DISKDEF 0,1,26,6,1024,243,64,64,2`. Its skew-6
  table is `1,7,13,19,25,5,11,17,23,3,9,15,21,2,8,14,20,26,6,12,18,24,4,10,16,22` (p.32).

### 3.3 Write types and deblocking (§2.5, p.36–37; App. B)

`WRITE` gets a write type in C:

| C | Meaning |
|---|---|
| 0 | Deferred write |
| 1 | Non-deferred write |
| 2 | Deferred write to the first sector of a new block |
| 3 | Non-deferred write to the first sector of a new block |

Types 0 and 2 occur only on permanent drives. Type 1 is also used for directory writes on a
permanent drive. The Appendix B algorithm skips the pre-read when bit 1 is set. Its sample host
has 512-byte sectors, 20 to a track, and 2,048-byte blocks.

### 3.4 What the BNKXIOS must keep in common memory (§2.6, p.37)

- Every BIOS and XIOS entry, except the disk entries
- The DPHs, the DPBs and `DIRBUF`
- All disk polling code and all interrupt handlers
- The code that moves data into the user's DMA buffer

A deblocking buffer can be in banked memory. That needs a 128-byte buffer in common memory and one
more move. The bank must not change while a controller does DMA into banked memory.

### 3.5 External procedures (§2.4, Table 2-7, p.33–35)

GENSYS fills in a jump vector at `COMMONBASE`:

```
COMMONBASE: JMP COLDSTART
SWTUSER:    JMP $-$     ; switch to the calling process's bank
SWTSYS:     JMP $-$     ; switch back to the BNKBDOS bank
PDISP:      JMP $-$     ; force a dispatch (end of an interrupt handler)
XDOS:       JMP $-$     ; XDOS functions
SYSDAT:     DW  $-$     ; address of the system data page (not a jump)
```

Call `SWTUSER` and `SWTSYS` only from common memory and only from the disk functions. Both disable
interrupts and then **enable** them again, even if interrupts were disabled before the call.

## 4. The XIOS part (Section 3)

### 4.1 Jump vector (§3.1, p.39)

| Offset | Entry | Rule |
|---|---|---|
| `33H` | `SELMEMORY` | BC points to a memory descriptor: base, size, attributes and bank, one byte each. Called from the dispatcher with interrupts disabled. Must not enable them. |
| `36H` | `POLLDEVICE` | Device number in C. Returns `0FFH` if ready, `00H` if not. Called in a critical region. Must not enable interrupts. |
| `39H` | `STARTCLOCK` | A process is on the delay list. Start setting flag #1 at each tick. |
| `3CH` | `STOPCLOCK` | The delay list is empty. Stop setting flag #1. |
| `3FH` | `EXITREGION` | If `PREEMPT` is true, leave interrupts disabled. If it is false, enable them. |
| `42H` | `MAXCONSOLE` | Number of physical consoles in A |
| `45H` | `SYSTEMINIT` | Cold-start initialization (below) |
| `48H` | `IDLE` | Optional. If it is not supplied, put three zero bytes here. |

Every entry must be above `COMMONBASE` (Table 3-1, p.39–43).

- **One clock for both time bases.** When a single timer gives the tick and the second,
  `STARTCLOCK` and `STOPCLOCK` set a flag byte. The interrupt handler tests it before it sets
  flag #1.
- **`SYSTEMINIT`.** MP/M II disables interrupts and calls `SYSTEMINIT` before any other XIOS call.
  It enables interrupts when `SYSTEMINIT` returns. Bank 0 is in place, and MP/M II has already
  set its base page. On entry:
  - **C** holds the MP/M debugger RST number.
  - **DE** holds the debugger entry. Put a jump to DE at that RST in each bank.
  - **HL** holds the BIOS direct jump table. Put a jump to HL at `0000H` in each bank.

  `SYSTEMINIT` also sets the interrupt vectors and masks. MPMLDR and MP/M II both assume bank 0
  is selected when MPMLDR runs.
- **`IDLE`.** The normal idle is a call to the dispatcher, which serves the polled devices. A
  system with no polled devices can use `HLT` then `RET`.

### 4.2 Interrupt service (§3.3, p.43–44)

1. Save the registers with as little stack as possible. A CP/M program gives no spare stack. The
   samples switch to a local stack and add no levels beyond the RST itself.
2. Set `PREEMPT` true.
3. Find the cause, clear it, and set a flag with XDOS function 133. Any other XDOS or BDOS call
   dispatches and enables interrupts too early.
4. If the processor needs `RETI`, execute it before the jump to `PDISP`.
5. Jump to `PDISP`. The dispatcher runs the highest-priority ready process and enables interrupts.

Use interrupts for asynchronous events, such as console input and disk completion. Leave console
output polled, because a dispatch for each character costs more, especially at high baud rates.

### 4.3 Time base (§3.4, p.44–45)

- Flag #2: once each second of real time. MP/M II keeps the time of day with it.
- Flag #1: at each tick, from `STARTCLOCK` to `STOPCLOCK`. The delay list runs on it.
- The tick rate is also the dispatch rate for compute-bound processes. A high rate costs
  overhead. A low rate lets one process keep the processor for longer.
- GENSYS records the rate in the system data page, byte 122, for programs to read. It does not
  set the hardware.

## 5. MPM.SYS components and the system data page (Section 4)

`MPM.SYS` holds the system data page, the XIOS, RESBDOS and BNKBDOS, XDOS and BNKXDOS, the TMP
and the resident system processes. It is in user 0, usually read-only.

Table 4-1, system data page (p.47–48, read from the page image):

| Byte | Contents |
|---|---|
| 000 | `Mem$top`, top page of memory |
| 001 | `Nmb$cns`, number of system consoles (TMPs) |
| 002 | `Brkpt$RST`, breakpoint RST number |
| 003 | Add system call user stacks, boolean |
| 004 | Bank switched, boolean |
| 005 | Z80 version, boolean |
| 006 | Banked BDOS, boolean |
| 007 | XIOS jump table page |
| 008 | RESBDOS base page |
| 009–010 | **CP/NET master configuration table address** |
| 011 | XDOS base page |
| 012 | RSPs (BNKXIOS top+1) base page |
| 013 | BNKXIOS base page |
| 014 | BNKBDOS base page |
| 015 | `Max$mem$seg`, maximum memory segment number |
| 016–047 | Initial memory segment table |
| 048–063 | Breakpoint vector table, filled in by debuggers |
| 064–079 | Reserved |
| 080–095 | System call user stack pointer table |
| 096–119 | Reserved |
| 120–121 | Number of records in `MPM.SYS` |
| 122 | Ticks per second |
| 123 | System drive |
| 124 | Common memory base page |
| 125 | Number of RSPs |
| 126–127 | `Listcp` array address |
| 128–143 | `Subflg`, submit flag array |
| 144–186 | Reserved |
| 187 | Maximum locked records per process |
| 188 | Maximum open files per process |
| 189–190 | Number of list items |
| 191–192 | Pointer to the base of lock table free space |
| 193 | Total system locked records |
| 194 | Total system open files |
| 195 | Dayfile logging, boolean |
| 196 | Temporary file drive |
| 197 | Number of printers |
| 197–241 | Reserved (⚠ printed as 197, see Quirks) |
| 242 | Banked XDOS base page |
| 243 | TMP process descriptor base |
| 244 | `Console.dat` base |
| 245–246 | BDOS/XDOS entry point |
| 247 | `TMP.spr` base |
| 248 | `Nmbrsps`, number of banked RSPs |
| 249 | BRSP base address |
| 250–251 | `Brspl`, non-resident RSP process link |
| 252–253 | `Sysdatadr`, XDOS internal data segment address |
| 254–255 | `Rspl`, resident system process link |

Bytes 009–010 are where the CP/NET server's NETWRKIF writes its configuration table address.

**Resident system processes** (`.RSP`, §4.5, p.49) are page-relocatable. Bytes 0–1 hold the
BDOS/XDOS address, and the process descriptor starts at byte 2. A **banked RSP** (§4.6, p.49–50)
has a resident part with the descriptor, whose memory segment index is 0 and not `0FFH`. It also
has a `.BRS` code part:

| BRS bytes | Contents |
|---|---|
| 0–1 | Address of the resident part |
| 2–3 | Initial stack pointer. The top of the stack holds the entry address. |
| 4–11 | ASCII process name |

## 6. GENSYS and MPMLDR (Sections 5 and 6)

GENSYS questions, with the defaults from the sample run (p.51–57). A number is hex. A `#` before it
means decimal.

| Question | Sample default | Notes |
|---|---|---|
| Use SYSTEM.DAT for defaults | Y | Or the built-in defaults |
| Top page of operating system | FF | The highest address used is `xxFFH` |
| Number of TMPs (system consoles) | #2 | Each needs 256 bytes of `CONSOLE.DAT`. Four TMP descriptors fit in each page of `TMPD.DAT`. `MAXCONSOLE` lowers it at start-up. |
| Number of printers | #1 | Used by MPMSTAT |
| Breakpoint RST | 06 | RST 1 to RST 6 are recommended |
| Add system call user stacks | Y | Needed to run CP/M `.COM` files. `USERSYS.STK` is 100H for 0–3 segments, 200H for 4–7. |
| Z80 CPU | Y | The dispatcher saves the alternate registers. Answer Y only on a Z80. |
| Number of ticks/second | #60 | For programs to read |
| System disk | E: | Second search drive for the CLI |
| Temporary file drive | E: | SUBMIT's `$n$.SUB` |
| Maximum locked records/process | #16 | 0–255, not more than the system total |
| Total locked records/system | #32 | 0–255 |
| Maximum open files/process | #16 | 0–255, not more than the system total |
| Total open files/system | #32 | 0–255 |
| Bank switched memory | Y | |
| Number of user memory segments | #3 | 1–7, at least the number of system consoles |
| Common memory base page | C0 | GENSYS checks that common modules are above it |
| Dayfile logging at console | Y | Prints time, file and user for each command |

After the RSPs are selected, GENSYS asks for the memory segment table as `base,size,attrib,bank`.
- Entry 0 is the operating system (bank 0). It is not counted in the user segment count.
- List the segments based at `0000H` from the largest to the smallest. The memory manager takes the
  first free one for a `.COM` program.
- An attribute of `FFH` pre-allocates a segment.
- The bank byte is an index. The XIOS turns it into the value for the bank hardware.

The sample run gives this map (p.51–52, read from the page image):

| Module | Base | Size |
|---|---|---|
| `SYSTEM DAT` | `FF00H` | `0100H` |
| `TMPD DAT` | `FE00H` | `0100H` |
| `USERSYS STK` | `FD00H` | `0100H` |
| `XIOSJMP TBL` | `FC00H` | `0100H` |
| `RESBDOS SPR` | `F000H` | `0C00H` |
| `XDOS SPR` | `CE00H` | `2200H` |
| `ABORT`, `SPOOL`, `MPMSTAT RSP` | `CD00H`, `CC00H`, `CB00H` | `0100H` each |
| `BNKXIOS SPR` | `B800H` | `1300H` |
| `BNKBDOS SPR` | `9500H` | `2300H` |
| `BNKXDOS SPR` | `9200H` | `0300H` |
| `TMP SPR` | `8F00H` | `0300H` |
| `SPOOL BRS`, `MPMSTAT BRS` | `8700H`, `7900H` | `0800H`, `0E00H` |
| `LCKLSTS DAT`, `CONSOLE DAT` | `7700H`, `7500H` | `0200H` each |
| Segments | System: `7500H`, `8B00H`, bank 0. User: `0000H`, `C000H`, banks 1 and 2. User: `0000H`, `7500H`, bank 0. | |

**MPMLDR** (§6, p.59–60) needs no operator input. It prints the console count, the breakpoint RST,
the Z80 line and the memory map, then starts MP/M II. Its parameters are:

- `$Bn` in the default FCB name field from `005DH`, to break to a CP/M debugger. The default n is 7.
- Another `.SYS` file name in the FCB at `005CH`, or at `006CH` with `$Bn`. A LDRBIOS can ask for a
  name at `SELDSK` and put it there.

## 7. The sample listings (Appendixes C, D, E)

| App. | What | Hardware it assumes |
|---|---|---|
| C, p.75–76 | Skeleton LDRBIOS, `ORG 1700H` | None. Every routine is a `RET`. |
| D, p.77–97 | Simple RESXIOS, `MP/M II V2.0 DSC-2 Basic & Extended I/O Systems` ("bios for micro-2 computer"). It is `RESXIOS.ASM` on the distribution disk. | Z80 (`IM 1`) at 4 MHz (`dlycnst 086h`). No banks and no protection: `SELMEMORY` is a `RET`. Three consoles, with data/status at `40h/41h`, `50h/51h` and `58h/59h`. The printer (a TTY Model 40) is at `48h/49h`. Status bit 1 = input ready, bit 0 = output ready. Disk controller at `80h`–`83h`. Interrupt mask at port `60h`, bit 6 = the 60 Hz clock. Every interrupt is an RST 7 (`0038h`). One 8" drive type: `DISKDEF 0,1,58,,2048,256,128,128,2`. |
| E, p.99–159 | Banked XIOS `XIOS200` by Altos Computer Systems, version 1.12 and later, for the Altos Sun Series 8000. Printed by permission "as a sample". | Z80 with a CTC. The vector `60H` goes to port `30H`. Channel 3 (port `33H`) gets control `0A7H` and time constant 250. Bank select at port `09H` (`MEMPORT`): the bank number shifted left 3, masked with `18H`. WD1791 floppy and hard disk. Virtual disk in banks 1–3. Tick 62.5 per second. The full listing is at the end of this file. |

Flags used by the Appendix D handlers (p.88–90):

| Flag | Set by |
|---|---|
| 1 | The 60 Hz clock, while `tickn` is true |
| 2 | The 60 Hz clock, every 60th tick |
| 5 | Disk interrupt (status bit 3) |
| 6 | Console #0 input (only when `debug` is false) |
| 8 | Console #2 input |

## Quirks worth carrying

- ⚠ **Byte 197 is listed twice in Table 4-1** (p.48). The table has "197-197 Number of printers"
  and then "197-241 Reserved", and the page image confirms both. Nothing in the guide settles
  it. The likely reading is that the reserved range starts at 198. (Unresolved.)
- ⚠ **The LDRBIOS top.** The text says the upper limit is `1A00H` (p.2). Table 1-2 (p.13) gives
  the LDRBIOS seven sectors, `1700H`–`1A7FH`, and 2 × 26 − 1 sectors from `0100H` also end at
  `1A7FH`. Both readings fit if the LDRBIOS stays below `1A00H`, as the text says.
- ⚠ **The sample XIOS puts every interrupt on RST 7**, and its `SYSTEMINIT` writes a jump at
  `0038H` (App. D, p.87). §1.4 says that DDT and SID use RST 7. Running the sample XIOS under DDT
  breaks DDT's breakpoints. On a machine with a vectored interrupt board, use a level other than 7.
- ⚠ **The Appendix E comments contradict its code** (p.148–149). The handler is labeled `T20MS`,
  and a comment says the dispatch is forced "each 1/32nd of a second". The code counts 62 and 63 in
  turn ("ACTUAL #/SEC = 62.5"). The code wins: 62.5 ticks a second, 16 ms. The CTC setup agrees. Control `0A7H` selects the ÷256 prescaler, so 256 × 250 = 64,000 clocks is 16 ms with a 4 MHz clock (p.157). The listing does not state the clock rate. The heading "MP/M 1.0
  INTERRUPT HANDLERS" is also left over from MP/M 1.0.
- ⚠ **The version is 2.0 in the guide and 2.1 on the disks.** The guide and its samples say V2.0.
  The GENSYS sample prints `MP/M-80 V2.0 System Generation`. The DRI distribution disks are labeled
  Version 2.1. Expect banners that differ from the guide.
- ⚠ **Write types use CP/M 2.2 names in Appendix B.** The listing names C = 0, 1, 2 `wrall`,
  `wrdir`, `wrual` (p.67). §2.5 defines them as deferred or non-deferred, with bit 1 meaning a new
  block. Bit 1, which the algorithm tests, means the same in both.
- ⚠ **`SETDMA 0FFFFH` is a flush, not an address** (p.20–21). A BIOS copied from CP/M 2.2 stores
  `0FFFFH` as the DMA address and then writes to it.
- ⚠ **`SWTUSER` and `SWTSYS` always enable interrupts on return** (p.35), even when the caller had
  them disabled.
- ⚠ **A wrong cross-reference.** §5.2.15 (p.55) says the bank questions are "as shown in Section
  5.2.2". They are §5.2.16 and §5.2.17.
- ⚠ **`SDCONF` in Appendix E never clears drives C: and D:** (p.133). It tests for four floppies
  with `ANI 05H` and then does `JMP SDDBL`, a jump with no condition. The two `MOV M,A` after it
  never run. The comment "YES SKIP THE ZAP" suggests that a `JNZ` was meant.
- ⚠ **`HOMEIT` in Appendix E tests for the virtual disk outside `if mdisk`** (p.112). It compares
  the drive with 12 in every build. With `mdisk` false, `MAXDSK` is 12 and `SELDSK` refuses
  drive 12, so the test does no harm.

---

## Appendix E: the banked XIOS listing (p.99–159)

This is all of Appendix E, copied from the page images. Each block is one printed page. The
listing is the `.PRN` output of MAC for the Altos banked XIOS that section 7 describes.

How to read it:

- The printer cut each line at the right margin. Some comments and operand lists stop in the
  middle of a word, as on the page.
- A `+` after the address marks a line from a macro. `Z80S.LIB` gives each Z80 instruction
  (`JR`, `JRNZ`, `LDIR`, `OUTIR`, `RETI`, `DJNZ`) as a `DB` line with the comment
  "FAKE … INSTRUCTION". The line above it, with no address, is the macro call.
- A source line with no address is in an `IF` block that is false. The listing was assembled with
  `mpm20`, `HARDSK`, `DMA` and `RELOC` true and `mdisk` false.
- When the bytes do not fit in their field, they run into the label, as in
  `0070 FFFFFFFFFFTRK0:`. A `DB` or `DW` line shows only its first 5 bytes.
- The symbol table at the end keeps 10 characters of each name and drops the `$`.

Each label address agrees with the symbol table. The operand bytes of each `CALL`, `JMP`, `LXI`,
`LDA`, `STA`, `LHLD` and `SHLD` agree with the address of the operand.

| Routine | Page |
|---|---|
| Jump vector, `INTERUPT` vector table | 102–103 |
| Work areas, DMA command strings | 103–104 |
| `DPE0`–`DPEB`, model DPEs, translate tables | 105–106 |
| `SELDSK`, `SETDMA` (the `0FFFFH` flush), `SETTRK`, `SETSEC` | 107–108 |
| `READ`, `WRITE`, `SETMOD`, `RETMOD`, `HOMEIT` | 109–113 |
| Hard disk deblocking (`READHARD` to `NEWTRKCMP`) | 114–118 |
| `WRITEHST`, `READHST` (hard disk) | 119–121 |
| `DSKSEL`: floppy select and head unload on a drive change | 122–123 |
| `SELHARD`, `POINT`, `SECTRAN` | 124–125 |
| `READSOFT`, `WRITESOFT`, `LOAD$HEAD`, `FLOPPYIO` | 125–128 |
| `CHECK$STAT` and the retries | 128–130 |
| `WAIT0`, `INTFIX`, `FPYWAIT`, `FINTFIX`, `DELAY` | 130–132 |
| `SDCONF`, `XETMOD` | 133–134 |
| Data areas, the common base (`swtuser`, `swtsys`, `pdisp`, `xdos`, `sysdat`) | 135–136 |
| Centronics printer, disk interrupt handlers | 137–138 |
| Console routines (data ports `1CH`, `2CH`, `2EH`, `2AH`) | 138–145 |
| `LIST`, `POLLPT`, `POLLDEVICE` | 145–147 |
| `SELMEMORY`, `STARTCLOCK`, `STOPCLOCK`, `EXITREGION`, `MAXCONSOLE` | 147–148 |
| Tick handler (`T20MS`), `INTDONE`, `INTINIT` | 148–150 |
| Disk parameter blocks | 150–152 |
| `RWMOVE`, `MVDTB`, `MVDFB` (copy through `swtuser`) | 153–154 |
| `SYSTEMINIT` | 154–157 |
| Symbol table | 157–159 |

The floppy head, in this listing:

- **Unload on a drive change** (`SELSOFT`, p.122–123). When the drive is not the last one, the
  XIOS writes the track register to the data register and sends `12H`, a seek with the head
  unloaded. The head does not move. The comment says that the next access to that drive then
  loads the head and waits for it to settle.
- **Load before each access** (`LOAD$HEAD`, p.126). The XIOS reads bit 1 of port `08H`. If the
  head is not loaded, it sends `1AH`, a seek with the head loaded, waits for the interrupt and
  then waits 16 ms. If the head is loaded, it clears the head-load bit (`04H`) of the read or
  write command.
- **No timed unload.** Nothing in the listing unloads the head after a time with no access.
- **The watchdog** (`FINTFIX`, `T20MS`, `FPYWAIT`). Each floppy command sets `FPYTIME` to
  `0103H`. The once-a-second tick counts the low byte down. At 0 it sets flag 6 with status
  `90H`, and `FPYWAIT` resets the WD1791 with bit 1 of port `09H`. This catches a controller that
  stops. It does not control the head.

*p.99*

```
                        page    0
                        TITLE   'XIOS200, Copyright 1980, ALTOS COMPUTER SY
                ;-----------------------------------------------------------
                ;
                ;       ALTOS COMPUTER SYSTEMS
                ;       2360 BERING DRIVE
                ;       SAN JOSE, CALIFORNIA 95131
                ;
                ;       Copyright 1980, ALTOS COMPUTER SYSTEMS
                ;
                ;       This program is a copyright program product of
                ;       ALTOS COMPUTER SYSTEMS and is distributed to the
                ;       owners of ALTOS SUN SERIES 8000 computers for
                ;       use on those systems only. Any other use of this
                ;       software constitutes a breach of the copyright
                ;       license to the purchaser.  However, permission is
                ;       granted to use this listing as a sample for the
                ;       construction of the reader's own XIOS.
                ;
                ;       VERSION NUMBER: 1.12*
                ;       VERSION DATE:   June 28, 1980
                ;       .       Add support for CP/M version 2.0
                ;       .       Add support for Hard disk drives
                ;       .       Add support for disk MODE selection
                ;       .       Provide compatability MODE for 1.4 operatio
                ;       .       Remove CTC/1791 counter reset
                ;       .       CORRECT HARD DISK SEEK PROBLEM
                ;       .       Add code to recover from WD1791 going to sl
                ;       .       Initialize parallel port for Centronics pri
                ;       VERSION DATE:   March 17, 1981
                ;       .       Virtual disk in banks 1,2,3: M DISK !;
                ;       VERSION DATE:   April 11, 1981
                ;       .       Conditional assembly for virtual disks
                ;       .       Conditional assembly for MP/M 2.0
                ;       VERSION DATE:   April 14, 1981
                ;       .       Equates added for LDRBIOS hooks  !
                ;       VERSION DATE:   April 16, 1981
                ;       .       Testing for bank setup added
                ;
                ;-----------------------------------------------------------
                ;

                ;-----------------------------------------------------------
                ;
                ;       Mode    0       IBM single density
                ;               1       ALTOS double density Version 2.0
```

*p.100*

```
                ;               2       ALTOS double density Version 1.4
                ;               3       ALTOS hard disk Version 2.0 (8 MEG
                ;               4       ALTOS HARD DISK VERSION 2.0 (8 MEG
                ;               5       ALTOS HARD DISK VERSION 2.0 (8 MEG
                ;               6       ALTOS HARD DISK VERSION 2.0 (4 MEG
                ;
                ;-----------------------------------------------------------

                ;-----------------------------------------------------------
                ;
                ;       ASSEMBLER CONTROL STATEMENTS
                ;
                ;-----------------------------------------------------------

                        MACLIB  DISKDEF
                        MACLIB  Z80S

FFFF =          TRUE    EQU     0FFFFH          ;VALUE FOR TRUE
0000 =          FALSE   EQU     NOT TRUE        ;VALUE FOR FALSE

0000 =          mdisk   equ     false           ;Virtual Disk cond asm bool
FFFF =          mpm20   equ     true            ;MP/M 2.0 cond asm boolean

                ;-----------------------------------------------------------
1700 =          ldrbiosbase equ 1700h   ;                       for M

0037 =          density$mask$offset equ 37h ;density mask offset from LDRBI
00BB =          misc$params$offset equ 0bbh ;misc. parameters offset from L

                ;-----------------------------------------------------------
                ;
                ;
                ;       THE FOLLOWING EQUATES ARE USER MODIFIABLE BASED ON
                ;       PARTICULAR USER SYSTEM AND OPTIONS SELECTED.
                ;
                ;-----------------------------------------------------------

FFFF =          DMA     EQU     TRUE            ;DMA HARDWARE SUPPORT ??
FFFF =          HARDSK  EQU     TRUE            ;HARD DISK SUPPORT

                ;-----------------------------------------------------------
                ;
                ;       THE FOLLOWING CONSTANTS APPLY TO THE DEBLOCKING OF
                ;       SECTORS LARGER THAN 128 FOR THE ALTOS DOUBLE DENSIT
                ;       AND THE ALTOS HARD DISK.
                ;
                ;-----------------------------------------------------------

4000 =          BLKSIZ  EQU     16384           ;CP/M ALLOCATION SIZE
0400 =          HSTSIZ  EQU     1024            ;HOST DISK SECTOR SIZE
0010 =          HSTSPT  EQU     16              ;HOST DISK SECTORS PER TRAC
0008 =          HSTBLK  EQU     HSTSIZ/128      ;CP/M SECTORS PER HOST BUFF
0080 =          CPMSPT  EQU     HSTBLK * HSTSPT ;CP/M SECTORS PER TRACK
0007 =          SECMSK  EQU     HSTBLK - 1      ;SECTOR MASK
0003 =          SECSHF  EQU     3               ;LOG2(HHSTBLK)
```

*p.101*

```
                        PAGE

                ;-----------------------------------------------------------
                ;
                ;       THE FOLLOWING EQUATES APPLY TO THE RELOCATABILITY
                ;       OF THE CBIOS AND SHOULD NOT BE USER ALTERED.
                ;
                ;-----------------------------------------------------------

FFFF =          RELOC   EQU     TRUE            ;RELOCATABLE VERSION ??

                ;-----------------------------------------------------------

                        if      mdisk
                maxdsk  equ     13
                        else
                        IF      HARDSK
000C =          MAXDSK  EQU     12              ;MAXIMUM NUMBER OF LOGICAL
                        ELSE
                MAXDSK  EQU     4               ;MAXIMUM NUMBER OF LOGICAL
                        ENDIF
                        endif

                        IF      RELOC
0000                    ORG     0000H
                        ELSE
                        ORG     0C000H
                        ENDIF

0000 =          BASE    EQU     $

                ;-----------------------------------------------------------

0000 =          WRALL   EQU     0               ;WRITE TO ALLOCATED
0001 =          WRDIR   EQU     1               ;WRITE TO DIRECTORY
0002 =          WRUAL   EQU     2               ;WRITE TO UNALLOCATED


0004 =          NMBCNS  EQU     4       ; NUMBER OF CONSOLES

0083 =          POLL    EQU     131     ; XDOS POLL FUNCTION
0084 =          FLAGWT  EQU     132     ; XDOS FLAG WAIT FUNCTION
0085 =          FLAGST  EQU     133     ; XDOS FLAG SET FUNCTION

0005 =          HDFLAG  EQU     5       ;HARD DISK FLAG FOR WAIT & SET
0006 =          FPYFLAG EQU     6       ;FLOPPY DISK FLAG FOR WAIT & SET

0000 =          PLLPT   EQU     0       ; POLL PRINTER
0001 =          PLCO0   EQU     PLLPT+1 ; POLL CONSOLE OUT #0 (CRT:)
0002 =          PLCO1   EQU     PLCO0+1 ; POLL CONSOLE OUT #1 (CRT:)
0003 =          PLCO2   EQU     PLCO1+1 ; POLL CONSOLE OUT #2 (CRT:)
0004 =          PLCO3   EQU     PLCO2+1 ; POLL CONSOLE OUT #3 (CRT:)
0005 =          PLCI0   EQU     PLCO3+1 ; POLL CONSOLE IN #0 (CRT:)
0006 =          PLCI1   EQU     PLCI0+1 ; POLL CONSOLE IN #1 (CRT:)
```

*p.102*

```
0007 =          PLCI2   EQU     PLCI1+1 ; POLL CONSOLE IN #2 (CRT:)
0008 =          PLCI3   EQU     PLCI2+1 ; POLL CONSOLE IN #3 (CRT:)

0009 =          MEMPORT EQU     009H    ; MEMORY SELECT PORT
0002 =          MEMSK   EQU     002H    ; MEMORY SELECT MASK

                        PAGE

                ;-----------------------------------------------------------
                ;
                ;       JUMP VECTORS FOR ENTRIES TO CBIOS ROUTINES
                ;
                ;-----------------------------------------------------------

                ;       EXTERNAL JUMP TABLE (BELOW XIOS BASE)


                ;PDISP  EQU     $-3
                ;XDOS   EQU     PDISP-3

                        if      mpm20
0000 C3040B             jmp     commonbase
                        else
                        JMP     COLDSTART       ;COLD START
                        endif
                WBOTE:
0003 C3150B             JMP     WARMSTART       ;WARM START
0006 C3790B             JMP     CONST           ;CONSOLE STATUS
0009 C3840B             JMP     CONIN           ;CONSOLE CHARACTER IN
000C C38F0B             JMP     CONOUT          ;CONSOLE CHARACTER OUT
000F C3A90C             JMP     LIST            ;LIST CHARACTER OUT - THIS
                ;                               ;  "CLIST" IF SETUP PROGRAM
                ;                               ;  PARALLEL PRINTER PORT

0012 C31A0B             JMP     RTNEMPTY        ;PUNCH NOT IMPLEMENTED
0015 C31A0B             JMP     RTNEMPTY        ;READER NOT IMPLEMENTED
0018 C3F902             JMP     HOMEIT          ;MOVE HEAD TO HOME
001B C30302             JMP     SELDSK          ;SELECT DISK
001E C36D02             JMP     SETTRK          ;SET TRACK NUMBER
0021 C37302             JMP     SETSEC          ;SET SECTOR NUMBER
0024 C35502             JMP     SETDMA          ;SET DMA ADDRESS
0027 C38B02             JMP     READ            ;READ DISK
002A C39602             JMP     WRITE           ;WRITE DISK
002D C3BC0C             JMP     POLLPT          ;LIST STATUS
0030 C3D605             JMP     SECTRAN         ;SECTOR TRANSLATE

                ;       EXTENDED I/O SYSTEM JUMP VECTOR

0033 C3E90C             JMP     SELMEMORY       ; SELECT MEMORY
0036 C3CB0C             JMP     POLLDEVICE      ; POLL DEVICE
0039 C3050D             JMP     STARTCLOCK      ; START CLOCK
003C C30B0D             JMP     STOPCLOCK       ; STOP CLOCK
003F C3100D             JMP     EXITREGION      ; EXIT REGION
0042 C3170D             JMP     MAXCONSOLE      ; MAXIMUM CONSOLE NUMBER
```

*p.103*

```
0045 C39D12             JMP     SYSTEMINIT      ; SYSTEM INITIALIZATION
0048 00                 NOP                     ; NO JMP HERE
0049 00                 NOP                     ; FOR MP/M DELAY
004A 00                 NOP                     ;


004B C3A102             JMP     SETMOD          ;ROUTINE TO SET DISK MODE
004E C3EE02             JMP     RETMOD          ;ROUTINE TO RETURN CURRENT

                        if      not mpm20
                COLDSTART:
                WARMSTART:
                        MVI     C,0             ; SEE SYSTEM INIT
                                                ; COLD & WARM START INCLUDE
                                                ; FOR COMPATIBILITY WITH CP
                        JMP     XDOS            ; SYSTEM RESET, TERMINATE P

                RTNEMPTY:
                        XRA     A               ; NOT USED
                        RET                     ;
                        endif

                LAST:
005E                    ORG     (((LAST-BASE)+0A2H) AND 0FF00H) +05EH

                INTERUPT:
005E 470B               DW      FLOPPY$INT              ;FLOPPY DISK INTERR
0060 1C0B               DW      NULL$INT                ;
0062 1C0B               DW      NULL$INT                ;
0064 1C0B               DW      NULL$INT                ;
0066 1A0D               DW      INT1HND                 ;CTC INTERRUPT
0068 1C0B               DW      NULL$INT                ;
006A 5E0B               DW      HARD$INT                ;HARD DISK INTERRUP
006C 1C0B               DW      NULL$INT                ;
006E 1C0B               DW      NULL$INT                ;

                        if      not mpm20
                NULL$INT:
                        EI
                        RETI
                        endif

                        PAGE



                ;-----------------------------------------------------------
                ;
                ;       WORK AND CONTROL AREAS FOR CBIOS SERVICES
                ;
                ;-----------------------------------------------------------

0070 FFFFFFFFFFTRK0:    DB      0FFH,0FFH,0FFH,0FFH,0FFH,0FFH,0FFH,0FFH,0FF
```

*p.104*

```
007C 0408102010SEL0:    DB      004H,008H,010H,020H,010H,010H,010H,020H,020
0088 0000000003MODE:    DB      000H,000H,000H,003H,004H,005H,003H,004
0094 0000000000TCNT:    DB      000H,000H,000H,000H,000H,000H,000H,000H,000
00A0 0000000000PCNT:    DB      000H,000H,000H,000H,000H,000H,000H,000H,000

00AC 00         DISKNO: DB      000H                                    ;CURRENT DR
00AD 00         TRAKNO: DB      000H                                    ;CURRENT TR
00AE 00         HEADNO: DB      000H                                    ;CURRENT HE
00AF 0000       DMAADR: DW      000H                                    ;CURRENT DM
00B1 00         SECTNO: DB      000H                                    ;CURRENT SE
00B2 0000       DPEPTR: DW      000H                                    ;CURRENT DP
00B4 0000       DBLKAD: DW      000H                                    ;CURRENT EX
00B6 0000       MPARMS: DW      000H                                    ;MISC. PARA
00B8 10         HTK1:   DB      10H                                     ;HARD DISK
00B9 20         HTK2:   DB      20H                                     ;HARD DISK
                ;
                ;       PARAMETER FLAGS
                ;
                ;       0100H = DOUBLE HEADED DRIVES
                ;       0200H = CENTRONICS PRINTER FOR LIST DEVICE
                ;       0400H = FOUR DRIVE SYSTEM  [ A B C D ]
                ;-----------------------------------------------------------
                ;
                ;-----------------------------------------------------------
                ;
                ;       NOTE:
                ;       NO CHANGES ARE TO BE MADE TO THE ABSOLUTE LOCATIONS
                ;       ANY FIELDS PRIOR TO THIS POINT. EXTERNAL PROGRAMS A
                ;       DEPENDENT UPON THE LOCATION OF THE PRECEEDING DATA.
                ;
                ;-----------------------------------------------------------

                        IF      NOT DMA
                NMIRTN: DB      0EDH,0A2H,0EDH,045H                     ;FAKE INI A
                        ENDIF

00BA C37D       DMAS1:  DB      0C3H,07DH                               ;FIRST PART
00BC 0000       DMASA:  DW      000H                                    ;ADDRESS FO
00BE 0004       DMALEN: DW      1025-1                                  ;LENGTH FOR

00C0 54CE68CEA5DMAS2H:  DB      054H,0CEH,068H,0CEH,0A5H,020H           ;HARD DISK

00C6 14288507   DMAS2F: DB      014H,028H,085H,007H                     ;FLOPPY DIS

00CA 8ACF01CF   DMAS3:  DB      08AH,0CFH,001H,0CFH                     ;LAST PART
00CE 01         DMAS3F: DB      001H                                    ;001=READ,
00CF CF87               DB      0CFH,087H                               ;SETUP DMA,

                        PAGE

                ;-----------------------------------------------------------
                ;
                ;       CONTROL BLOCKS FOR DISK DRIVER
                ;
                ;-----------------------------------------------------------
```

*p.105*

```
00D1 =          DPBASE  EQU     $               ;START OF DISK PARAMETER BL

00D1 B5010000   DPE0:   DW      XLT0,0000H      ;TRANSLATE TABLE AND WORK A
00D5 00000000           DW      0000H,0000H     ;SCRATCH AREA
00D9 9D12D40D           DW      DIRBUF,DPB0     ;DIR BUFF, PARM BLOCK
00DD 3E081E08           DW      CSV0,ALV0       ;CHECK VECTOR, ALLOC VECTOR

00E1 B5010000   DPE1:   DW      XLT0,0000H      ;TRANSLATE TABLE AND WORK A
00E5 00000000           DW      0000H,0000H     ;SCRATCH AREA
00E9 9D12D40D           DW      DIRBUF,DPB0     ;DIR BUFF, PARM BLOCK
00ED 7E085E08           DW      CSV1,ALV1       ;CHECK VECTOR, ALLOC VECTOR

00F1 B5010000   DPE2:   DW      XLT0,0000H      ;TRANSLATE TABLE AND WORK A
00F5 00000000           DW      0000H,0000H     ;SCRATCH AREA
00F9 9D12D40D           DW      DIRBUF,DPB0     ;DIR BUFF, PARM BLOCK
00FD BE089E08           DW      CSV2,ALV2       ;CHECK VECTOR, ALLOC VECTOR

0101 B5010000   DPE3:   DW      XLT0,0000H      ;TRANSLATE TABLE AND WORK A
0105 00000000           DW      0000H,0000H     ;SCRATCH AREA
0109 9D12D40D           DW      DIRBUF,DPB0     ;DIR BUFF, PARM BLOCK
010D FE08DE08           DW      CSV3,ALV3       ;CHECK VECTOR, ALLOC VECTOR

                        IF      HARDSK

0111 00000000   DPE4:   DW      0000H,0000H     ;TRANSLATE TABLE AND WORK A
0115 00000000           DW      0000H,0000H     ;SCRATCH AREA
0119 9D12010E           DW      DIRBUF,DPB3     ;DIR BUFF, PARM BLOCK
011D 5E091E09           DW      CSV4,ALV4       ;CHECK VECTOR, ALLOC VECTOR

0121 00000000   DPE5:   DW      0000H,0000H     ;TRANSLATE TABLE AND WORK A
0125 00000000           DW      0000H,0000H     ;SCRATCH AREA
0129 9D12100E           DW      DIRBUF,DPB4     ;DIR BUFF, PARM BLOCK
012D 9E095E09           DW      CSV5,ALV5       ;CHECK VECTOR, ALLOC VECTOR

0131 00000000   DPE6:   DW      0000H,0000H     ;TRANSLATE TABLE AND WORK A
0135 00000000           DW      0000H,0000H     ;SCRATCH AREA
0139 9D121F0E           DW      DIRBUF,DPB5     ;DIR BUFF, PARM BLOCK
013D DE099E09           DW      CSV6,ALV6       ;CHECK VECTOR, ALLOC VECTOR

0141 00000000   DPE7:   DW      0000H,0000H     ;TRANSLATE TABLE AND WORK A
0145 00000000           DW      0000H,0000H     ;SCRATCH AREA
0149 9D12010E           DW      DIRBUF,DPB3     ;DIR BUFF, PARM BLOCK
014D 1E0ADE09           DW      CSV7,ALV7       ;CHECK VECTOR, ALLOC VECTOR

0151 00000000   DPE8:   DW      0000H,0000H     ;TRANSLATE TABLE AND WORK A
0155 00000000           DW      0000H,0000H     ;SCRATCH AREA
0159 9D12100E           DW      DIRBUF,DPB4     ;DIR BUFF, PARM BLOCK
015D 5E0A1E0A           DW      CSV8,ALV8       ;CHECK VECTOR, ALLOC VECTOR

0161 00000000   DPE9:   DW      0000H,0000H     ;TRANSLATE TABLE AND WORK A
0165 00000000           DW      0000H,0000H     ;SCRATCH AREA
0169 9D121F0E           DW      DIRBUF,DPB5     ;DIR BUFF, PARM BLOCK
016D 9E0A5E0A           DW      CSV9,ALV9       ;CHECK VECTOR, ALLOC VECTOR
```

*p.106*

```
0171 00000000   DPEA:   DW      0000H,0000H     ;TRANSLATE TABLE AND WORK A
0175 00000000           DW      0000H,0000H     ;SCRATCH AREA
0179 9D122E0E           DW      DIRBUF,DPB6     ;DIR BUFF, PARM BLOCK
017D C20A9E0A           DW      CSVA,ALVA       ;CHECK VECTOR, ALLOC VECTOR

0181 00000000   DPEB:   DW      0000H,0000H     ;TRANSLATE TABLE AND WORK A
0185 00000000           DW      0000H,0000H     ;SCRATCH AREA
0189 9D122E0E           DW      DIRBUF,DPB6     ;DIR BUFF, PARM BLOCK
018D E60AC20A           DW      CSVB,ALVB       ;CHECK VECTOR, ALLOC VECTOR

                        ENDIF

                        if      mdisk
                ;               Virtual disk parameter header

                DPEC:   DW      0000H,0000H     ;TRANSLATE TABLE AND WORK A
                        DW      0000H,0000H     ;SCRATCH AREA
                        DW      DIRBUF,DPB7     ;DIR BUFF, PARM BLOCK
                        DW      CSVC,ALVC       ;CHECK VECTOR, ALLOC VECTOR
                        endif

                ;-----------------------------------------------------------

0191 B5010000   MODL0:  DW      XLT0,000H       ;MODEL DPE FOR MODE 0
0195 00000000           DW      000H,000H       ;
0199 9D12D40D           DW      DIRBUF,DPB0     ;

019D CF010000   MODL1:  DW      XLT1,0000H      ;MODEL DPE FOR MODE 1
01A1 00000000           DW      0000H,0000H     ;
01A5 9D12E30D           DW      DIRBUF,DPB1     ;

01A9 CF010000   MODL2:  DW      XLT2,0000H      ;MODEL DPE FOR MODE 2
01AD 00000000           DW      0000H,0000H     ;
01B1 9D12F20D           DW      DIRBUF,DPB2     ;

                ;-----------------------------------------------------------

01B5 01070D1319XLT0:    DB      1,7,13,19,25,5,11,17,23,3,9,15,21
01C2 02080E141A         DB      2,8,14,20,26,6,12,18,24,4,10,16,22

                XLT1:
                XLT2:
01CF 0102030405         DB      01,02,03,04,05,06,07,08,09,10,11,12,13
01DC 0E0F101112         DB      14,15,16,17,18,19,20,21,22,23,24,25,26
01E9 1B1C1D1E1F         DB      27,28,29,30,31,32,33,34,35,36,37,38,39
01F6 28292A2B2C         DB      40,41,42,43,44,45,46,47,48,49,50,51,52

                        PAGE

                ;-----------------------------------------------------------
                ;
                ;       DISK ACCESS ROUTINES
                ;
```

*p.107*

```
                ;-----------------------------------------------------------

                SELDSK:
0203 79                 MOV     A,C             ;LIMIT SELECT TO REAL OPTIO
0204 FE0C               CPI     MAXDSK          ;
                        JRNC    SELERR          ;  INVALID DRIVE
0206+303A               DB      030H,SELERR-$-1 ;---- FAKE JRNC INSTRUCTION
                ;       MOV     A,E             ; TEST FOR INITIAL SELECT
                ;       ANI     1               ;   E = 0  IS FIRST TIME
                ;       PUSH    PSW             ;
0208 1600               MVI     D,0             ;
020A 59                 MOV     E,C             ; TRANSLATE TABLE
020B 214602             LXI     H,DTBLT         ;  FOR LOGICAL TO PHYSICAL
020E 19                 DAD     D               ;
020F 4E                 MOV     C,M             ;  C = PHYSICAL DRIVE
0210 79                 MOV     A,C             ; M translates to the 12 di

                        if      mdisk
                        CPI     12
                        JZ      VIRTUAL
                        endif

                ;       POP     PSW             ; RESTORE TEST
                ;       JRNZ    SELSDP          ; BYPASS SELECT
                SETDSK:
0211 0600               MVI     B,0             ;
0213 217C00             LXI     H,SEL0          ; BASE OF SELECT MASKS
0216 09                 DAD     B               ;
0217 7E                 MOV     A,M             ;  GET SELECT BYTE
0218 A7                 ANA     A               ;   CHECK FOR VALID DRIVE
                        JRZ     SELERR          ;    DRIVE NOT CONFIGURED
0219+2827               DB      028H,SELERR-$-1 ;---- FAKE JRZ INSTRUCTION
021B 79                 MOV     A,C             ;
021C FE04               CPI     4               ; CHECK FOR FLOPPY
                        JRC     SELSDP          ;
021E+380F               DB      038H,SELSDP-$-1 ;---- FAKE JRC INSTRUCTION
0220 7E         CHKHRD: MOV     A,M             ; RESTORE SELECT BYTE
0221 D320               OUT     20H             ;
0223 C5                 PUSH    B               ;
0224 0E01               MVI     C,1             ; DELAY FOR 1 MS
0226 CD8207             CALL    DELAY           ;
0229 C1                 POP     B               ;
022A DB24               IN      24H             ; CHECK FOR HARD DISK READY
022C 17                 RAL                     ;  80H = READY
                        JRNC    SELERR          ;
022D+3013               DB      030H,SELERR-$-1 ;---- FAKE JRNC INSTRUCTION
                SELSDP:
022F 79                 MOV     A,C             ;

                        if      mdisk
                VIRTUAL:
                        endif

0230 32E60A             STA     NEWDSK          ;SAVE FOR I/O LATER
0233 2600               MVI     H,0             ;
```

*p.108*

```
0235 69                 MOV     L,C             ;COMPUTE DP HEADER ADDRESS
0236 29                 DAD     H               ;* 2
0237 29                 DAD     H               ;* 4
0238 29                 DAD     H               ;* 8
0239 29                 DAD     H               ;* 16 (DP HEADER SIZE)
023A 11D100             LXI     D,DPBASE        ;START OF DP HEADERS
023D 19                 DAD     D               ;POINT TO CORRECT ONE
023E 22B200             SHLD    DPEPTR          ;SAVE ADDRESS OF CURRENT DP
0241 C9                 RET                     ;

0242 210000     SELERR: LXI     H,0             ; INDICATE ERROR
0245 C9                 RET                     ;  AND RETURN

                ;               A,B,C,D,E,F,G,H,I,J, K, L,M ,N,O
0246 0001020304DTBLT:   DB      0,1,2,3,4,5,6,7,8,9,10,11,12,0,0


                SETDMA:
0255 60                 MOV     H,B             ;TO ALLOW SAVING
0256 69                 MOV     L,C             ;
0257 22AF00             SHLD    DMAADR          ;

                        if      mpm20
025A 23                 inx     h               ;test for flush buffers
025B 7D                 mov     a,l
025C B4                 ora     h
025D C0                 rnz                     ;HL = FFFFh is flush buffer
025E 21F00A             lxi     h,hstwrt
0261 7E                 mov     a,m
0262 3600               mvi     m,0
0264 B7                 ora     a
0265 C8                 rz
0266 CD6D04             call    writehst        ;flush host write if pendin
0269 B7                 ora     a
026A C8                 rz                      ;return if no error
026B E1                 pop     h
                        endif

026C C9                 ret

                SETTRK:
026D 60                 MOV     H,B             ;TO ALLOW SAVE
026E 69                 MOV     L,C             ;
026F 22E70A             SHLD    NEWTRK          ;SAVE NEXT TRACK NUMBER
0272 C9                 RET                     ;RETURN TO CALLER

                SETSEC:
0273 79                 MOV     A,C             ;FOR SAVE
0274 32E90A             STA     NEWSEC          ;
0277 C9                 RET                     ;RETURN TO CALLER

                SETDEN:
0278 117C00             LXI     D,SEL0          ;START OF SELECT/DENSITY MA
027B 2AE60A             LHLD    NEWDSK          ;NEXT DRIVE ADDRESS
027E 2600               MVI     H,000H          ;ENSURE ZERO FOR SINGLE BYT
```

*p.109*

```
0280 19                 DAD     D               ;POINT TO CORRECT MASK
0281 79                 MOV     A,C             ;ISOLATE DENSITY BIT
0282 E601               ANI     00000001B       ;
0284 4F                 MOV     C,A             ;SAVE FOR NOW
0285 7E                 MOV     A,M             ;LOAD SELECT DENSITY MASK
0286 E6FE               ANI     11111110B       ;RESET CURRENT DENSITY SETT
0288 B1                 ORA     C               ;SET NEW VALUE
0289 77                 MOV     M,A             ;RESTORE MASK IN TABLE
028A C9                 RET                     ;RETURN TO CALLER

                        if      mdisk
                MREADSECTOR:
                        call    compbank        ;compute bank
                        di
                        call    chgbank
                        lxi     b,128
                        lxi     d,localbuf
                        lhld    addroff
                        ldir                    ;block move into the dma ar
                        mvi     a,02h           ; select bank 0
                        out     09h
                        ei
                        lxi     b,128
                        lhld    dmaadr
                        xchg
                        lxi     h,localbuf
                        ldir
                        xra     a
                        ret

                mbankno         db      0
                addroff         dw      0
                localbuf        ds      128

                compbank:
                        lda     newtrk
                        mov     h,a
                        ani     0fh     ;save track rem 16
                        mov     l,a
                        mov     a,h     ;restore track
                        mvi     h,0
                        ani     0f0h            ; bank is high order nibble
                        rar ! rar ! rar ! rar
                        inr     a
                        sta     mbankno         ; which bank we want

                        dad     h               ;trk 0-15
                        dad     h               ; * 2
                        dad     h               ; * 4
                        mov     e,l
                        mov     d,h
                        dad     d
                        dad     d               ; * 24:

                        lda     newsec          ; figure offset within the
```

*p.110*

```
                        mov     e,a
                        mvi     d,0
                        dad     d               ; add sector offset within
                        dad     h ! dad h ! dad h ! dad h ! dad h ! dad h !
                        shld    addroff         ; (track * 24 + sector) * 1
                        ret
                        endif

                READ:
                        if      mdisk
                        LDA     NEWDSK
                        CPI     12              ;VIRTUAL DISK ?
                        JZ      MREADSECTOR
                        endif

028B CDEE02             CALL    RETMOD          ;WHAT TYPE OF I/O ??
028E FE03               CPI     003H            ;
0290 DAE405             JC      READSOFT        ;FLOPPY DISK DRIVE....
0293 C36B03             JMP     READHARD        ;HARD DISK I/O

                        if      mdisk
                mwritesector:
                        call    compbank
                        lhld    dmaadr
                        lxi     d,localbuf
                        lxi     b,128
                        ldir
                        di
                        call    chgbank
                        lxi     d,localbuf
                        lxi     b,128
                        lhld    addroff
                        xchg
                        ldir
                        mvi     a,02h           ; select bank 0
                        out     09h
                        ei
                        xra     a
                        ret

                chgbank:
                        lda     mbankno
                        ral
                        ral
                        ral
                        ani     018h
                        ori     memsk
                        out     009h
                        ret
                        endif

                WRITE:
                        if      mdisk
                        lda     newdsk
                        cpi     12
```

*p.111*

```
                        jz      mwritesector
                        endif

0296 CDEE02             CALL    RETMOD          ;WHAT TYPE OF I/O ??
0299 FE03               CPI     003H            ;
029B DAF205             JC      WRITESOFT       ;FLOPPY DISK
029E C37E03             JMP     WRITEHARD       ;HARD DISK I/O

                        PAGE

                ;-----------------------------------------------------------
                ;
                ;       ROUTINES TO SET AND RETURN THE CURRENT DRIVE MODE
                ;
                ;-----------------------------------------------------------

                SETMOD:
02A1 21E60A             LXI     H,NEWDSK        ; SAVE NEWDSK IN STACK
02A4 7E                 MOV     A,M             ;
02A5 F5                 PUSH    PSW             ;
02A6 70                 MOV     M,B             ;
02A7 C5                 PUSH    B               ;
                ;       MVI     E,0             ; INDICATE INITIAL SELECT
02A8 48                 MOV     C,B             ; CALL DISK SELECT
02A9 CD0302             CALL    SELDSK          ;
02AC C1                 POP     B               ;
02AD 7C                 MOV     A,H             ; CHECK FOR BAD SELECT
02AE B5                 ORA     L               ;
                        JRZ     SMERR           ;   YES  -  ABORT CHANGING
02AF+2832               DB      028H,SMERR-$-1  ;---- FAKE JRZ INSTRUCTION
02B1 68                 MOV     L,B             ;  B AND L  = DRIVE #
02B2 2600               MVI     H,000H          ;
02B4 78                 MOV     A,B             ;CHECK MODE SET VALIDITY
02B5 FE04               CPI     004H            ;ONLY VALID FOR FLOPPY DISK
                        JRNC    SMERR           ;INVALID DRIVE FOR MODE SET
02B7+302A               DB      030H,SMERR-$-1  ;---- FAKE JRNC INSTRUCTION
02B9 118800             LXI     D,MODE          ;START OF MODE BYTES
02BC 19                 DAD     D               ;
02BD 71                 MOV     M,C             ;SAVE NEW MODE BYTE
02BE E5                 PUSH    H               ;SAVE MODE BYTE ADDRESS
02BF 79                 MOV     A,C             ;SETUP FOR DENSITY CHANGE
02C0 B7                 ORA     A               ;
02C1 0E00               MVI     C,000H          ;ASSUME SINGLE DENSITY MODE
                        JRZ     SETSEL          ;VERIFY ASSUMPTION
02C3+2802               DB      028H,SETSEL-$-1 ;---- FAKE JRZ INSTRUCTION
02C5 0E01               MVI     C,001H          ;SET FOR DOUBLE DENSITY MOD
02C7 CD7802     SETSEL: CALL    SETDEN          ;SET DENSITY BASED ON LOW B
02CA E1                 POP     H               ;RESTORE
02CB 6E                 MOV     L,M             ;PICKUP MODE AGAIN
02CC 2600               MVI     H,000H          ;FOR SINGLE BYTE PRECISION
02CE 7D                 MOV     A,L             ;SAVE MODE IN ACCUMULATOR F
02CF 29                 DAD     H               ;* 2
02D0 29                 DAD     H               ;* 4
02D1 E5                 PUSH    H               ;SAVE * 4
02D2 29                 DAD     H               ;* 8
```

*p.112*

```
02D3 D1                 POP     D               ;REGAIN * 4
02D4 19                 DAD     D               ;* 12
02D5 119101             LXI     D,MODL0         ;FIRST MODEL DPE
02D8 19                 DAD     D               ;POINT TO THIS ONE
02D9 EB                 XCHG                    ;SETUP TEMPORARILY AS DESTI
02DA 2AB200             LHLD    DPEPTR          ;ADDRESS OF CURRENTLY SELEC
02DD EB                 XCHG                    ;SETUP TO ALTER
02DE 010C00             LXI     B,12            ;LENGTH FOR MOVE
                        LDIR                    ;DO MOVE
02E1+EDB0               DB      0EDH,0B0H       ;---- FAKE LDIR INSTRUCTION
02E3 F1         SMERR:  POP     PSW             ;
02E4 E5                 PUSH    H               ;
02E5 32E60A             STA     NEWDSK          ; RESTORE ORIGINAL NEWDSK
02E8 4F                 MOV     C,A             ;
02E9 CD0302             CALL    SELDSK          ;
02EC E1                 POP     H               ;
02ED C9                 RET                     ;RETURN TO CALLER

                RETMOD:
02EE 118800             LXI     D,MODE          ;START OF MODE BYTES
02F1 2AE60A             LHLD    NEWDSK          ;NEXT DRIVE FOR I/O
02F4 2600               MVI     H,000H          ;RESET FOR SINGLE BYTE QUAN
02F6 19                 DAD     D               ;POINT TO IT....
02F7 7E                 MOV     A,M             ;LOAD IT FOR CALLER
02F8 C9                 RET                     ;RETURN, WITH CURRENT MODE

                        PAGE

                ;-----------------------------------------------------------
                ;
                ;       THIS IS THE HOME DEVICE ROUTINE
                ;
                ;-----------------------------------------------------------

02F9 3AE60A     HOMEIT: LDA     NEWDSK          ; CHECK FOR FIRST HOME
02FC FE0C               CPI     12              ; CHECK FOR VIRTUAL DISK
02FE C20803             JNZ     REALDISK
0301 AF                 XRA     A               ; VIRTUAL DISK
0302 67                 MOV     H,A             ; SET TRACK TO ZERO
0303 6F                 MOV     L,A
0304 22E70A             SHLD    NEWTRK
0307 C9                 RET
                REALDISK:
0308 FE04               CPI     4               ;  CHECK FOR FLOPPY
                        JRC     HOME            ;  DO NOT BYPASS FLOPPY HOM
030A+380E               DB      038H,HOME-$-1   ;---- FAKE JRC INSTRUCTION
030C 4F                 MOV     C,A             ;
030D 0600               MVI     B,0             ; POINT TO PRESENT TRACK ST
030F 217000             LXI     H,TRK0          ;
0312 09                 DAD     B               ;
0313 7E                 MOV     A,M             ; CHECK IF INITIALIZED
0314 FEFF               CPI     0FFH            ;
0316 3E00               MVI     A,0             ;
0318 C0                 RNZ                     ; YES  -  RETURN WITH NO ER
0319 77                 MOV     M,A             ;
```

*p.113*

```
                HOME:
031A 3AE60A             LDA     NEWDSK          ;GET VALUE OF DRIVE FOR HOM
031D FE04               CPI     004H            ;IS IT A HARD DISK ??
                        JRNC    HOMEHARD        ;YES, PROCESS....
031F+3022               DB      030H,HOMEHARD-$-1       ;---- FAKE JRNC INS

                HOMESOFT:
0321 CD5205             CALL    DSKSEL          ;SELECT CORRECT DRIVE (IN A
0324 3AF60A             LDA     ERFLAG          ;
0327 B7                 ORA     A               ;CHECK FOR ERRORS DURING SE
                        JRNZ    HOME1A          ;EXIT IF ERRORS
0328+2016               DB      020H,HOME1A-$-1 ;---- FAKE JRNZ INSTRUCTION
032A CDB305             CALL    POINT           ;POINT TO TRACK REGISTER SA
032D 3600               MVI     M,000H          ;RESET TO TRACK ZERO
032F CD1905             CALL    DBL$UPDATE      ;
0332 3E0A               MVI     A,00AH          ;HOME COMMAND....
0334 CD6307             CALL    FINTFIX         ;CLEAR ANY PENDING INTERRUP
                ;                               ;AND ISSUE COMMAND
0337 CD3A07     HOME1:  CALL    FPYWAIT         ;WAIT UNTIL I/O COMPLETE
033A 3AFC0A             LDA     STATUS          ;PICKUP STATUS BYTE
033D E698               ANI     10011000B       ;CHECK STATUS
033F C8                 RZ                      ;RETURN WITH GOOD ESULT
0340 3E01       HOME1A: MVI     A,001H          ;SET ERROR ON HOME
0342 C9                 RET                     ;AND RETURN....

                HOMEHARD:
                        IF      HARDSK
0343 CD5205             CALL    DSKSEL          ;SELECT CORRECT DRIVE (IN A
0346 CDB305             CALL    POINT           ;POINT TO SAVE AREA
0349 3600               MVI     M,000H          ;SET TO TRACK ZERO
034B EB                 XCHG                    ;POINT TO SELECT WORD
034C 7E                 MOV     A,M             ;LOAD SELECT MASK
034D E6F0               ANI     11110000B       ;RESET HEAD MASK
034F 77                 MOV     M,A             ;SAVE
0350 D320               OUT     020H            ;WRITE HEAD/SELECT MASK
0352 3E20               MVI     A,020H          ;HOME COMMAND
0354 CD2107             CALL    INTFIX          ;CLEAR ANY PENDING INTERRUP
                ;                               ;AND ISSUE COMMAND
0357 CD1707     HOME2:  CALL    WAIT0           ;WAIT UNTIL I/O COMPLETE
035A 0E14               MVI     C,20            ;DELAY FOR 20 MILLISECONDS
035C CD8207             CALL    DELAY           ;
035F AF                 XRA     A               ;SET NEW TRACK REGISTER TO
0360 D322               OUT     022H            ;FOR CONTROLLER
                ;       LXI     H,MHM           ;***DEBUG***
                ;       CALL    MSPRT           ;***DEBUG***
0362 3AFC0A             LDA     STATUS          ;PICKUP STATUS BYTE
0365 E65D               ANI     01011101B       ;CHECK STATUS
0367 C8                 RZ                      ;
0368 3E01               MVI     A,001H          ;SET ERROR ON HOME
                        ENDIF
036A C9                 RET                     ;AND RETURN

                        PAGE
```

*p.114*

```
                ;-----------------------------------------------------------
                ;
                ;       THESE ARE THE HARD DISK UNBLOCK/REBLOCK AND READ AN
                ;       ROUTINES CALLED BY THE BDOS SOFTWARE.
                ;
                ;-----------------------------------------------------------

                READHARD:
                        IF      HARDSK
036B AF                 XRA     A               ;RESET UNALLOCATED COUNT
036C 32F10A             STA     UNACNT          ;
036F 3E01               MVI     A,001H          ;READ THE SELECTED CP/M SEC
0371 32F80A             STA     READOP          ;
0374 32F70A             STA     RSFLAG          ;MUST READ DATA
0377 3E02               MVI     A,WRUAL         ;
0379 32F90A             STA     WRTYPE          ;TREAT AS UNALLOCATED
                        JR      RWOPER          ;TO PERFORM THE READ
037C+1864               DB      018H,RWOPER-$-1 ;---- FAKE JR INSTRUCTION -
                        ENDIF

                WRITEHARD:
                        IF      HARDSK
037E AF                 XRA     A               ;WRITE THE SELECTED CP/M SE
037F 32F80A             STA     READOP          ;NOT A READ OPERATION
0382 79                 MOV     A,C             ;WRITE TYPE IS PASSED IN RE
0383 32F90A             STA     WRTYPE          ;

                        if      mpm20
0386 E602               ani     WRUAL           ;IS IT WRITE UNALLOCATED ??
                        JRZ     CHKUNA          ;CHECK FOR UNALLOCATED
0388+2817               DB      028H,CHKUNA-$-1 ;---- FAKE JRZ INSTRUCTION
                        else
                        CPI     WRUAL           ;IS IT WRITE UNALLOCATED ??
                        JRNZ    CHKUNA          ;CHECK FOR UNALLOCATED
                        endif
                ;
                ;       WRITE TO UNALLOCATED, SET PARAMETERS
                ;


038A 3E80               MVI     A,BLKSIZ/128    ;NEXT UNALLOC RECS
038C 32F10A             STA     UNACNT          ;
038F 3AE60A             LDA     NEWDSK          ;DISK FOR I/O
0392 32F20A             STA     UNADSK          ;UNADSK = NEWDSK
0395 2AE70A             LHLD    NEWTRK          ;
0398 22F30A             SHLD    UNATRK          ;UNATRK = NEWTRK
039B 3AE90A             LDA     NEWSEC          ;
039E 32F50A             STA     UNASEC          ;UNASEC = NEWSEC

                ;
                ;       CHECK FOR WRITE TO UNALLOCATED SECTOR
                ;

                CHKUNA:
03A1 3AF10A             LDA     UNACNT          ;ANY UNALLOCATED REMAIN ??
03A4 B7                 ORA     A               ;
```

*p.115*

```
                        JRZ     ALLOC           ;SKIP IS NOT
03A5+2833               DB      028H,ALLOC-$-1  ;---- FAKE JRZ INSTRUCTION

                ;
                ;       MORE UNALLOCATED RECORDS REMAIN
                ;

03A7 3D                 DCR     A               ;UNACNT = UNACNT - 1
03A8 32F10A             STA     UNACNT          ;
03AB 3AE60A             LDA     NEWDSK          ;SAME DISK ??
03AE 21F20A             LXI     H,UNADSK        ;
03B1 BE                 CMP     M               ;NEWDSK = UNADSK ??
                        JRNZ    ALLOC           ;SKIP IF NOT
03B2+2026               DB      020H,ALLOC-$-1  ;---- FAKE JRNZ INSTRUCTION

                ;
                ;       DISKS ARE THE SAME
                ;

03B4 21F30A             LXI     H,UNATRK        ;
03B7 CD6104             CALL    NEWTRKCMP       ;NEWTRK = UNATRK ??
                        JRNZ    ALLOC           ;SKIP IF NOT
03BA+201E               DB      020H,ALLOC-$-1  ;---- FAKE JRNZ INSTRUCTION

                ;
                ;       TRACKS ARE THE SAME
                ;

03BC 3AE90A             LDA     NEWSEC          ;SAME SECTOR ??
03BF 21F50A             LXI     H,UNASEC        ;
03C2 BE                 CMP     M               ;NEWSEC = UNASEC ??
                        JRNZ    ALLOC           ;SKIP IF NOT
03C3+2015               DB      020H,ALLOC-$-1  ;---- FAKE JRNZ INSTRUCTION

                ;
                ;       MATCH, MOVE TO NEXT SECTOR FOR FUTURE REFERENCE
                ;

03C5 34                 INR     M               ;UNASEC = UNASEC + 1
03C6 7E                 MOV     A,M             ;END OF TRACK ??
03C7 FE80               CPI     CPMSPT          ;COUNT CP/M SECTORS
                        JRC     NOOVF           ;SKIP IF NO OVERFLOW
03C9+3809               DB      038H,NOOVF-$-1  ;---- FAKE JRC INSTRUCTION

                ;
                ;       OVERFLOW TO NEXT TRACK
                ;

03CB 3600               MVI     M,000H          ;UNASEC = 0
03CD 2AF30A             LHLD    UNATRK          ;
03D0 23                 INX     H               ;
03D1 22F30A             SHLD    UNATRK          ;UNATRK = UNATRK + 1

                ;
                ;       MATCH FOUND, MARK AS UNNECESSARY READ
```

*p.116*

```
                ;

                NOOVF:
03D4 AF                 XRA     A               ;ZERO TO ACCUMULATOR
03D5 32F70A             STA     RSFLAG          ;RSFLAG = 0
                        JR      RWOPER          ;TO PERFORM THE WRITE
03D8+1808               DB      018H,RWOPER-$-1 ;---- FAKE JR INSTRUCTION -

                ;
                ;       NOT AN UNALLOCATED RECORD, REQUIRES PRE-READ
                ;

                ALLOC:
03DA AF                 XRA     A               ;ZERO TO ACCUMULATOR
03DB 32F10A             STA     UNACNT          ;UNACNT = 0
03DE 3C                 INR     A               ;ONE TO ACCUMULATOR
03DF 32F70A             STA     RSFLAG          ;RSFLAG = 1

                ;-----------------------------------------------------------
                ;
                ;       THE FOLLOWING CODE IS COMMON TO BOTH READ AND WRITE
                ;
                ;-----------------------------------------------------------

                RWOPER:
03E2 AF                 XRA     A               ;ZERO TO ACCUMULATOR
03E3 32F60A             STA     ERFLAG          ;NO ERRORS YET....
03E6 3AE90A             LDA     NEWSEC          ;COMPUTE HOST SECTOR
                        REPT    SECSHF          ;COMPUTE HOST SECTOR
                        ORA     A               ;CARRY = 0
                        RAR                     ;SHIFT RIGHT
                        ENDM
03E9+B7                 ORA     A               ;CARRY = 0
03EA+1F                 RAR                     ;SHIFT RIGHT
03EB+B7                 ORA     A               ;CARRY = 0
03EC+1F                 RAR                     ;SHIFT RIGHT
03ED+B7                 ORA     A               ;CARRY = 0
03EE+1F                 RAR                     ;SHIFT RIGHT
03EF 32EE0A             STA     NEWHST          ;HOST SECTOR TO SEEK

                ;
                ;       ACTIVE HOST SECTOR ??
                ;

03F2 21EF0A             LXI     H,HSTACT        ;HOST ACTIVE FLAG
03F5 7E                 MOV     A,M             ;
03F6 3601               MVI     M,001H          ;ALWAYS BECOMES 1
03F8 B7                 ORA     A               ;WAS IT ALREADY ??
                        JRZ     FILLHST         ;FILL HOST IF NOT
03F9+2821               DB      028H,FILLHST-$-1        ;---- FAKE JRZ INST

                ;
                ;       HOST BUFFER ACTIVE, SAME AS SEEK BUFFER
                ;
```

*p.117*

```
03FB 3AE60A             LDA     NEWDSK          ;
03FE 21EA0A             LXI     H,HSTDSK        ;SAME DISK ??
0401 BE                 CMP     M               ;NEWDSK = HSTDSK ??
                        JRNZ    NOMATCH         ;
0402+2011               DB      020H,NOMATCH-$-1        ;---- FAKE JRNZ INS

                ;
                ;       SAME DISK, SAME TRACK ??
                ;

0404 21EB0A             LXI     H,HSTTRK        ;
0407 CD6104             CALL    NEWTRKCMP       ;NEWTRK = HSTTRK ??
                        JRNZ    NOMATCH         ;
040A+2009               DB      020H,NOMATCH-$-1        ;---- FAKE JRNZ INS

                ;
                ;       SAME DISK, SAME TRACK, SAME BUFFER ??
                ;

040C 3AEE0A             LDA     NEWHST          ;
040F 21ED0A             LXI     H,HSTSEC        ;NEWHST = HSTSEC ??
0412 BE                 CMP     M               ;
                        JRZ     MATCH           ;SKIP IF MATCH
0413+2824               DB      028H,MATCH-$-1  ;---- FAKE JRZ INSTRUCTION

                ;
                ;       PROPER DISK, BUT NOT CORRECT SECTOR
                ;

                NOMATCH:
0415 3AF00A             LDA     HSTWRT          ;HOST WRITTEN ??
0418 B7                 ORA     A               ;
0419 C46D04             CNZ     WRITEHST        ;CLEAR HOST BUFFER

                ;
                ;       MAY HAVE TO FILL HOST BUFFER
                ;

                FILLHST:
041C 3AE60A             LDA     NEWDSK          ;
041F 32EA0A             STA     HSTDSK          ;
0422 2AE70A             LHLD    NEWTRK          ;
0425 22EB0A             SHLD    HSTTRK          ;
0428 3AEE0A             LDA     NEWHST          ;
042B 32ED0A             STA     HSTSEC          ;
042E 3AF70A             LDA     RSFLAG          ;NEED TO READ ??
0431 B7                 ORA     A               ;
0432 C47F04             CNZ     READHST         ;YES, IF 1
0435 AF                 XRA     A               ;ZERO TO ACCUMULATOR
0436 32F00A             STA     HSTWRT          ;NO PENDING WRITE

                MATCH:
0439 3AE90A             LDA     NEWSEC          ;MASK BUFFER NUMBER
043C E607               ANI     SECMSK          ;LEAST SIGNIF BITS
043E 6F                 MOV     L,A             ;READY TO SHIFT
```

*p.118*

```
043F 2600               MVI     H,000H          ;DOUBLE COUNT
                        REPT    7
                        DAD     H               ;
                        ENDM
0441+29                 DAD     H               ;
0442+29                 DAD     H               ;
0443+29                 DAD     H               ;
0444+29                 DAD     H               ;
0445+29                 DAD     H               ;
0446+29                 DAD     H               ;
0447+29                 DAD     H               ;

                ;
                ;       HL NOW HAS RELATIVE HOST BUFFER ADDRESS
                ;

0448 119C0E             LXI     D,HSTBUF        ;
044B 19                 DAD     D               ;HL = HOST ADDRESS
044C EB                 XCHG                    ;NOW IN DE
044D 2AAF00             LHLD    DMAADR          ;GET/PUT CP/M DATA
0450 EB                 XCHG                    ;SET FOR Z80 LDIR INSTRUCTI
                ;       LXI     B,128           ;LENGTH OF MOVE
0451 3AF80A             LDA     READOP          ;WHICH WAY ??
0454 B7                 ORA     A               ;
0455 C23D0E             JNZ     RWMOVE          ;SKIP IF READ
                ;
                ;       WRITE OPERATION, MARK AND SWITCH DIRECTION
                ;

0458 3E01               MVI     A,001H          ;
045A 32F00A             STA     HSTWRT          ;HSTWRT = 1
045D EB                 XCHG                    ;SWAP DIRECTION
045E C33D0E             jmp     rwmove
                        endif

                        PAGE

                ;-----------------------------------------------------------
                ;
                ;       UTILITY SUBROUTINE FOR 16 BIT COMPARE
                ;
                ;-----------------------------------------------------------

                        IF      HARDSK
                NEWTRKCMP:
0461 EB                 XCHG                    ;HL = .UNATRK OR .HSTTRK
0462 21E70A             LXI     H,NEWTRK        ;
0465 1A                 LDAX    D               ;LOW BYTE COMPARE
0466 BE                 CMP     M               ;SAME ??
0467 C0                 RNZ                     ;RETURN IF NOT
0468 13                 INX     D               ;TO CHECK HIGH BYTE
0469 23                 INX     H               ;
046A 1A                 LDAX    D               ;
```

*p.119*

```
046B BE                 CMP     M               ;SETS FLAGS
046C C9                 RET                     ;

                        PAGE

                ;-----------------------------------------------------------
                ;
                ;       WRITEHST PERFORMS THE PHYSICAL WRITE TO THE HOST DI
                ;       READHST PERFORMS THE PHYSICAL READ FROM THE HOST DI
                ;
                ;       HSTDSK = HOST DISK NUMBER
                ;       HSTTRK = HOST TRACK NUMBER
                ;       HSTSEC = HOST SECTOR NUMBER
                ;       RETURN ERROR FLAG IN ERFLAG
                ;
                ;-----------------------------------------------------------

                WRITEHST:
046D 3E05               MVI     A,005H          ;SETUP DMA FOR WRITE
046F 32CE00             STA     DMAS3F          ;
0472 3E02               MVI     A,002H          ;WRITE COMMAND
0474 32FA0A             STA     CMD             ;SAVE FOR LATER
0477 219B0E             LXI     H,HSTBUF-1      ;WRITE MUST WRITE CONTROL B
047A 22BC00             SHLD    DMASA           ;
                        JR      HRW0            ;
047D+1810               DB      018H,HRW0-$-1   ;---- FAKE JR INSTRUCTION -

                READHST:
047F 3E01               MVI     A,001H          ;SETUP DMA FOR READ
0481 32CE00             STA     DMAS3F          ;
0484 3E04               MVI     A,004H          ;READ COMMAND
0486 32FA0A             STA     CMD             ;SAVE FOR LATER
0489 219C0E             LXI     H,HSTBUF        ;READ ONLY DATA BYTES
048C 22BC00             SHLD    DMASA           ;

                HRW0:
048F 3E05               MVI     A,05            ;FIVE RETRIES
0491 32020B             STA     T$RETRIES       ;SETUP TEMPORARY RETRIES CO
0494 3EFF               MVI     A,0FFH          ;INIT TOGGLE SO THAT NO HOM
0496 32030B             STA     HOME$TOGGLE     ;ALTERNATE RETRIES WILL BE
                ;                               ;OTHER RETRIES WILL BE DONE

                HRW1:
0499 3AED0A             LDA     HSTSEC          ;HOST SECTOR NUMBER
049C 32B100             STA     SECTNO          ;SAVE SECTOR NUMBER
049F 3AEA0A             LDA     HSTDSK          ;PICKUP DRIVE ID FOR SELECT
04A2 CD5205             CALL    DSKSEL          ;SELECT CORRECT DRIVE FOR I
04A5 CDB305             CALL    POINT           ;POINT TO TRACK REGISTER SA
04A8 EB                 XCHG                    ;POINT TO SELECT MASK
04A9 3EF0               MVI     A,11110000B     ;TO REMOVE CURRENT HEAD SEL
04AB A6                 ANA     M               ;
04AC 77                 MOV     M,A             ;
04AD E5                 PUSH    H               ;SAVE MASK ADDRESS
04AE CD3205             CALL    SETHED          ;COMPUTE CORRECT HEAD NUMBE
04B1 7D                 MOV     A,L             ;TRACK NUMBER AFTER HEAD CA
```

*p.120*

```
04B2 32AD00             STA     TRAKNO          ;
04B5 E1                 POP     H               ;RESTORE MASK ADDRESS
04B6 3AAE00             LDA     HEADNO          ;TO OR IN NEW HEAD NUMBER
04B9 B6                 ORA     M               ;
04BA 77                 MOV     M,A             ;SAVE NEW DRIVE/HEAD SELECT
04BB E67F               ANI     07FH            ; MASK OFF LARGE DRIVE FLAG
04BD D320               OUT     020H            ;WRITE IT TO SELECT NEW HEA
04BF 0E01               MVI     C,1             ;DELAY FOR 1 MILLISECOND
04C1 CD8207             CALL    DELAY           ;

                HRW2:
04C4 CDB305             CALL    POINT           ;IS A SEEK NECESSARY ??
04C7 3AAD00             LDA     TRAKNO          ;CHECK
04CA BE                 CMP     M               ;WELL ??
                        JRZ     HRW5            ;NO SEEK NECESSARY...
04CB+2814               DB      028H,HRW5-$-1   ;---- FAKE JRZ INSTRUCTION

                HRW3:
04CD D322               OUT     022H            ;WRITE NEW TRACK NUMBER
04CF 46                 MOV     B,M             ;SAVE TEMPORARILY
04D0 77                 MOV     M,A             ;UPDATE TRACK REGISTER SAVE
04D1 78                 MOV     A,B             ;OLD TRACK NUMBER
04D2 D321               OUT     021H            ;TO OLD TRACK REGISTER
04D4 3E10               MVI     A,010H          ;SEEK COMMAND
04D6 CD2107             CALL    INTFIX          ;CLEAR ANY PENDING INTERRUP
                ;                               ;AND ISSUE COMMAND
04D9 CD1707     HRW4:   CALL    WAIT0           ;WAIT FOR I/O
04DC 0E14               MVI     C,20            ;DELAY AFTER SEEK FOR 20 MI
04DE CD8207             CALL    DELAY           ;

                HRW5:
04E1 3AB100             LDA     SECTNO          ;SET SECTOR
04E4 D321               OUT     021H            ;


                HRW6:
04E6 21BA00             LXI     H,DMAS1         ;SETUP DMA FOR HARD DISK I/
04E9 010006             LXI     B,0600H         ;
                        OUTIR                   ;
04EC+EDB3               DB      0EDH,0B3H       ;---- FAKE OTIR INSTRUCTION
04EE 21C000             LXI     H,DMAS2H        ;
04F1 010006             LXI     B,0600H         ;
                        OUTIR                   ;
04F4+EDB3               DB      0EDH,0B3H       ;---- FAKE OTIR INSTRUCTION
04F6 21CA00             LXI     H,DMAS3         ;
04F9 010007             LXI     B,0700H         ;
                        OUTIR                   ;
04FC+EDB3               DB      0EDH,0B3H       ;---- FAKE OTIR INSTRUCTION

04FE 3AFA0A             LDA     CMD             ;PICKUP I/O COMMAND
0501 CD2107             CALL    INTFIX          ;CLEAR ANY PENDING INTERRUP
                ;                               ;AND ISSUE COMMAND
0504 CD1707     HRW7:   CALL    WAIT0           ;WAIT FOR COMPLETION

0507 3E5D               MVI     A,01011101B     ;SETUP STATUS AND MASK
```

*p.121*

```
0509 32FB0A             STA     MASK            ;SAVE FOR STATUS CHECK
050C CDAE06             CALL    CHECK$STAT      ;CHECK STATUS FROM I/O
050F C8                 RZ                      ;OK ??

0510 3A030B             LDA     HOME$TOGGLE     ;
0513 2F                 CMA                     ;CHANGE TOGGLE SO THAT HOME
0514 32030B             STA     HOME$TOGGLE     ;

                        JR      HRW1            ;RETRY I/O
0517+1880               DB      018H,HRW1-$-1   ;---- FAKE JR INSTRUCTION -
                        ENDIF

                        PAGE

                ;-----------------------------------------------------------
                ;
                ;       DOUBLE SIDED TRACK REGISTER UPDATE ROUTINE
                ;
                ;-----------------------------------------------------------

                DBL$UPDATE:
0519 3AB600             LDA     MPARMS          ;CHECK FOR DOUBLE SIDED DRI
051C E601               ANI     1               ;  IS FLAG SET
051E C8                 RZ                      ;   NO  - SO RETURN
051F 3AAC00             LDA     DISKNO          ;CURRENT DISK DRIVE
0522 FE04               CPI     004H            ;IS IT A FLOPPY
0524 D0                 RNC                     ;NO, RETURN WITHOUT UPDATE
0525 E602               ANI     00000010B       ;IS THIS DRIVE 2 OR 3 ??
0527 7E                 MOV     A,M             ;WE WERE CALLED WITH (HL) P
                        JRZ     DBL$LOW         ;IT MUST BE DRIVE ZERO OR O
0528+2804               DB      028H,DBL$LOW-$-1        ;---- FAKE JRZ INST
052A 2B                 DCX     H               ;BACKUP TO OTHER SIDE POINT
052B 2B                 DCX     H               ;
                        JR      DBL$SAVE        ;
052C+1802               DB      018H,DBL$SAVE-$-1       ;---- FAKE JR INSTR

                DBL$LOW:
052E 23                 INX     H               ;BUMP UP TO DRIVE TWO OR TH
052F 23                 INX     H               ;

                DBL$SAVE:
0530 77                 MOV     M,A             ;UPDATE OTHER SIDE REGISTER
0531 C9                 RET                     ;

                        PAGE

                ;-----------------------------------------------------------
                ;
                ;       ROUTINE TO COMPUTE HEAD NUMBER FROM TRACK NUMBER
                ;       TRACK NUMBER IS IN HL ON ENTRY
                ;
                ;-----------------------------------------------------------
                        IF      HARDSK
                SETHED:
```

*p.122*

```
0532 2AEB0A             LHLD    HSTTRK          ;CP/M TRACK NUMBER (0-800)
0535 E680               ANI     80H             ; CHECK FOR LARGE DRIVE
0537 7D                 MOV     A,L             ;LOW ORDER
                        JRZ     SETH14          ;  SMALL DRIVE
0538+2806               DB      028H,SETH14-$-1 ;---- FAKE JRZ INSTRUCTION
053A E607               ANI     00000111B       ;GET TRACK MOD 8 (HEAD NUMB
053C 0E03               MVI     C,3             ;LIMIT LOOP FOR DIVIDE BY E
                        JR      SETDVD          ;
053E+1804               DB      018H,SETDVD-$-1 ;---- FAKE JR INSTRUCTION -
0540 E603       SETH14: ANI     00000011B       ;GET TRACK MOD 4 (HEAD NUMB
0542 0E02               MVI     C,2             ;LIMIT LOOP FOR DIVIDE BY F
0544 32AE00     SETDVD: STA     HEADNO          ;SAVE AS HEAD NUMBER
0547 B7         SHD1:   ORA     A               ;ENSURE CARRY IS ZERO
0548 7C                 MOV     A,H             ;FOR SHIFT
0549 1F                 RAR                     ;ONE BIT
054A 67                 MOV     H,A             ;
054B 7D                 MOV     A,L             ;LOW ORDER
054C 1F                 RAR                     ;CARRY PARTICIPATES FROM HI
054D 6F                 MOV     L,A             ;
054E 0D                 DCR     C               ;END OF DIVIDE YET ??
                        JRNZ    SHD1            ;NO, CONTINUE
054F+20F6               DB      020H,SHD1-$-1   ;---- FAKE JRNZ INSTRUCTION
0551 C9                 RET                     ;RETURN TO CALLER, TRACK IN
                        ENDIF

                        PAGE

                ;-----------------------------------------------------------
                ;
                ;       DISK DRIVE SELECT ROUTINE
                ;               ON ENTRY, THE ACCUMULATOR CONTAINS THE DRIV
                ;               RETURNS CARRY SET FOR HARD DISK SELECTED
                ;               RETURNS CARRY RESET FOR FLOPPY DISK SELECTE
                ;
                ;-----------------------------------------------------------

                DSKSEL:
0552 FE04               CPI     004H            ;IS IT HARD DISK ??
                        JRNC    SELHARD         ;YES, GO PROCESS....
0554+3045               DB      030H,SELHARD-$-1        ;---- FAKE JRNC INS

                SELSOFT:
0556 21AC00             LXI     H,DISKNO        ;CURRENT DRIVE NUMBER
0559 BE                 CMP     M               ;SAME DRIVE AS LAST TIME ??
                        JRZ     SLS3            ;YES, DONT BOTHER WITH UNLO
055A+2819               DB      028H,SLS3-$-1   ;---- FAKE JRZ INSTRUCTION
055C 77                 MOV     M,A             ;UPDATE WITH CURRENT DRIVE

                ;-----------------------------------------------------------
                ;
                ;       WE WILL NOW FORCE THE HEAD TO UNLOAD PRIOR TO THE S
                ;       TO ENSURE THAT WHEN WE RETURN TO THIS DISK WE WILL
                ;       LOAD AND WAIT FOR THE HEAD TO SETTLE.
                ;
                ;-----------------------------------------------------------
```

*p.123*

```
                SLS1:
055D DB04               IN      004H            ;ENSURE FLOPPY PORT NOT BUS
055F 1F                 RAR                     ;
                        JRC     SLS1            ;
0560+38FB               DB      038H,SLS1-$-1   ;---- FAKE JRC INSTRUCTION
0562 DB05               IN      005H            ;READ THE TRACK REGISTER
0564 D307               OUT     007H            ;ENSURE WE DONT MOVE THE HE

0566 3E12               MVI     A,012H          ;SEEK AND UNLOAD HEAD
0568 CD6307             CALL    FINTFIX         ;CLEAR ANY PENDING INTERRUP
                ;                               ;  AND ISSUE COMMAND
056B CD3A07     SLS2:   CALL    FPYWAIT         ;WAIT HERE FOR INTERRUPT
056E 3AFC0A             LDA     STATUS          ;HOW DID THE I/O GO?
0571 E698               ANI     10011000B       ;  CHECK
                        JRNZ    SLSERR          ;EXIT IF ERROR
0573+2020               DB      020H,SLSERR-$-1 ;---- FAKE JRNZ INSTRUCTION

                ;-----------------------------------------------------------
                ;
                ;       WE WILL NOW LOAD THE SELECT MASK AND SELECT THE DRI
                ;       EVEN IF ITS THE SAME DRIVE BECAUSE THE DENSITY MAY
                ;       HAVE CHANGED.
                ;
                ;-----------------------------------------------------------

                SLS3:
0575 CDB305             CALL    POINT           ;POINT TO TRACK SAVE AREA
0578 EB                 XCHG                    ;POINT TO SELECT MASK
0579 3AAD00             LDA     TRAKNO          ;NEXT TRACK FOR I/O
057C FE02               CPI     002H            ;IS IT TRACK ZERO OR ONE
057E 3EFF               MVI     A,11111111B     ;ASSUME NO....
                        JRNC    SLS4            ;VERIFY ASSUMPTION
0580+3002               DB      030H,SLS4-$-1   ;---- FAKE JRNC INSTRUCTION
0582 3EFE               MVI     A,11111110B     ;FORCE SINGLE DENSITY FOR 0

                SLS4:
0584 A6                 ANA     M               ;LOAD MASK AND CORRECT IF N
0585 D308               OUT     008H            ;SELECT IT
0587 DB04               IN      004H            ;IS DRIVE READY?
0589 17                 RAL                     ;
                        JRC     SLSERR          ;IF NOT...BRANCH
058A+3809               DB      038H,SLSERR-$-1 ;---- FAKE JRC INSTRUCTION
058C EB                 XCHG                    ;RESTORE TRACK REGISTER ADD
058D 7E                 MOV     A,M             ;PICK UP TRACK NUMBER
058E D305               OUT     005H            ;GIVE IT TO CONTROLLER
0590 AF                 XRA     A               ;ENSURE CARRY IS RESET
0591 32F60A             STA     ERFLAG          ;ALSO ZERO ERROR INDICATOR
0594 C9                 RET

0595 AF         SLSERR: XRA     A               ;ENSURE CARRY IS RESET
0596 3C                 INR     A               ;SET TO 1 FOR ERROR FLAG
0597 32F60A             STA     ERFLAG          ;SHOW ERROR
059A C9                 RET
```

*p.124*

```
                ;-----------------------------------------------------------
                ;
                ;       THIS ROUTINE SETS UP THE HARD DISK BY SELECTING THE
                ;       DRIVE AND RELOADING THE HEAD AND TRACK REGISTERS IN
                ;       HARD DISK CONTROLLER READY FOR I/O LATER.
                ;
                ;-----------------------------------------------------------

                SELHARD:
                        IF      HARDSK
059B 21AC00             LXI     H,DISKNO        ;CURRENT DRIVE SELECTED
059E BE                 CMP     M               ;SAME ??
059F C8                 RZ                      ;YES, NO NEW SELECT NECESSA
05A0 77                 MOV     M,A             ;UPDATE DISKNO

                SLH1:
05A1 CDB305             CALL    POINT           ;TRACK SAVE REGISTER
05A4 EB                 XCHG                    ;POINT TO SELECT MASK
05A5 7E                 MOV     A,M             ;LOAD DRIVE/HEAD VALUE
05A6 D320               OUT     020H            ;WRITE IT TO SELECT PORT
05A8 EB                 XCHG                    ;REGAIN ADDRESS OF TRACK RE
05A9 7E                 MOV     A,M             ;LOAD OLD TRACK NUMBER
05AA D322               OUT     022H            ;WRITE IT TO OLD TRACK REGI
05AC 0E14               MVI     C,20            ;DELAY FOR 20 MILLISECONDS
05AE CD8207             CALL    DELAY           ;
05B1 37                 STC                     ;SET CARRY TO SHOW HARD DIS
                        ENDIF
05B2 C9                 RET                     ;RETURN TO CALLER

                        PAGE

                ;-----------------------------------------------------------
                ;
                ;       SUBROUTINE TO POINT TO CURRENT TRACK REGISTER SAVE
                ;
                ;-----------------------------------------------------------

                POINT:
05B3 2AAC00             LHLD    DISKNO  ;PICKUP CURRENT DISK
05B6 7D                 MOV     A,L     ;
05B7 2600               MVI     H,0     ;RESET HIGH ORDER HALF
05B9 117000             LXI     D,TRK0  ;LOAD TRACK POINTER
05BC 19                 DAD     D       ;POINT TO CURRENT TRACK PTR
05BD 54                 MOV     D,H     ; DE = TRACK
05BE 5D                 MOV     E,L     ;
05BF 010C00             LXI     B,12    ;
05C2 09                 DAD     B       ; HL = SELECT
                        IF      HARDSK
05C3 FE04               CPI     4       ;
                        JRC     PNTFN   ; FLOPPY DISK
05C5+380D               DB      038H,PNTFN-$-1  ;---- FAKE JRC INSTRUCTION
05C7 3E10               MVI     A,10H   ;
05C9 A6                 ANA     M       ; CHECK DRIVE SELECT
                        JRZ     PNTH2   ;   MUST BE DRIVE  # 2
05CA+2805               DB      028H,PNTH2-$-1  ;---- FAKE JRZ INSTRUCTION
```

*p.125*

```
05CC 11B800             LXI     D,HTK1  ; POINT TO DRIVE 1
                        JR      PNTFN   ;
05CF+1803               DB      018H,PNTFN-$-1  ;---- FAKE JR INSTRUCTION -
05D1 11B900     PNTH2:  LXI     D,HTK2  ; POINT TO DRIVE 2
                        ENDIF
05D4 EB         PNTFN:  XCHG            ; SWITCH
05D5 C9                 RET             ; HL = TRACK    DE = SELECT

                ;-----------------------------------------------------------
                ;
                ;       ROUTINE TO TRANSLATE SECTOR NUMBER
                ;
                ;-----------------------------------------------------------

                SECTRAN:
05D6 EB                 XCHG                    ;TABLE ADDRESS IS IN DE (NO
05D7 7C                 MOV     A,H             ;IS THERE A TABLE ADDRESS ?
05D8 B5                 ORA     L               ;
                        JRZ     STRN2           ;NO, JUST RETURN ENTERED QU
05D9+2807               DB      028H,STRN2-$-1  ;---- FAKE JRZ INSTRUCTION

                STRN1:
05DB 0600               MVI     B,000H          ;ENSURE OK FOR SINGLE BYTE
05DD 09                 DAD     B               ;ADD SECTOR NUMBER
05DE 6E                 MOV     L,M             ;LOAD TRANSLATED VALUE
05DF 2600               MVI     H,000H          ;
05E1 C9                 RET                     ;NEW VALUE RETURNED IN HL

                STRN2:
05E2 09                 DAD     B               ;RETURN SAME VALUE AS ENTER
05E3 C9                 RET                     ;

                ;-----------------------------------------------------------
                ;
                ;       ROUTINES TO DO FLOPPY I/O
                ;
                ;-----------------------------------------------------------

                READSOFT:
05E4 3E9F               MVI     A,09FH          ;MASK FOR READ STATUS
05E6 32FB0A             STA     MASK            ;
05E9 3E01               MVI     A,001H          ;SETUP DMA FOR READ
05EB 32CE00             STA     DMAS3F          ;
05EE 3E8C               MVI     A,08CH          ;READ COMMAND
                        JR      SRW1            ;
05F0+180F               DB      018H,SRW1-$-1   ;---- FAKE JR INSTRUCTION -

                WRITESOFT:
05F2 3EFF               MVI     A,0FFH          ;MASK FOR WRITE STATUS
05F4 32FB0A             STA     MASK            ;
05F7 CD6B0E             CALL    MVDTB           ;
05FA 3E05               MVI     A,005H          ;SETUP DMA FOR WRITE
05FC 32CE00             STA     DMAS3F          ;
05FF 3EAC               MVI     A,0ACH          ;WRITE COMMAND
```

*p.126*

```
                SRW1:
0601 32FA0A             STA     CMD             ;
0604 211D13             LXI     H,FPYBUF        ;
0607 22BC00             SHLD    DMASA           ;
060A 3AE60A             LDA     NEWDSK          ;
060D CD5205             CALL    DSKSEL          ;SELECT DRIVE FOR I/O
0610 3AF60A             LDA     ERFLAG          ;CHECK FOR SELECT ERROR
0613 B7                 ORA     A               ;
0614 C0                 RNZ                     ;RETURN IF ERROR

                SRW2:
0615 3E0A               MVI     A,10            ;SET NUMBER OF TRIALS
0617 32020B             STA     T$RETRIES       ;SAVE FOR RETRY ROUTINE
061A AF                 XRA     A
061B 32030B             STA     HOME$TOGGLE     ;FORCE HOME PRIOR TO EACH R

                LOAD$HEAD:
061E DB08               IN      008H            ;IS HEAD LOADED ??
0620 E602               ANI     00000010B       ;CHECK IT....
                        JRNZ    REMOVE$LD       ;YES, ITS LOADED, DONT RELO
0622+201F               DB      020H,REMOVE$LD-$-1      ;---- FAKE JRNZ INS
0624 DB05               IN      005H            ;DUMMY SEEK TO START HEAD L
0626 D307               OUT     007H            ;KEEP IT SHORT....
0628 3E1A               MVI     A,01AH          ;START HEAD LOADING
062A CD6307             CALL    FINTFIX         ;CLEAR ANY PENDING INTERRUP
                ;                               ;AND ISSUE COMMAND
062D CD3A07     LDH1:   CALL    FPYWAIT         ;WAIT FOR I/O TO COMPLETE
0630 3AFC0A             LDA     STATUS          ;HOW DID IT GO?
0633 E698               ANI     10011000B       ;CHECK
                        JRNZ    CHECKIT         ;DO NOT GO ON IF ERROR
0635+2044               DB      020H,CHECKIT-$-1        ;---- FAKE JRNZ INS

0637 0E10               MVI     C,16            ;WAIT HERE FOR 16 MS
0639 CD8207             CALL    DELAY           ;CALL WAIT ROUTINE
063C CDB305             CALL    POINT           ;REESTABLISH TRACK REGISTER
063F 36FE               MVI     M,254           ;ENSURE FURTHER SEEK AND DE
                        JR      TRKTST          ;
0641+1807               DB      018H,TRKTST-$-1 ;---- FAKE JR INSTRUCTION -

                REMOVE$LD:
0643 21FA0A             LXI     H,CMD           ;POINT TO I/O COMMAND
0646 3EFB               MVI     A,11111011B     ;REMOVE HEAD LOAD BIT
0648 A6                 ANA     M               ;DO IT....
0649 77                 MOV     M,A             ;SAVE IT BACK INTO CMD

                TRKTST:
064A CDB305             CALL    POINT           ;RESTORE TRACK REGISTER POI
064D 3AE70A             LDA     NEWTRK          ;GET NEW TRACK NUMBER
0650 32AD00             STA     TRAKNO          ;SAVE IN COMMON PLACE
0653 BE                 CMP     M               ;SAME AS LAST TIME ??
                        JRZ     FSECSET         ;YES, DONT BOTHER WITH SEEK
0654+281A               DB      028H,FSECSET-$-1        ;---- FAKE JRZ INST
0656 77                 MOV     M,A             ;SAVE IT
0657 D307               OUT     007H            ;ALSO SEND IT TO CONTROLLER
```

*p.127*

```
0659 CD1905             CALL    DBL$UPDATE      ;DOUBLE SIDED SUPPORT

                FLOPPY$SEEK:
065C 3E1A               MVI     A,01AH          ;SEEK COMMAND WITH HEAD LOA
065E CD6307             CALL    FINTFIX         ;CLEAR ANY PENDING INTERRUP
                ;                               ;AND ISSUE COMMAND
0661 CD3A07     FPS1:   CALL    FPYWAIT         ;WAIT FOR I/O TO COMPLETE
0664 3AFC0A             LDA     STATUS          ;HOW DID IT GO?
0667 E698               ANI     10011000B       ;CHECK
                        JRNZ    CHECKIT         ;DO NOT GO ON IF ERROR
0669+2010               DB      020H,CHECKIT-$-1        ;---- FAKE JRNZ INS

066B 0E10               MVI     C,16            ;SET FOR 16 MS DELAY
066D CD8207             CALL    DELAY           ;
                FSECSET:
0670 3AE90A             LDA     NEWSEC          ;SET SECTOR
0673 32B100             STA     SECTNO          ;SAVE IN COMMONN PLACE
0676 D306               OUT     006H            ;

0678 CD8706             CALL    FLOPPYIO        ;DO I/O
                CHECKIT:
067B CDAE06             CALL    CHECK$STAT      ;CHECK STATUS OF I/O
067E 3AF60A             LDA     ERFLAG          ;SETUP TO RETURN TO BDOS
0681 CC7E0E             CZ      MVDFB           ;
0684 C8                 RZ                      ;EITHER OK OR PERMANENT ERR
                        JR      LOAD$HEAD       ;ERROR, JUST RETRY THIS SAM
0685+1897               DB      018H,LOAD$HEAD-$-1      ;---- FAKE JR INSTR

                        PAGE

                ;-----------------------------------------------------------
                ;
                ;       THIS IS THE ROUTINE THAT DOES THE FLOPPY DISK I/O
                ;
                ;-----------------------------------------------------------

                FLOPPYIO:
                        IF      NOT DMA
                        LXI     H,066H          ;MOVE DATA FROM 066H TO SAV
                        LXI     D,SAVE1         ;
                        LXI     B,004H          ;
                        LDIR                    ;MOVE IT

                        LXI     H,NMIRTN        ;SET NMI ROUTINE TO NMI ADD
                        LXI     D,066H          ;
                        LXI     B,004H          ;
                        LDIR                    ;MOVE IT

                        LDA     CMD             ;IS IT A WRITE ??
                        ANI     20H             ;
                        JZ      FRD             ;NO, LEAVE INI CMD IN LOW M
                        LXI     H,067H          ;POINT TO COMMAND AREA
                        MVI     M,0A3H          ;MAKE IT AN OTI CMD....
                FRD     EQU     $               ;LABEL
                        ENDIF
```

*p.128*

```
                        IF      DMA
0687 21BA00             LXI     H,DMAS1         ;INITIALIZE DMA
068A 010006             LXI     B,0600H         ;
                        OUTIR                   ;WRITE TO DMA
068D+EDB3               DB      0EDH,0B3H       ;---- FAKE OTIR INSTRUCTION
068F 21C600             LXI     H,DMAS2F        ;
0692 010004             LXI     B,0400H         ;
                        OUTIR                   ;WRITE TO DMA
0695+EDB3               DB      0EDH,0B3H       ;---- FAKE OTIR INSTRUCTION
0697 21CA00             LXI     H,DMAS3         ;
069A 010007             LXI     B,0700H         ;
                        OUTIR                   ;WRITE TO DMA
069D+EDB3               DB      0EDH,0B3H       ;---- FAKE OTIR INSTRUCTION
                        ENDIF

069F 0E07               MVI     C,007H          ;PORT ADDRESS FOR I/O
06A1 211D13             LXI     H,FPYBUF        ;DMA ADDRESS
06A4 3AFA0A             LDA     CMD             ;I/O COMMAND
06A7 CD6307             CALL    FINTFIX         ;CLEAR ANY PENDING INTERRUP
                ;                               ;AND ISSUE COMMAND
06AA CD3A07     FWT1:   CALL    FPYWAIT         ;WAIT HERE FOR I/O TO COMPL

                        IF      NOT DMA
                        LXI     H,SAVE1         ;SETUP TO REPLACE DATA
                        LXI     D,066H          ;COPIED FROM NMI LOCATION
                        LXI     B,004H          ;
                        LDIR                    ;MOVE IT....
                        ENDIF

06AD C9                 RET                     ;RETURN, I/O COMPLETED

                ;-----------------------------------------------------------
                ;
                ;       WE WILL NOW CHECK THE STATUS OF THE I/O OPERATION
                ;               RETURN WITH CONDITION CODE ZERO = NO RETRY
                ;               RETURN WITH CONDITION CODE NON ZERO = RETRY
                ;
                ;-----------------------------------------------------------

                CHECK$STAT:
06AE 21F60A             LXI     H,ERFLAG        ;POINT TO ERROR INDICATOR
06B1 3600               MVI     M,000H          ;ASSUME OK
06B3 21FC0A             LXI     H,STATUS        ;CHECK STATUS
06B6 3AFB0A             LDA     MASK            ;MASK FOR UNWANTED BIT REMO
06B9 A6                 ANA     M               ;
06BA 77                 MOV     M,A             ;SAVE CLEANED STATUS
06BB C8                 RZ                      ;OK, SO RETURN

                CHKS0:
06BC CDEE02             CALL    RETMOD          ;
06BF FE03               CPI     003H            ;HARD DISK ??
06C1 21FC0A             LXI     H,STATUS        ;
06C4 7E                 MOV     A,M             ;RELOAD STATUS BYTE
                        JRNC    CHKS2           ;YES, CHECK FOR DRIVE READY
```

*p.129*

```
06C5+3006               DB      030H,CHKS2-$-1  ;---- FAKE JRNC INSTRUCTION

                CHKS1:
06C7 FE80               CPI     080H            ;IS FLOPPY DISK NOT READY ?
                        JRZ     BADIO           ;YES, DONT BOTHER WITH RETR
06C9+283D               DB      028H,BADIO-$-1  ;---- FAKE JRZ INSTRUCTION
                        JR      CHKS3           ;GO TO BAD MESSAGE ROUTINE
06CB+1819               DB      018H,CHKS3-$-1  ;---- FAKE JR INSTRUCTION -

                CHKS2:
06CD FE00               CPI     000H            ;IS HARD DISK NOT READY ??
                        JRZ     BADIO           ;YES, BYPASS ERROR MESSAGE
06CF+2837               DB      028H,BADIO-$-1  ;---- FAKE JRZ INSTRUCTION
06D1 E640               ANI     01000000B       ;IS IT WRITE FAULT ??
                        JRZ     CHKS3           ;NO, CONTINUE ON
06D3+2811               DB      028H,CHKS3-$-1  ;---- FAKE JRZ INSTRUCTION
06D5 CDB305             CALL    POINT           ;POINT TO TRACK REGISTER
06D8 EB                 XCHG                    ;POINT TO SELECT MASK
06D9 7E                 MOV     A,M             ;
06DA F640               ORI     01000000B       ;TURN ON WRITE FAULT CLEAR
06DC D320               OUT     020H            ;
06DE 7E                 MOV     A,M             ;RESET CLEAR
06DF D320               OUT     020H            ;
06E1 0E14               MVI     C,20            ;DELAY JUST TO BE SAFE
06E3 CD8207             CALL    DELAY           ;

                CHKS3:
06E6 3A030B             LDA     HOME$TOGGLE
06E9 B7                 ORA     A               ;IS A HOME NEEDED ON THIS R
                        JRNZ    CHKS4           ;
06EA+200B               DB      020H,CHKS4-$-1  ;---- FAKE JRNZ INSTRUCTION

06EC 3AFC0A             LDA     STATUS          ;SAVE STATUS OVER HOME
06EF F5                 PUSH    PSW             ;
06F0 CD1A03             CALL    HOME            ;RESET DEVICE TO HOME
06F3 F1                 POP     PSW             ;
06F4 32FC0A             STA     STATUS          ;SAVE FOR ERROR MESSAGE

                CHKS4:
06F7 119400             LXI     D,TCNT          ;BUMP TEMP ERROR COUNT
06FA CD0F07             CALL    ADDERRORS       ;
06FD 21020B             LXI     H,T$RETRIES     ;PICKUP RETRY COUNT
0700 35                 DCR     M               ;DECREMENT COUNT OF RETRIES
0701 C0                 RNZ                     ;

0702 11A000             LXI     D,PCNT          ;BUMP PERMANENT ERROR COUNT
0705 CD0F07             CALL    ADDERRORS       ;

                BADIO:
0708 21F60A             LXI     H,ERFLAG        ;SET PERMANENT ERROR
070B 3601               MVI     M,001H          ;DO IT....
070D AF                 XRA     A               ;RESET TO PRECLUDE RETRIES
070E C9                 RET                     ;RETURN TO CALLER

                ADDERRORS:
```

*p.130*

```
070F 2AAC00             LHLD    DISKNO          ;BUMP COUNT OF DISK ERRORS
0712 2600               MVI     H,000H          ;
0714 19                 DAD     D               ;POINT TO ERROR REGISTER
0715 34                 INR     M               ;
0716 C9                 RET                     ;

                        PAGE

                ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
                ;
                ;
                ;       THIS IS HARD DISK WAIT ENTRY
                ;
                ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
                ;

                WAIT0:
0717 C5                 PUSH    B               ; SAVE RETRY COUNT
0718 0E84               MVI     C,FLAGWT        ; FUNCTION FLAG WAIT
071A 1E05               MVI     E,HDFLAG        ; DEVICE IS HARD DISK
071C CD100B             CALL    XDOS
071F C1                 POP     B               ; RESTORE RETRY COUNTER IN

                ;       READ OR WRITE IS OK, ACCUMULATOR CONTAINS ZERO

0720 C9                 RET


                ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
                ;
                ;       THE FOLLOWING CODE GUARANTEES THAT HARD DISK FLAG I
                ;       IT APPEARS THAT WE OCCASIONALLY GET FLAG SET AS A R
                ;       OF AN INTERRUPT FROM THE HARD DISK, WHEN WE DO
                ;       NOT EXPECT IT.
                ;
                ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

                INTFIX:
0721 F5                 PUSH    PSW
0722 C5                 PUSH    B
0723 D5                 PUSH    D
0724 E5                 PUSH    H

0725 0E85               MVI     C,FLAGST
0727 1E05               MVI     E,HDFLAG
0729 CD100B             CALL    XDOS                    ;EITHER FLAG 5 WILL BE SET
                ;                                       ;IT IS ALREADY SET - IN WHI
                ;                                       ;THIS REQUEST WILL BE IGNOR

072C 0E84               MVI     C,FLAGWT
072E 1E05               MVI     E,HDFLAG
0730 CD100B             CALL    XDOS                    ;NOW CLEAR THE FLAG

0733 E1                 POP     H
0734 D1                 POP     D
```

*p.131*

```
0735 C1                 POP     B
0736 F1                 POP     PSW                     ;RESTORE REGISTERS

0737 D323               OUT     023H                    ;ISSUE COMMAND TO HARD DISK

0739 C9                 RET

                        PAGE

                ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
                ;
                ;       THIS IS FLOPPY DISK WAIT ENTRY
                ;
                ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

                FPYWAIT:
073A C5                 PUSH    B       ;SAVE RETRY COUNT
073B E5                 PUSH    H
073C 0E84               MVI     C,FLAGWT                ; FUNCTION IS FLAG WAIT
073E 1E06               MVI     E,FPYFLAG               ; WAIT FOR FLOPPY
0740 CD100B             CALL    XDOS
0743 F5                 PUSH    PSW
0744 3AD00D             LDA     FPYTIME                 ;DID WD1791 GO TO SLEEP?
0747 B7                 ORA     A                       ;
                        JRNZ    NOFPYRST                ;IF STILL AWAKE, SKIP RESET
0748+2015               DB      020H,NOFPYRST-$-1       ;---- FAKE JRNZ INS

074A DB09               IN      009H                    ;GET CURRENT BANK NUMBER
074C E618               ANI     00011000B               ;REMOVE OTHER INFO
074E D309               OUT     009H                    ;RESET WD1791
0750 0E01               MVI     C,1                     ;DELAY 1 MILLISEC
0752 CD8207             CALL    DELAY                   ;
0755 F602               ORI     00000010B               ;END RESET
0757 D309               OUT     009H                    ;
0759 3AE60A             LDA     NEWDSK                  ;MAKE SURE CURRENT DISK AND
075C 32AC00             STA     DISKNO                  ; THE SAME
                NOFPYRST:
075F F1                 POP     PSW
0760 E1                 POP     H
0761 C1                 POP     B                       ;RESTORE RETRY COUNT IN <C>


0762 C9                 RET

                ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
                ;
                ;       THE FOLLOWING CODE GUARANTEES THAT FLOPPY DISK FLAG
                ;
                ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

                FINTFIX:
0763 F5                 PUSH    PSW
0764 C5                 PUSH    B
0765 D5                 PUSH    D
0766 E5                 PUSH    H
```

*p.132*

```
0767 0E85               MVI     C,FLAGST
0769 1E06               MVI     E,FPYFLAG
076B CD100B             CALL    XDOS

076E 0E84               MVI     C,FLAGWT
0770 1E06               MVI     E,FPYFLAG
0772 CD100B             CALL    XDOS

0775 210301             LXI     H,00103H                ;SET TIME OUT INDICATOR ON
0778 22D00D             SHLD    FPYTIME                 ; TIME TO BE BETWEEN 2 AND

077B E1                 POP     H
077C D1                 POP     D
077D C1                 POP     B
077E F1                 POP     PSW

077F D304               OUT     004H                    ;ISSUE COMMAND TO FLOPPY DI

0781 C9                 RET

                        if      not mpm20
                FPYTIME:
                        DW      0

                FPYTCNT:
                        DW      0
                        endif

                        PAGE

                ;-----------------------------------------------------------
                ;
                ;       THIS IS THE DELAY ROUTINE. IT WILL LOOP HERE FOR TH
                ;       NUMBER OF MILLISECONDS SPECIFIED IN REGISTER C.
                ;
                ;-----------------------------------------------------------

                DELAY:
0782 0664       DEL1:   MVI     B,100                   ;FORCE DELAY FOR 1 MILLISEC
0784 00         DEL2:   NOP                             ;INSTRUCTIONS TO FILL IN TI
0785 29                 DAD     H                       ;
0786 29                 DAD     H                       ;
0787 05                 DCR     B                       ;AT ONE MILLISECOND YET ??
0788 C28407             JNZ     DEL2                    ;NO, KEEP ON LOOPING
078B 0D                 DCR     C                       ;END OF REQUESTED INTERVAL
078C C28207             JNZ     DEL1                    ;NO, KEEP ON
078F C9                 RET                             ;RETURN TO CALLER


                ;********************************************
                ;*  NOTE: THE INITIALIZATION CODE WILL BE
                ;*     OVERWRITTEN BY DIRBUF & FPYBUF
                ;********************************************
```

*p.133*

```
                        if      not mpm20
                DIRBUF  EQU     $
                        endif

                ;-----------------------------------------------------------
                ;
                ;       DISK CONFIGURATION TABLE
                ;
                ;-----------------------------------------------------------

                        IF      HARDSK
                ;                                                       PIN C

0790 0000000000DSCN0:   DB      00H,00H,00H,00H,00H,00H,00H,00H
0798 1000000000         DB      10H,00H,00H,00H,00H,00H,10H,00H         ;
07A0 9090900000         DB      90H,90H,90H,00H,00H,00H,00H,00H         ;
07A8 0000000000         DB      00H,00H,00H,00H,00H,00H,00H,00H
07B0 1000002000         DB      10H,00H,00H,20H,00H,00H,10H,20H         ;
07B8 0000000000         DB      00H,00H,00H,00H,00H,00H,00H,00H
07C0 9090902000         DB      90H,90H,90H,20H,00H,00H,00H,20H         ;
07C8 909090A0A0         DB      90H,90H,90H,0A0H,0A0H,0A0H,0H,0H        ;
                        ENDIF
                ;-----------------------------------------------------------
                ;
                ;       SET UP DISK CONFIGURATON
                ;
                ;       [ THIS CODE EXECUTED ONLY ONCE ]
                ;
                ;-----------------------------------------------------------
                ;
07D0 217E00     SDCONF: LXI     H,SEL0+2        ;POINT TO DRIVE C:
07D3 3AB600             LDA     MPARMS          ;
07D6 E605               ANI     05H             ; TEST FOR FOUR FLOPPIES
07D8 C3DE07             JMP     SDDBL           ;  YES   SKIP THE ZAP
07DB 77                 MOV     M,A             ;
07DC 23                 INX     H               ; ZAP C: AND  D:
07DD 77                 MOV     M,A             ;
                SDDBL:
07DE 118000             LXI     D,SEL0+4        ;POINT TO DRIVE E:
                        IF      HARDSK
07E1 DB25               IN      025H            ;READ CONFIGURATION PORT
07E3 E607               ANI     07H             ;STRIP OFF HIGH PART
07E5 17                 RAL                     ;
07E6 17                 RAL                     ;
07E7 17                 RAL                     ;
07E8 0600               MVI     B,0             ;
07EA 4F                 MOV     C,A             ;POINT TO CONFIGURATION TAB
07EB 219007             LXI     H,DSCN0         ;
07EE 09                 DAD     B               ;  INDEX TO RIGHT ENTRY
07EF 0608               MVI     B,8             ;
07F1 7E         SDL1:   MOV     A,M             ; CHANGE ALL SELECT MASKS
07F2 12                 STAX    D               ;
07F3 13         SDOK:   INX     D               ; NEXT
```

*p.134*

```
07F4 23                 INX     H               ;  DRIVE
                        DJNZ    SDL1            ;
07F5+10FA               DB      010H,SDL1-$-1   ;---- FAKE DJNZ INSTRUCTION
                        ENDIF
                        IF      NOT HARDSK
                        XCHG                    ;
                        MVI     B,8             ;
                        XRA     A               ;
                SDL2:   MOV     M,A             ; ZAP ALL HARD DRIVES
                        INX     H               ;
                        DJNZ    SDL2            ;
                        ENDIF                   ;

07F7 C9                 RET

07F8 =          INITEND EQU     $

07F8 E5         XETMOD: PUSH    H               ;SAVE MODE BYTE ADDRESS
07F9 79                 MOV     A,C             ;SETUP FOR DENSITY CHANGE
07FA B7                 ORA     A               ;
07FB 0E00               MVI     C,000H          ;ASSUME SINGLE DENSITY MODE
                        JRZ     XETSEL          ;VERIFY ASSUMPTION
07FD+2802               DB      028H,XETSEL-$-1 ;---- FAKE JRZ INSTRUCTION
07FF 0E01               MVI     C,001H          ;SET FOR DOUBLE DENSITY MOD
0801 CD7802     XETSEL: CALL    SETDEN          ;SET DENSITY BASED ON LOW B
0804 E1                 POP     H               ;RESTORE
0805 6E                 MOV     L,M             ;PICKUP MODE AGAIN
0806 2600               MVI     H,000H          ;FOR SINGLE BYTE PRECISION
0808 7D                 MOV     A,L             ;SAVE MODE IN ACCUMULATOR F
0809 29                 DAD     H               ;* 2
080A 29                 DAD     H               ;* 4
080B E5                 PUSH    H               ;SAVE * 4
080C 29                 DAD     H               ;* 8
080D D1                 POP     D               ;REGAIN * 4
080E 19                 DAD     D               ;* 12
080F 119101             LXI     D,MODL0         ;FIRST MODEL DPE
0812 19                 DAD     D               ;POINT TO THIS ONE
0813 EB                 XCHG                    ;SETUP TEMPORARILY AS DESTI
0814 2AB200             LHLD    DPEPTR          ;ADDRESS OF CURRENTLY SELEC
0817 EB                 XCHG                    ;SETUP TO ALTER
0818 010C00             LXI     B,12            ;LENGTH FOR MOVE
                        LDIR                    ;DO MOVE
081B+EDB0               DB      0EDH,0B0H       ;---- FAKE LDIR INSTRUCTION
081D C9                 RET                     ;RETURN TO CALLER


                        PAGE

                ;-----------------------------------------------------------
                ;
                ;       THE FOLLOWING AREA CONTAINS THE DISK/WORK SAVE AREA
                ;       USED BY THE CBIOS IN THE NORMAL COURSE OF ACTIVITY.
                ;
                ;-----------------------------------------------------------
```

*p.135*

```
                        if      mpm20
                ;tempbuf        equ     (dirbuf-base)+128
                        else
                TEMPBUF EQU     (DIRBUF-BASE)+256
                        ORG TEMPBUF+((INITEND-BASE)/TEMPBUF)*((INITEND-BASE
                        endif

081E =          BEGDAT  EQU     $                               ;START OF BDOS AREA
                ;DIRBUF:         DS      128     ;OVERLAYS SYSTEMINIT CODE
081E            ALV0:   DS      32
083E            CSV0:   DS      32
085E            ALV1:   DS      32
087E            CSV1:   DS      32
089E            ALV2:   DS      32
08BE            CSV2:   DS      32
08DE            ALV3:   DS      32
08FE            CSV3:   DS      32
                        IF      HARDSK
091E            ALV4:   DS      64
095E            CSV4:   DS      0
095E            ALV5:   DS      64
099E            CSV5:   DS      0
099E            ALV6:   DS      64
09DE            CSV6:   DS      0
09DE            ALV7:   DS      64
0A1E            CSV7:   DS      0
0A1E            ALV8:   DS      64
0A5E            CSV8:   DS      0
0A5E            ALV9:   DS      64
0A9E            CSV9:   DS      0
0A9E            ALVA:   DS      36
0AC2            CSVA:   DS      0
0AC2            ALVB:   DS      36
0AE6            CSVB:   DS      0
                        endif

                        if      mdisk
                ALVC:   DS      32                              ;VIRTUAL DISK
                CSVC:   DS      0
                        endif

                        if      not mpm20
                        if      hardsk
                        DS      1                               ;MUST PRECEDE HSTBU
                HSTBUF: DS      1024                            ;HOST BUFFER AREA
                        DS      1                               ;MUST FOLLOW HSTBUF
                        ENDIF

                FPYBUF  EQU     DIRBUF+128                      ; FLOPPY I/O BUFFER
                        endif

0AE6            NEWDSK: DS      1                               ;SEEK DISK NUMBER
0AE7            NEWTRK: DS      2                               ;SEEK TRACK NUMBER
0AE9            NEWSEC: DS      1                               ;SEEK SECTOR NUMBER
```

*p.136*

```
0AEA            HSTDSK: DS      1                               ;HOST DISK NUMBER
0AEB            HSTTRK: DS      2                               ;HOST TRACK NUMBER
0AED            HSTSEC: DS      1                               ;HOST SECTOR NUMBER

0AEE            NEWHST: DS      1                               ;SEEK SHR SECSHF
0AEF            HSTACT: DS      1                               ;HOST ACTIVE FLAG
0AF0            HSTWRT: DS      1                               ;HOST WRITTEN FLAG

0AF1            UNACNT: DS      1                               ;UNALLOCATED RECORD
0AF2            UNADSK: DS      1                               ;LAST UNALLOCATED D
0AF3            UNATRK: DS      2                               ;LAST UNALLOCATED T
0AF5            UNASEC: DS      1                               ;LAST UNALLOCATED S

0AF6            ERFLAG: DS      1                               ;ERROR REPORTING
0AF7            RSFLAG: DS      1                               ;READ SECTOR FLAG
0AF8            READOP: DS      1                               ;1 IF READ OPERATIO
0AF9            WRTYPE: DS      1                               ;WRITE OPERATION TY

0AFA 00         CMD:    DB      0                               ;COMMANDS FOR NEXT
0AFB 00         MASK:   DB      0                               ;STATUS MASKS BUFFE
0AFC 00         STATUS: DB      0                               ;STATUS SAVE LOCATI

0AFD 00000000   SAVE1:  DB      000H,000H,000H,000H             ;SAVE AREA FOR NMI
0B01 00         P$RETRIES: DB   000H                            ;COUNTER FOR PERMAN
0B02 00         T$RETRIES: DB   000H                            ;COUNTER FOR TEMPOR
                HOME$TOGGLE:
0B03 00                 DB      000H                            ;INDICATOR TO TELL
                ;                                               ;.. IF HOME SHOULD


                        page

                        if      mpm20

                ; *********************************************************
                ; *
                ; *             M P / M   2 . 0   C O M M O N   B A S E
                ; *
                ; *********************************************************

                commonbase:
0B04 C3150B             jmp     coldstart
0B07 C30000     swtuser: jmp    $-$
0B0A C30000     swtsys: jmp     $-$
0B0D C30000     pdisp:  jmp     $-$
0B10 C30000     xdos:   jmp     $-$
0B13 0000       sysdat: dw      $-$
                COLDSTART:
                WARMSTART:
0B15 0E00               MVI     C,0                     ; SEE SYSTEM INIT
                                                        ; COLD & WARM START INCLUDE
                                                        ; FOR COMPATIBILITY WITH CP
0B17 C3100B             JMP     XDOS                    ; SYSTEM RESET, TERMINATE P
```

*p.137*

```
                rtnempty:
0B1A AF                 xra     a
0B1B C9                 ret

                NULL$INT:
0B1C FB                 EI
                        RETI
0B1D+ED4D               DB      0EDH,04DH       ;---- FAKE RETI INSTRUCTION
                        endif


                ;-----------------------------------------------------------
                ;
                ;       CENTRONICS PRINTER ROUTINE (WITH SEPARATE BUSY TEST
                ;
                ;-----------------------------------------------------------

                CNSTAT:
0B1F 3E01               MVI     A,001H          ;TO SET STROBE HIGH
0B21 D310               OUT     010H            ;
0B23 DB10               IN      010H            ;READ PRINTER STATUS
0B25 E620               ANI     020H            ;REMOVE ALL BUT BUSY BIT
0B27 3EFF               MVI     A,0FFH          ;ASSUME NOT BUSY
0B29 C8                 RZ                      ;CHECK ASSUMPTION
0B2A AF                 XRA     A               ;SET TO SHOW STILL BUSY
0B2B C9                 RET                     ;
                ;
                CLIST:
0B2C CD1F0B             CALL    CNSTAT          ;IS PRINTER READY NOW?
0B2F B7                 ORA     A
                        JRNZ    CLIST1          ;IF READY, SKIP POLL
0B30+2009               DB      020H,CLIST1-$-1 ;---- FAKE JRNZ INSTRUCTION

0B32 C5                 PUSH    B               ;
0B33 0E83               MVI     C,POLL          ; POLL DEVICE
0B35 1E00               MVI     E,PLLPT         ;  PRINTER
0B37 CD100B             CALL    XDOS            ;WAIT FOR PRINTER TO FREE U
0B3A C1                 POP     B               ;

                CLIST1:
0B3B 79                 MOV     A,C             ;CHARACTER TO PRINT
0B3C D311               OUT     011H            ;WRITE IT TO DATA PORT
0B3E 3E00               MVI     A,000H          ;TO FORCE STROBE LOW
0B40 D310               OUT     010H            ;
0B42 3E01               MVI     A,001H          ;TO FORCE STROBE HIGH
0B44 D310               OUT     010H            ;
0B46 C9                 RET                     ;

                        PAGE

                ;-----------------------------------------------------------
                ;
                ;       DISK INTERRUPT ROUTINE
                ;
                ;-----------------------------------------------------------
```

*p.138*

```
                FLOPPY$INT:
0B47 22C80D             SHLD    SVDHL
0B4A 21500B             LXI     H,FDINTH
0B4D C37F0D             JMP     INTINIT
                FDINTH:
0B50 DB04               IN      004H            ;GET STATUS
0B52 32FC0A             STA     STATUS          ;SAVE FOR I/O ROUTINE
0B55 3E00               MVI     A,0             ;STOP TIMING OF RESPONSE TO
0B57 32D10D             STA     FPYTIME+1       ;
0B5A 1E06               MVI     E,FPYFLAG       ;SHOW I/O COMPLETED
                        JR      HDSTFLG
0B5C+1813               DB      018H,HDSTFLG-$-1        ;---- FAKE JR INSTR

                HARD$INT:
0B5E 22C80D             SHLD    SVDHL
0B61 21670B             LXI     H,HDINTH
0B64 C37F0D             JMP     INTINIT
                HDINTH:
0B67 DB24               IN      024H            ;GET STATUS
0B69 32FC0A             STA     STATUS          ;SAVE FOR CHECK LATER

0B6C AF                 XRA     A
0B6D D323               OUT     023H            ;RESET INTERRUPT BY RELOADI

0B6F 1E05               MVI     E,HDFLAG        ;SHOW I/O COMPLETED
                HDSTFLG:
0B71 0E85               MVI     C,FLAGST
0B73 CD100B             CALL    XDOS
0B76 C3670D             JMP     INTDONE

                        PAGE

                ;-----------------------------------------------------------
                ;
                ;       CONSOLE DISPLAY ROUTINES
                ;
                ;-----------------------------------------------------------

                ;
                CONST:                  ; CONSOLE STATUS
0B79 CD9A0B             CALL    PTBLJMP ; COMPUTE AND JUMP TO HNDLR
0B7C AD0B               DW      PT0ST   ; CONSOLE #0 STATUS ROUTINE
0B7E EC0B               DW      PT1ST   ; CONSOLE #1 STATUS ROUTINE
0B80 2B0C               DW      PT2ST   ; CONSOLE #2 STATUS ROUTINE
0B82 6A0C               DW      PT3ST   ; CONSOLE #3 STATUS ROUTINE

                CONIN:                  ; CONSOLE INPUT
0B84 CD9A0B             CALL    PTBLJMP ; COMPUTE AND JUMP TO HNDLR
0B87 B80B               DW      PT0IN   ; CONSOLE #0 INPUT
0B89 F70B               DW      PT1IN   ; CONSOLE #1 INPUT
0B8B 360C               DW      PT2IN   ; CONSOLE #2 INPUT
0B8D 750C               DW      PT3IN   ; CONSOLE #3 INPUT

                CONOUT:                 ; CONSOLE OUTPUT
```

*p.139*

```
0B8F CD9A0B             CALL    PTBLJMP ; COMPUTE AND JUMP TO HNDLR
0B92 CA0B               DW      PT0OUT  ; CONSOLE #0 OUTPUT
0B94 090C               DW      PT1OUT  ; CONSOLE #1 OUTPUT
0B96 480C               DW      PT2OUT  ; CONSOLE #2 OUTPUT
0B98 870C               DW      PT3OUT  ; CONSOLE #3 OUTPUT

                ;
                PTBLJMP:                ; COMPUTE AND JUMP TO HANDLER
                                        ; D = CONSOLE #
                                        ; DO NOT DESTROY <D>
0B9A 7A                 MOV     A,D
0B9B FE04               CPI     NMBCNS
                        JRC     TBLJMP
0B9D+3803               DB      038H,TBLJMP-$-1 ;---- FAKE JRC INSTRUCTIO
0B9F F1                 POP     PSW     ; THROW AWAY TABLE ADDRESS
0BA0 AF                 XRA     A
0BA1 C9                 RET
                TBLJMP:                 ; COMPUTE AND JUMP TO HANDLER
                                        ; A = TABLE INDEX
0BA2 87                 ADD     A       ; DOUBLE TABLE INDEX FOR ADR OFFST
0BA3 E1                 POP     H       ; RETURN ADR POINTS TO JUMP TBL
0BA4 5F                 MOV     E,A
0BA5 1600               MVI     D,0
0BA7 19                 DAD     D       ; ADD TABLE INDEX * 2 TO TBL BASE
0BA8 5E                 MOV     E,M     ; GET HANDLER ADDRESS
0BA9 23                 INX     H
0BAA 56                 MOV     D,M
0BAB EB                 XCHG
0BAC E9                 PCHL            ; JUMP TO COMPUTED CNS HANDLER

                        PAGE

                ;-----------------------------------------------------------
                ;
                ;       SERIAL PORT ADDRESS EQUATES
                ;
                ;-----------------------------------------------------------

001C =          DATA0   EQU     01CH            ;CONSOLE #0 DATA
001D =          STS0    EQU     DATA0+1         ;CONSOLE #0 STATUS
002C =          DATA1   EQU     02CH            ;CONSOLE #1 DATA
002D =          STS1    EQU     DATA1+1         ;CONSOLE #1 STATUS
002E =          DATA2   EQU     02EH            ;CONSOLE #2 DATA
002F =          STS2    EQU     DATA2+1         ;CONSOLE #2 STATUS
002A =          DATA3   EQU     02AH            ;CONSOLE #3 DATA
002B =          STS3    EQU     DATA3+1         ;CONSOLE #3 STATUS
001E =          LPTPRT0 EQU     01EH            ;PRINTER #0 DATA
001F =          LPTSTS0 EQU     LPTPRT0+1       ;PRINTER #0 STATUS
0028 =          LPTPRT1 EQU     028H            ;PRINTER #1 DATA
0029 =          LPTSTS1 EQU     LPTPRT1+1       ;PRINTER #1 STATUS

                        PAGE
```

*p.140*

```
                ;-----------------------------------------------------------
                ;
                ;       POLL CONSOLE  # 0  INPUT
                ;
                ;-----------------------------------------------------------

                POLCI0:
                PT0ST:                                  ; TEST CONSOLE STATUS
0BAD AF                 XRA     A               ;  RETURN  0FFH IF READY
0BAE D31D               OUT     STS0            ;          000H IF NOT
0BB0 DB1D               IN      STS0            ;
0BB2 E601               ANI     1               ;  RX CHAR ?
0BB4 C8                 RZ                      ;   NO
0BB5 3EFF               MVI     A,0FFH          ;   YES  -  SET FLAG
0BB7 C9                 RET                     ;
                ;
                ;-----------------------------------------------------------
                ;
                ;       CONSOLE  # 0  INPUT
                ;
                ;-----------------------------------------------------------
                ;
                PT0IN:                                  ; RETURN CHAR IN REG A
0BB8 CDAD0B             CALL    POLCI0          ;IS IT READY NOW?
0BBB B7                 ORA     A               ;
                        JRNZ    PT0IN1          ;IF READY, SKIP POLL
0BBC+2007               DB      020H,PT0IN1-$-1 ;---- FAKE JRNZ INSTRUCTION
0BBE 0E83               MVI     C,POLL          ;
0BC0 1E05               MVI     E,PLCI0         ; POLL CONSOLE #0 INPUT
0BC2 CD100B             CALL    XDOS            ;
0BC5 DB1C       PT0IN1: IN      DATA0           ; READ CHARACTER
0BC7 E67F               ANI     7FH             ; STRIP PARITY
0BC9 C9                 RET                     ;
                ;
                ;
                ;-----------------------------------------------------------
                ;
                ;       CONSOLE  # 0  OUTPUT
                ;
                ;-----------------------------------------------------------
                ;
                PT0OUT:                                 ; REG C = CHAR TO OUTPUT
0BCA CDDD0B             CALL    POLCO0          ;IS IT READY NOW?
0BCD B7                 ORA     A               ;
                        JRNZ    PT0OUT1         ;IF READY, SKIP POLL
0BCE+2009               DB      020H,PT0OUT1-$-1        ;---- FAKE JRNZ INS
0BD0 C5                 PUSH    B               ;
0BD1 0E83               MVI     C,POLL          ;
0BD3 1E01               MVI     E,PLCO0         ;
0BD5 CD100B             CALL    XDOS            ; POLL CONSOLE #0 OUTPUT
0BD8 C1                 POP     B               ;
                PT0OUT1:
0BD9 79                 MOV     A,C             ;
0BDA D31C               OUT     DATA0           ; TRANSMIT CHARACTER
```

*p.141*

```
0BDC C9                 RET                     ;
                ;
                ;
                ;-----------------------------------------------------------
                ;
                ;       POLL CONSOLE  # 0  OUTPUT
                ;
                ;-----------------------------------------------------------
                ;
                POLCO0:                                 ; RETURN 0FFH IF READY
0BDD 3E10               MVI     A,10H           ;          000H IF NOT
0BDF D31D               OUT     STS0            ; RESET INT BIT
0BE1 DB1D               IN      STS0            ; READ STATUS
0BE3 E60C               ANI     0CH             ; MASK FOR DTR AND TXE
0BE5 FE0C               CPI     0CH             ; MUST HAVE BOTH
0BE7 3E00               MVI     A,0             ;
0BE9 C0                 RNZ                     ; RETURN NOT READY
0BEA 3D                 DCR     A               ;CHANGE "A" TO 0FFH
0BEB C9                 RET                     ; RETURN READY

                        PAGE


                ;-----------------------------------------------------------
                ;
                ;       POLL CONSOLE  # 1  INPUT
                ;
                ;-----------------------------------------------------------

                POLCI1:
                PT1ST:                                  ; TEST CONSOLE STATUS
0BEC AF                 XRA     A               ;  RETURN  0FFH IF READY
0BED D32D               OUT     STS1            ;          000H IF NOT
0BEF DB2D               IN      STS1            ;
0BF1 E601               ANI     1               ;  RX CHAR ?
0BF3 C8                 RZ                      ;   NO
0BF4 3EFF               MVI     A,0FFH          ;   YES  -  SET FLAG
0BF6 C9                 RET                     ;
                ;
                ;-----------------------------------------------------------
                ;
                ;       CONSOLE  # 1  INPUT
                ;
                ;-----------------------------------------------------------
                ;
                PT1IN:                                  ; RETURN CHAR IN REG A
0BF7 CDEC0B             CALL    POLCI1          ;READY NOW?
0BFA B7                 ORA     A               ;
                        JRNZ    PT1IN1          ;IF READY, SKIP POLL
0BFB+2007               DB      020H,PT1IN1-$-1 ;---- FAKE JRNZ INSTRUCTION
0BFD 0E83               MVI     C,POLL          ;
0BFF 1E06               MVI     E,PLCI1         ; POLL CONSOLE #1 INPUT
0C01 CD100B             CALL    XDOS            ;
0C04 DB2C       PT1IN1: IN      DATA1           ; READ CHARACTER
0C06 E67F               ANI     7FH             ; STRIP PARITY
```

*p.142*

```
0C08 C9                 RET                     ;
                ;
                ;
                ;-----------------------------------------------------------
                ;
                ;       CONSOLE  # 1  OUTPUT
                ;
                ;-----------------------------------------------------------
                ;
                PT1OUT:                                 ; REG C = CHAR TO OUTPUT
0C09 CD1C0C             CALL    POLCO1          ;ARE WE READY NOW?
0C0C B7                 ORA     A               ;
                        JRNZ    PT1OUT1         ;IF READY, SKIP POLL
0C0D+2009               DB      020H,PT1OUT1-$-1        ;---- FAKE JRNZ INS
0C0F C5                 PUSH    B               ;
0C10 0E83               MVI     C,POLL          ;
0C12 1E02               MVI     E,PLCO1         ;
0C14 CD100B             CALL    XDOS            ; POLL CONSOLE #1 OUTPUT
0C17 C1                 POP     B               ;
                PT1OUT1:
0C18 79                 MOV     A,C             ;
0C19 D32C               OUT     DATA1           ; TRANSMIT CHARACTER
0C1B C9                 RET                     ;
                ;
                ;
                ;-----------------------------------------------------------
                ;
                ;       POLL CONSOLE  # 1  OUTPUT
                ;
                ;-----------------------------------------------------------
                ;
                POLCO1:                                 ; RETURN 0FFH IF READY
0C1C 3E10               MVI     A,10H           ;          000H IF NOT
0C1E D32D               OUT     STS1            ; RESET INT BIT
0C20 DB2D               IN      STS1            ; READ STATUS
0C22 E60C               ANI     0CH             ; MASK FOR DTR AND TXE
0C24 FE0C               CPI     0CH             ; MUST HAVE BOTH
0C26 3E00               MVI     A,0             ;
0C28 C0                 RNZ                     ; RETURN NOT READY
0C29 3D                 DCR     A               ;CHANGE "A" TO 0FFH
0C2A C9                 RET                     ; RETURN READY

                        PAGE


                ;-----------------------------------------------------------
                ;
                ;       POLL CONSOLE  # 2  INPUT
                ;
                ;-----------------------------------------------------------

                POLCI2:
                PT2ST:                                  ; TEST CONSOLE STATUS
0C2B AF                 XRA     A               ;  RETURN  0FFH IF READY
```

*p.143*

```
0C2C D32F               OUT     STS2            ;          000H IF NOT
0C2E DB2F               IN      STS2            ;
0C30 E601               ANI     1               ;  RX CHAR ?
0C32 C8                 RZ                      ;   NO
0C33 3EFF               MVI     A,0FFH          ;   YES  -  SET FLAG
0C35 C9                 RET                     ;
                ;
                ;-----------------------------------------------------------
                ;
                ;       CONSOLE  # 2  INPUT
                ;
                ;-----------------------------------------------------------
                ;
                PT2IN:                                  ; RETURN CHAR IN REG A
0C36 CD2B0C             CALL    POLCI2          ;READY NOW?
0C39 B7                 ORA     A               ;
                        JRNZ    PT2IN1          ;IF READY, SKIP POLL
0C3A+2007               DB      020H,PT2IN1-$-1 ;---- FAKE JRNZ INSTRUCTION
0C3C 0E83               MVI     C,POLL          ;
0C3E 1E07               MVI     E,PLCI2         ; POLL CONSOLE #2 INPUT
0C40 CD100B             CALL    XDOS            ;
0C43 DB2E       PT2IN1: IN      DATA2           ; READ CHARACTER
0C45 E67F               ANI     7FH             ; STRIP PARITY
0C47 C9                 RET                     ;
                ;
                ;
                ;-----------------------------------------------------------
                ;
                ;       CONSOLE  # 2  OUTPUT
                ;
                ;-----------------------------------------------------------
                ;
                PT2OUT:                                 ; REG C = CHAR TO OUTPUT
0C48 CD5B0C             CALL    POLCO2          ;READY NOW?
0C4B B7                 ORA     A               ;
                        JRNZ    PT2OUT1         ;IF READY, SKIP POLL
0C4C+2009               DB      020H,PT2OUT1-$-1        ;---- FAKE JRNZ INS
0C4E C5                 PUSH    B               ;
0C4F 0E83               MVI     C,POLL          ;
0C51 1E03               MVI     E,PLCO2         ;
0C53 CD100B             CALL    XDOS            ; POLL CONSOLE #2 OUTPUT
0C56 C1                 POP     B               ;
                PT2OUT1:
0C57 79                 MOV     A,C             ;
0C58 D32E               OUT     DATA2           ; TRANSMIT CHARACTER
0C5A C9                 RET                     ;
                ;
                ;
                ;-----------------------------------------------------------
                ;
                ;       POLL CONSOLE  # 2  OUTPUT
                ;
                ;-----------------------------------------------------------
                ;
                POLCO2:                                 ; RETURN 0FFH IF READY
```

*p.144*

```
0C5B 3E10               MVI     A,10H           ;          000H IF NOT
0C5D D32F               OUT     STS2            ; RESET INT BIT
0C5F DB2F               IN      STS2            ; READ STATUS
0C61 E60C               ANI     0CH             ; MASK FOR DTR AND TXE
0C63 FE0C               CPI     0CH             ; MUST HAVE BOTH
0C65 3E00               MVI     A,0             ;
0C67 C0                 RNZ                     ; RETURN NOT READY
0C68 3D                 DCR     A               ;CHANGE "A" TO 0FFH
0C69 C9                 RET                     ; RETURN READY

                        PAGE


                ;-----------------------------------------------------------
                ;
                ;       POLL CONSOLE  # 3  INPUT
                ;
                ;-----------------------------------------------------------

                POLCI3:
                PT3ST:                                  ; TEST CONSOLE STATUS
0C6A AF                 XRA     A               ;  RETURN  0FFH IF READY
0C6B D32B               OUT     STS3            ;          000H IF NOT
0C6D DB2B               IN      STS3            ;
0C6F E601               ANI     1               ;  RX CHAR ?
0C71 C8                 RZ                      ;   NO
0C72 3EFF               MVI     A,0FFH          ;   YES  -  SET FLAG
0C74 C9                 RET                     ;
                ;
                ;-----------------------------------------------------------
                ;
                ;       CONSOLE  # 3  INPUT
                ;
                ;-----------------------------------------------------------
                ;
                PT3IN:                                  ; RETURN CHAR IN REG A
0C75 CD6A0C             CALL    POLCI3          ;READY NOW?
0C78 B7                 ORA     A               ;
                        JRNZ    PT3IN1          ;IF READY, SKIP POLL
0C79+2007               DB      020H,PT3IN1-$-1 ;---- FAKE JRNZ INSTRUCTION
0C7B 0E83               MVI     C,POLL          ;
0C7D 1E08               MVI     E,PLCI3         ; POLL CONSOLE #3 INPUT
0C7F CD100B             CALL    XDOS            ;
0C82 DB2A       PT3IN1: IN      DATA3           ; READ CHARACTER
0C84 E67F               ANI     7FH             ; STRIP PARITY
0C86 C9                 RET                     ;
                ;
                ;
                ;-----------------------------------------------------------
                ;
                ;       CONSOLE  # 3  OUTPUT
                ;
                ;-----------------------------------------------------------
                ;
```

*p.145*

```
                PT3OUT:                                 ; REG C = CHAR TO OUTPUT
0C87 CD9A0C             CALL    POLCO3          ;READY NOW?
0C8A B7                 ORA     A               ;
                        JRNZ    PT3OUT1         ;IF READY, SKIP POLL
0C8B+2009               DB      020H,PT3OUT1-$-1        ;---- FAKE JRNZ INS
0C8D C5                 PUSH    B               ;
0C8E 0E83               MVI     C,POLL          ;
0C90 1E04               MVI     E,PLCO3         ;
0C92 CD100B             CALL    XDOS            ; POLL CONSOLE #3 OUTPUT
0C95 C1                 POP     B               ;
                PT3OUT1:
0C96 79                 MOV     A,C             ;
0C97 D32A               OUT     DATA3           ; TRANSMIT CHARACTER
0C99 C9                 RET                     ;
                ;
                ;
                ;-----------------------------------------------------------
                ;
                ;       POLL CONSOLE  # 3  OUTPUT
                ;
                ;-----------------------------------------------------------
                ;
                POLCO3:                                 ; RETURN 0FFH IF READY
0C9A 3E10               MVI     A,10H           ;          000H IF NOT
0C9C D32B               OUT     STS3            ; RESET INT BIT
0C9E DB2B               IN      STS3            ; READ STATUS
0CA0 E60C               ANI     0CH             ; MASK FOR DTR AND TXE
0CA2 FE0C               CPI     0CH             ; MUST HAVE BOTH
0CA4 3E00               MVI     A,0             ;
0CA6 C0                 RNZ                     ; RETURN NOT READY
0CA7 3D                 DCR     A               ;CHANGE "A" TO 0FFH
0CA8 C9                 RET                     ; RETURN READY

                        PAGE



                ;-----------------------------------------------------------
                ;
                ;       LINE PRINTER  #0  DRIVER
                ;
                ;-----------------------------------------------------------
                ;
                LIST:                                   ;LIST OUTPUT #0
0CA9 CDBC0C             CALL    POLLPT
0CAC B7                 ORA     A               ;IS PRINTER READY NOW?
                        JRNZ    LIST1           ;IF READY, SKIP POLL
0CAD+2009               DB      020H,LIST1-$-1  ;---- FAKE JRNZ INSTRUCTION

0CAF C5                 PUSH    B
0CB0 0E83               MVI     C,POLL          ; POLL PRINTER STATUS
0CB2 1E00               MVI     E,PLLPT         ;
0CB4 CD100B             CALL    XDOS            ;
0CB7 C1                 POP     B               ;
```

*p.146*

```
                LIST1:
0CB8 79                 MOV     A,C             ; CHARACTER TO PRINT
0CB9 D31E               OUT     LPTPRT0         ;
0CBB C9                 RET                     ;

                ;
                ;-----------------------------------------------------------
                ;
                ;       POLL PRINTER OUTPUT
                ;
                ;-----------------------------------------------------------
                ;
                POLLPT:                                 ; RETURN 0FFH IF READY
0CBC 3E10               MVI     A,10H           ;          000H IF NOT
0CBE D31F               OUT     LPTSTS0         ; RESET INT BIT
0CC0 DB1F               IN      LPTSTS0         ; READ STATUS
0CC2 E60C               ANI     0CH             ; MASK FOR DTR AND TXE
0CC4 FE0C               CPI     0CH             ; MUST HAVE BOTH
0CC6 3E00               MVI     A,0             ;
0CC8 C0                 RNZ                     ; RETURN NOT READY
0CC9 3D                 DCR     A               ;CHANGE "A" TO 0FFH
0CCA C9                 RET                     ; RETURN READY
                ;
                        PAGE

                ;
                ;  MP/M 1.0   EXTENDED I/O SYSTEM
                ;
                ;

                POLLDEVICE:
                                                ; REG C = DEVICE # TO BE POLLED
                                                ; RETURN 0FFH IF READY,
                                                ;        000H IF NOT
0CCB 79                 MOV     A,C
0CCC FE09               CPI     NMBDEV
                        JRC     DEVOK
0CCE+3802               DB      038H,DEVOK-$-1  ;---- FAKE JRC INSTRUCTION
0CD0 3E09               MVI     A,NMBDEV; IF DEV # >= NMBDEV,
                                        ; SET TO NMBDEV
                DEVOK:
0CD2 CDA20B             CALL    TBLJMP  ; JUMP TO DEV POLL CODE

                DEVTBL:
0CD5 BC0C               DW      POLLPT  ; POLL PRINTER OUTPUT - THIS WILL P
                ;                       ;  SPECIFIED PARALLEL PORT FOR PRIN
0CD7 DD0B               DW      POLCO0  ; POLL CONSOLE #0 OUTPUT
0CD9 1C0C               DW      POLCO1  ; POLL CONSOLE #1 OUTPUT
0CDB 5B0C               DW      POLCO2  ; POLL CONSOLE #2 OUTPUT
0CDD 9A0C               DW      POLCO3  ; POLL CONSOLE #3 OUTPUT
0CDF AD0B               DW      POLCI0  ; POLL CONSOLE #0 INPUT
0CE1 EC0B               DW      POLCI1  ; POLL CONSOLE #1 INPUT
0CE3 2B0C               DW      POLCI2  ; POLL CONSOLE #2 INPUT
0CE5 6A0C               DW      POLCI3  ; POLL CONSOLE #3 INPUT
0009 =          NMBDEV  EQU     ($-DEVTBL)/2
```

*p.147*

```
0CE7 1A0B               DW      RTNEMPTY; BAD DEVICE HANDLER

                        PAGE

                ; SELECT / PROTECT MEMORY

                SELMEMORY:
                                                ; REG BC = ADR OF MEM DESCRIPTOR
                                                ; BC ->  BASE   1 BYTE,
                                                ;        SIZE   1 BYTE,
                                                ;        ATTRIB 1 BYTE,
                                                ;        BANK   1 BYTE.
                                                ;
                                                ;   BIOS TABLE MODIFIED
0CE9 FE20               CPI     20H             ;
0CEB CAEB0C             JZ      $
0CEE 210300             LXI     H,3             ; POINT TO BANK
0CF1 09                 DAD     B               ;
0CF2 7E                 MOV     A,M             ;  GET IT
0CF3 32030D             STA     BANKNO          ; SAVE BANK NUMBER
0CF6 17                 RAL                     ;
0CF7 17                 RAL                     ;
0CF8 17                 RAL                     ;
0CF9 E618               ANI     018H            ; MASK FOR PIO
0CFB F602               ORI     MEMSK           ;
0CFD 32040D             STA     CURMEM          ; STORE CURRENT BANK MASK
0D00 D309               OUT     009H            ; SET PIO
0D02 C9                 RET

0D03 00         BANKNO: DB      0               ; LAST SELECTED MEMORY BANK NUMBER
0D04 00         CURMEM: DB      0               ; LAST SELECTED MEMORY BANK MASK

                ; START CLOCK

                STARTCLOCK:
                                                ; WILL CAUSE FLAG #1 TO BE SET
                                                ;  AT EACH SYSTEM TIME UNIT TICK
0D05 3EFF               MVI     A,0FFH
0D07 32CE0D             STA     TICKN
0D0A C9                 RET

                ; STOP CLOCK

                STOPCLOCK:
                                                ; WILL STOP FLAG #1 SETTING AT
                                                ;  SYSTEM TIME UNIT TICK
0D0B AF                 XRA     A
0D0C 32CE0D             STA     TICKN
0D0F C9                 RET

                ; EXIT REGION
```

*p.148*

```
                EXITREGION:
                                                ; EI IF NOT PREEMPTED
0D10 3ACF0D             LDA     PREEMP
0D13 B7                 ORA     A
0D14 C0                 RNZ
0D15 FB                 EI
0D16 C9                 RET

                ; MAXIMUM CONSOLE NUMBER

                MAXCONSOLE:
0D17 3E04               MVI     A,NMBCNS
0D19 C9                 RET

                ;  MP/M 1.0   INTERRUPT HANDLERS

008E =          DSPTCH  EQU     142

                INT1HND:
                                                ; INTERRUPT 1 HANDLER ENTRY POINT
                                                ;
                T20MS:
0D1A 22C80D             SHLD    SVDHL
0D1D 21220D             LXI     H,TIMERINT
                        JR      INTINIT
0D20+185D               DB      018H,INTINIT-$-1        ;---- FAKE JR INSTR
                TIMERINT:
0D22 3ACE0D             LDA     TICKN
0D25 B7                 ORA     A                       ; TEST TICKN, INDICATES
                                                        ;  DELAYED PROCESS(ES)
                        JRZ     NOTICKN
0D26+2807               DB      028H,NOTICKN-$-1        ;---- FAKE JRZ INST
0D28 0E85               MVI     C,FLAGST
0D2A 1E01               MVI     E,1
0D2C CD100B             CALL    XDOS                    ; SET FLAG #1 EACH TICK
                NOTICKN:
0D2F 219D0D             LXI     H,CNTX
0D32 35                 DCR     M                       ; DEC TICK CNTR
                        JRNZ    NOT1SEC
0D33+2032               DB      020H,NOT1SEC-$-1        ;---- FAKE JRNZ INS
0D35 3E7D               MVI     A,125
0D37 2B                 DCX     H
0D38 96                 SUB     M
0D39 77                 MOV     M,A                     ; *** TOGGLE COUNT 62 <-> 6
0D3A 23                 INX     H
0D3B 77                 MOV     M,A                     ; *** ACTUAL #/SEC = 62.5
0D3C 0E85               MVI     C,FLAGST
0D3E 1E02               MVI     E,2
0D40 CD100B             CALL    XDOS                    ; SET FLAG #2 @ 1 SEC
0D43 2AD00D             LHLD    FPYTIME                 ;IS FLOPPY TIME CHECK IN EF
0D46 7C                 MOV     A,H                     ;
0D47 B7                 ORA     A                       ;
                        JRZ     NOT1SEC                 ;IF NOT IN EFFECT, FINISH
0D48+281D               DB      028H,NOT1SEC-$-1        ;---- FAKE JRZ INST
0D4A 2D                 DCR     L                       ;SUBTRACT A SECOND
```

*p.149*

```
0D4B 22D00D             SHLD    FPYTIME                 ;SAVE FOR NEXT TIME
                        JRNZ    NOT1SEC                 ;IF NOT TOO LONG, FINISH
0D4E+2017               DB      020H,NOT1SEC-$-1        ;---- FAKE JRNZ INS
0D50 65                 MOV     H,L                     ;ZERO OUT INDICATOR
0D51 22D00D             SHLD    FPYTIME                 ;PREVENT RE-ENTRY OF THIS R
0D54 0E85               MVI     C,FLAGST                ;
0D56 1E06               MVI     E,FPYFLAG               ;
0D58 CD100B             CALL    XDOS                    ;CAUSE I/O FOR FLOPPY TO CO
0D5B 3E90               MVI     A,10010000B
0D5D 32FC0A             STA     STATUS                  ;SHOW ERROR IN FLOPPY I/O
0D60 2AD20D             LHLD    FPYTCNT
0D63 23                 INX     H                       ;COUNT TIMES WD1791 GOES TO
0D64 22D20D             SHLD    FPYTCNT                 ;

                NOT1SEC:

                INTDONE:
0D67 AF                 XRA     A
0D68 32CF0D             STA     PREEMP  ; CLEAR PREEMPTED FLAG
0D6B C1                 POP     B
0D6C D1                 POP     D
0D6D 2ACA0D             LHLD    SVDSP
0D70 F9                 SPHL                            ; RESTORE STK PTR
0D71 F1                 POP     PSW
0D72 2ACC0D             LHLD    SVDRET
0D75 E5                 PUSH    H
0D76 210D0B             LXI     H,PDISP                 ; MP/M DISPATCH
0D79 E5                 PUSH    H                       ;   PUT ON STACK FOR RETURN
0D7A 2AC80D             LHLD    SVDHL
                ; THE FOLLOWING DISPATCH CALL WILL FORCE ROUND ROBIN
                ;  SCHEDULING OF PROCESSES EXECUTING AT THE SAME PRIORITY
                ;  EACH 1/32ND OF A SECOND.
                ; NOTE: INTERRUPTS ARE NOT ENABLED UNTIL THE DISPATCHER
                ;  RESUMES THE NEXT PROCESS.  THIS PREVENTS INTERRUPT
                ;  OVER-RUN OF THE STACKS WHEN STUCK OR HIGH FREQUENCY
                ;  INTERRUPTS ARE ENCOUNTERED.

                        RETI                            ; DISPATCH
0D7D+ED4D               DB      0EDH,04DH               ;---- FAKE RETI INSTRUCTION

                INTINIT:                        ;SAVE MACHINE STATE FOR INTRPT HNDL
0D7F 22C60D             SHLD    ADRINTHD
0D82 E1                 POP     H
0D83 22CC0D             SHLD    SVDRET
0D86 F5                 PUSH    PSW
0D87 210000             LXI     H,0
0D8A 39                 DAD     SP
0D8B 22CA0D             SHLD    SVDSP                   ; SAVE USERS STK PTR
0D8E 31C60D             LXI     SP,LSTINTSTK            ; LCL STK FOR INTR HNDL
0D91 D5                 PUSH    D
0D92 C5                 PUSH    B

0D93 3EFF               MVI     A,0FFH
0D95 32CF0D             STA     PREEMP                  ; SET PREEMPTED FLAG
```

*p.150*

```
0D98 2AC60D             LHLD    ADRINTHD
0D9B E9                 PCHL                    ;JUMP TO INTERRUPT HANDLER

                ;
                ; BIOS DATA SEGMENT
                ;
0D9C 3E         TOGCNT: DB      62      ; TOGGLE COUNTER 62 <-> 63
0D9D 3E         CNTX:   DB      62      ; TICK CNTR TO 1 SEC
                INTSTK:                 ; LOCAL INTRPT STK
0D9E C7C7C7C7C7         DW      0C7C7H,0C7C7H,0C7C7H,0C7C7H,0C7C7H
0DA8 C7C7C7C7C7         DW      0C7C7H,0C7C7H,0C7C7H,0C7C7H,0C7C7H
0DB2 C7C7C7C7C7         DW      0C7C7H,0C7C7H,0C7C7H,0C7C7H,0C7C7H
0DBC C7C7C7C7C7         DW      0C7C7H,0C7C7H,0C7C7H,0C7C7H,0C7C7H
                LSTINTSTK:
0DC6 0000       ADRINTHD: DW    0       ; INTERRUPT HANDLER ADDRESS
0DC8 0000       SVDHL:  DW      0       ; SAVED REGS HL DURING INT HNDL
0DCA 0000       SVDSP:  DW      0       ; SAVED SP DURING INT HNDL
0DCC 0000       SVDRET: DW      0       ; SAVED RETURN DURING INT HNDL
0DCE 00         TICKN:  DB      0       ; TICKING BOOLEAN,TRUE = DELAYED
0DCF 00         PREEMP: DB      0       ; PREEMPTED BOOLEAN

                        if      mpm20
                FPYTIME:
0DD0 0000               DW      0

                FPYTCNT:
0DD2 0000               DW      0
                        endif


                        PAGE

                ;-----------------------------------------------------------
                ;
                ;       THESE ARE THE DISK TYPE DEFINITION BLOCKS
                ;       EACH OF WHICH CORRESPONDS TO A PARTICULAR MODE.
                ;
                ;-----------------------------------------------------------

0DD4 =          DPB0:   EQU     $               ;VERSION 2.0, IBM SINGLE DE
0DD4 1A00               DW      26              ;SECTORS PER TRACK
0DD6 03                 DB      3               ;BLOCK SHIFT
0DD7 07                 DB      7               ;BLOCK SHIFT MASK
0DD8 00                 DB      0               ;EXTENT MASK
0DD9 F200               DW      242             ;DISK SIZE MINUS 1
0DDB 3F00               DW      63              ;DIRECTORY MAX
0DDD C0                 DB      192             ;ALLOC0
0DDE 00                 DB      0               ;ALLOC1
0DDF 1000               DW      16              ;CHECK AREA SIZE
0DE1 0200               DW      2               ;OFFSET TO START TRACK

0DE3 =          DPB1:   EQU     $               ;VERSION 2.0, IBM DOUBLE DE
0DE3 3400               DW      52              ;SECTORS PER TRACK
0DE5 04                 DB      4               ;BLOCK SHIFT
```

*p.151*

```
0DE6 0F                 DB      15              ;BLOCK SHIFT MASK
0DE7 01                 DB      1               ;EXTENT MASK
0DE8 F200               DW      242             ;DISK SIZE MINUS 1
0DEA 7F00               DW      127             ;DIRECTORY MAX
0DEC C0                 DB      192             ;ALLOC0
0DED 00                 DB      0               ;ALLOC1
0DEE 2000               DW      32              ;CHECK AREA SIZE
0DF0 0200               DW      2               ;OFFSET TO START TRACK

0DF2 =          DPB2:   EQU     $               ;VERSION 1.4 ALTOS DOUBLE D
0DF2 3000               DW      48              ;SECTORS PER TRACK
0DF4 04                 DB      4               ;BLOCK SHIFT
0DF5 0F                 DB      15              ;BLOCK SHIFT MASK
0DF6 00                 DB      0               ;EXTENT MASK (1.4 COMPATABI
0DF7 E000               DW      224             ;DISK SIZE MINUS 1
0DF9 5F00               DW      95              ;DIRECTORY MAX
0DFB C0                 DB      192             ;ALLOC0
0DFC 00                 DB      0               ;ALLOC1
0DFD 1800               DW      24              ;CHECK AREA SIZE
0DFF 0200               DW      2               ;OFFSET TO START TRACK

                        IF      HARDSK

                        if      mpm20
                DPB3:   DISKDEF 3,0,127,,16384,512,512,0,1,,0
0E01+=          DPB3    EQU     $               ;DISK PARM BLOCK
0E01+8000               DW      128             ;SEC PER TRACK
0E03+07                 DB      7               ;BLOCK SHIFT
0E04+7F                 DB      127             ;BLOCK MASK
0E05+07                 DB      7               ;EXTNT MASK
0E06+FF01               DW      511             ;DISK SIZE-1
0E08+FF01               DW      511             ;DIRECTORY MAX
0E0A+80                 DB      128             ;ALLOC0
0E0B+00                 DB      0               ;ALLOC1
0E0C+0080               DW      8000H+CKSZ              ;PERMANENT DISK WIT
0E0E+0100               DW      1               ;OFFSET
0000+=          XLT3    EQU     0               ;NO XLATE TABLE

                DPB4:   DISKDEF 4,0,127,,16384,512,512,0,513,,0
0E10+=          DPB4    EQU     $               ;DISK PARM BLOCK
0E10+8000               DW      128             ;SEC PER TRACK
0E12+07                 DB      7               ;BLOCK SHIFT
0E13+7F                 DB      127             ;BLOCK MASK
0E14+07                 DB      7               ;EXTNT MASK
0E15+FF01               DW      511             ;DISK SIZE-1
0E17+FF01               DW      511             ;DIRECTORY MAX
0E19+80                 DB      128             ;ALLOC0
0E1A+00                 DB      0               ;ALLOC1
0E1B+0080               DW      8000H+CKSZ              ;PERMANENT DISK WIT
0E1D+0102               DW      513             ;OFFSET
0000+=          XLT4    EQU     0               ;NO XLATE TABLE

                DPB5:   DISKDEF 5,0,127,,16384,512,512,0,1025,,0
0E1F+=          DPB5    EQU     $               ;DISK PARM BLOCK
0E1F+8000               DW      128             ;SEC PER TRACK
```

*p.152*

```
0E21+07                 DB      7               ;BLOCK SHIFT
0E22+7F                 DB      127             ;BLOCK MASK
0E23+07                 DB      7               ;EXTNT MASK
0E24+FF01               DW      511             ;DISK SIZE-1
0E26+FF01               DW      511             ;DIRECTORY MAX
0E28+80                 DB      128             ;ALLOC0
0E29+00                 DB      0               ;ALLOC1
0E2A+0080               DW      8000H+CKSZ              ;PERMANENT DISK WIT
0E2C+0104               DW      1025            ;OFFSET
0000+=          XLT5    EQU     0               ;NO XLATE TABLE

                DPB6:   DISKDEF 6,0,127,,16384,288,512,0,513,,0
0E2E+=          DPB6    EQU     $               ;DISK PARM BLOCK
0E2E+8000               DW      128             ;SEC PER TRACK
0E30+07                 DB      7               ;BLOCK SHIFT
0E31+7F                 DB      127             ;BLOCK MASK
0E32+07                 DB      7               ;EXTNT MASK
0E33+1F01               DW      287             ;DISK SIZE-1
0E35+FF01               DW      511             ;DIRECTORY MAX
0E37+80                 DB      128             ;ALLOC0
0E38+00                 DB      0               ;ALLOC1
0E39+0080               DW      8000H+CKSZ              ;PERMANENT DISK WIT
0E3B+0102               DW      513             ;OFFSET
0000+=          XLT6    EQU     0               ;NO XLATE TABLE
                        else
                DPB3:   DISKDEF 3,0,127,,16384,512,512,0,1

                DPB4:   DISKDEF 4,0,127,,16384,512,512,0,513

                DPB5:   DISKDEF 5,0,127,,16384,512,512,0,1025

                DPB6:   DISKDEF 6,0,127,,16384,288,512,0,513
                        endif

                        ENDIF

                        if      mdisk
                DPB7:   EQU     $               ;VIRTUAL DISK
                        DW      24              ;SECTORS PER TRACK
                        DB      3               ;BLOCK SHIFT
                        DB      7               ;BLOCK SHIFT MASK
                        DB      0               ;EXTENT MASK
                        DW      142             ;DISK SIZE MINUS 1
                        DW      63              ;DIRECTORY MAX
                        DB      0C0H            ;ALLOC0
                        DB      0               ;ALLOC1
                        DW      0               ;CHECK AREA SIZE
                        DW      0               ;OFFSET TO START TRACK
                        endif

                        page

                ;
                ;       MOVE SUBROUTINE
                ;
```

*p.153*

```
                        if      hardsk
                RWMOVE:
0E3D D5                 push    d
0E3E E5                 push    h
0E3F CD070B             call    swtuser         ;switch in user bank
0E42 E1                 pop     h
0E43 D1                 pop     d
0E44 018000             lxi     b,128
                        LDIR                    ;MOVE DATA TO/FROM BUFFER
0E47+EDB0               DB      0EDH,0B0H       ;---- FAKE LDIR INSTRUCTION
0E49 CD0A0B             call    swtsys          ;switch system back in
                ;
                ;       DATA HAS BEEN MOVED TO/FROM HOST BUFFER
                ;

0E4C 3AF90A             LDA     WRTYPE          ;WRITE TYPE ??

                        if      mpm20
0E4F E601               ani     WRDIR           ;TO DIRECTORY ??
                        JRZ     RWEND           ;NO, JUST END UP HERE
0E51+280D               DB      028H,RWEND-$-1  ;---- FAKE JRZ INSTRUCTION
                        else
                        CPI     WRDIR           ;TO DIRECTORY ??
                        JRNZ    RWEND           ;NO, JUST END UP HERE
                        endif

                ;
                ;       CLEAR HOST BUFFER FOR DIRECTORY WRITE
                ;

0E53 3AF60A             LDA     ERFLAG          ;CHECK PRIOR TO DIR ACTIVIT
0E56 B7                 ORA     A               ;ERRORS ??
                        JRNZ    RWEND           ;SKIP IF SO....
0E57+2007               DB      020H,RWEND-$-1  ;---- FAKE JRNZ INSTRUCTION
0E59 AF                 XRA     A               ;ZERO TO ACCUMULATOR
0E5A 32F00A             STA     HSTWRT          ;BUFFER WRITTEN
0E5D CD6D04             CALL    WRITEHST        ;

                RWEND:
0E60 3AF60A             LDA     ERFLAG          ;
0E63 B7                 ORA     A               ;IF ERRORS, RESET SO NO MAT
0E64 C8                 RZ                      ;NONE, JUST RETURN
0E65 21EA0A             LXI     H,HSTDSK        ;
0E68 36FF               MVI     M,0FFH          ;CANT POSSIBLY MATCH, MUST
                        ENDIF
0E6A C9                 RET                     ;

                MVDTB:
0E6B 2AAF00             LHLD    DMAADR          ; MOVE DATA TO FLOPPY BUFFE
0E6E E5                 push    h
0E6F CD070B             call    swtuser ;switch in user bank,
0E72 E1                 pop     h       ;   cannot access non-common BNKXIO
0E73 111D13             LXI     D,FPYBUF        ;
0E76 018000             LXI     B,128           ; 128 BYTES
```

*p.154*

```
                        LDIR                    ;
0E79+EDB0               DB      0EDH,0B0H       ;---- FAKE LDIR INSTRUCTION
0E7B C30A0B             jmp     swtsys          ;switch system back in
                        RET                     ;

0E7E F5         MVDFB:  PUSH    PSW             ; MOVE DATA FROM FLOPPY BUF
0E7F 3AFA0A             LDA     CMD             ;
0E82 E620               ANI     20H             ; CHECK FOR READ
                        JRNZ    MVDFX           ;  NO - BYPAS MOVE
0E84+2013               DB      020H,MVDFX-$-1  ;---- FAKE JRNZ INSTRUCTION
0E86 2AAF00             LHLD    DMAADR          ;
0E89 E5                 push    h
0E8A CD070B             call    swtuser ;switch in user bank,
0E8D D1                 pop     d       ;   cannot access non-common BNKXIO
0E8E 211D13             LXI     H,FPYBUF        ;
0E91 018000             LXI     B,128           ; 128 BYTES
                        LDIR                    ;
0E94+EDB0               DB      0EDH,0B0H       ;---- FAKE LDIR INSTRUCTION
0E96 CD0A0B             call    swtsys          ;switch system back in
0E99 F1         MVDFX:  POP     PSW             ;
0E9A C9                 RET                     ;

                        IF      HARDSK

0E9B                    DS      1                               ;MUST PRECEDE HSTBU
0E9C            HSTBUF: DS      1024                            ;HOST BUFFER AREA
129C                    DS      1                               ;MUST FOLLOW HSTBUF
                        ENDIF

                        PAGE



                ;-----------------------------------------------------------
                ;
                ;       INITIALIZE MP/M: REAL TIME CLOCK & DISKS
                ;
                ;-----------------------------------------------------------

                        if      mpm20
129D =          dirbuf  equ     $
131D =          fpybuf  equ     dirbuf+128
                        endif

                SYSTEMINIT:
                        ; C  = BREAKPOINT RESTART NUMBER
                        ; DE = BREAKPOINT RESTART HANDLER ADDRESS
                        ; HL = DIRECT XIOS INTERCEPT JUMP TABLE ADDRESS

129D 225E13             SHLD    SVDJT
12A0 69                 MOV     L,C
12A1 2600               MVI     H,0
12A3 29                 DAD     H
12A4 29                 DAD     H
12A5 29                 DAD     H       ;HL = RESTART JUMP ADDRESS
```

*p.155*

```
12A6 226013             SHLD    SVDBPA

                        if      not mdisk
12A9 2A130B             lhld    sysdat
12AC 2E0F               mvi     l,15    ;hl = .nmbmemsegs
12AE 46                 mov     b,m     ;b =  nmbmemsegs
                test$bank$setup$loop:
12AF 23                 inx     h
12B0 23                 inx     h
12B1 23                 inx     h
12B2 23                 inx     h       ;hl = .memseg(i).bank
12B3 7E                 mov     a,m
12B4 B7                 ora     a
12B5 C2BF12             jnz     bank$setup
12B8 05                 dcr     b
12B9 C2AF12             jnz     test$bank$setup$loop
12BC C3CE12             jmp     after$bank$setup
                bank$setup:
12BF 3E1A               MVI     A,01AH          ; SELECT BANK 3
12C1 CD4813             CALL    STMVTR          ; SET UP VECTORS
12C4 3E12               MVI     A,012H          ; SELECT BANK 2
12C6 CD4813             CALL    STMVTR          ; SET UP VECTORS
12C9 3E0A               MVI     A,00AH          ; SELECT BANK 1
12CB CD4813             CALL    STMVTR          ; SET UP VECTORS
                after$bank$setup:
                        else
                        mvi     a,1ah           ; bank 3 select for directo
                        out     09h
                        lxi     h,0bffeh
                        mvi     a,0e5h
                        cmp     m
                        inx     h
                        jrnz    fill
                        cmp     m
                        jrz     dontfill
                fill:
                        mov     m,a             ;set directory initialized
                        dcx     h
                        mov     m,a

                        lxi     b,07ffh         ;first 2 k of bank one gets
                        lxi     h,0
                        lxi     d,1
                        mvi     a,0ah           ; select bank 1
                        out     09h
                        mvi     m,0e5h
                        ldir
                dontfill:
                        endif
12CE 3E02               MVI     A,002H          ; SELECT BANK 0
12D0 CD4813             CALL    STMVTR          ; SET UP VECTORS

12D3 213717             lxi     h,ldrbiosbase+density$mask$offset
                ;;;;;   LXI     H,1737H         ; MOVE PARAMETERS CHANGED B
12D6 117C00             LXI     D,SEL0          ;         THE SETUP PROGRAM
```

*p.156*

```
12D9 010400             LXI     B,4             ;  4 SELECT MASKS
                        LDIR                    ;
12DC+EDB0               DB      0EDH,0B0H       ;---- FAKE LDIR INSTRUCTION
12DE 118800             LXI     D,MODE          ;
12E1 010400             LXI     B,4             ;  4 MODE BYTES
                        LDIR                    ;
12E4+EDB0               DB      0EDH,0B0H       ;---- FAKE LDIR INSTRUCTION
12E6 2ABB17             lhld    ldrbiosbase+misc$params$offset
                ;;;;;   LHLD    17BBH           ; GET MISC. PARAMETERS
12E9 22B600             SHLD    MPARMS          ;
12EC 3AB600             LDA     MPARMS          ; NOW TEST FOR CENTRONICS P
12EF E602               ANI     2               ;
                        JRZ     PRTOK           ;   NO   -   LEAVE SERIAL
12F1+2814               DB      028H,PRTOK-$-1  ;---- FAKE JRZ INSTRUCTION
12F3 212C0B             LXI     H,CLIST         ;
12F6 221000             SHLD    WBOTE+13        ; CHANGE PRINTER ROUTINE
12F9 211F0B             LXI     H,CNSTAT        ;   AND STATUS CHECK
12FC 22D50C             SHLD    DEVTBL          ;
12FF 3E03               MVI     A,003H          ;INITIALIZE PARALLEL PORT
1301 D313               OUT     013H
1303 3E0F               MVI     A,00FH          ;
1305 D313               OUT     013H

                PRTOK:
1307 010300             LXI     B,003H          ;SET THE MODE FOR DRIVES IN
                MODESET:
130A CD2F02             CALL    SELSDP          ;SELECT DRIVE FOR MODESET
130D 218800             LXI     H,MODE          ;
1310 09                 DAD     B               ;POINT TO CORRECT MODE BYTE
1311 C5                 PUSH    B               ;SAVE COUNT OF DRIVES
1312 41                 MOV     B,C             ; B = DRIVE #
1313 4E                 MOV     C,M             ;
1314 CDF807             CALL    XETMOD          ;SET MODE
1317 C1                 POP     B               ;
1318 0D                 DCR     C               ;END OF LIST YET ??
1319 F20A13             JP      MODESET         ;SET MODE FOR ALL DRIVES
131C CDD007             CALL    SDCONF          ;SET DISK CONFIGURATION

131F 018000             LXI     B,80H
1322 CD5502             CALL    SETDMA          ;SET DMA ADDRESS

1325 E5                 push    h

                        if      mpm20
1326 2A130B             lhld    sysdat
1329 2E07               mvi     l,7
132B 7E                 mov     a,m
                        else
                        lxi     h,INTERUPT
                        mov     a,h
                        endif

132C E1                 pop     h
132D ED47               DB      0EDH,047H       ;---- FAKE STAI INSTRUCTION
```

*p.157*

```
132F 3E60               MVI     A,60H           ; SET VECTOR FOR CTC
1331 D330               OUT     30H             ; CTC CHANNEL 0
1333 3EA7               MVI     A,0A7H          ; RESET  /  LOAD TIME CONST
1335 D333               OUT     33H             ; CHANNEL 3
1337 3EFA               MVI     A,250           ;  TIME CONSTANT
1339 D333               OUT     033H            ;

                        IF      HARDSK
133B AF                 XRA     A               ;ZERO ACCUMULATOR
133C 32EF0A             STA     HSTACT          ;SET HOST BUFFER INACTIVE
133F 32F10A             STA     UNACNT          ;SET UNALLOCATED COUNT TO Z

1342 219B0E             LXI     H,HSTBUF-1      ;SETUP WRITE CONTROL BYTE F
1345 360D               MVI     M,00DH          ;
                        ENDIF

1347 C9                 RET                     ;

                STMVTR:
1348 D309               OUT     MEMPORT
134A 3EC3               MVI     A,0C3H          ; SET VECTORS FOR BDOS
134C 320000             STA     0               ;  JMP INSTRUCTION
134F 2A5E13             LHLD    SVDJT           ;
1352 220100             SHLD    1
1355 2A6013             LHLD    SVDBPA
1358 77                 MOV     M,A
1359 23                 INX     H
135A 73                 MOV     M,E
135B 23                 INX     H
135C 72                 MOV     M,D
135D C9                 RET                     ;

135E            SVDJT:  DS      2       ; SAVED DIRECT JUMP TABLE ADDRESS
1360            SVDBPA: DS      2       ; SAVED BREAK POINT ADDRESS

                        if      mpm20
1362 =          xiosend equ     $
139D =          fdbuf   equ     (dirbuf-base)+256
139D                    org fdbuf+((xiosend-base)/fdbuf)*((xiosend-base)-fd
139D 00                 db      0
                        endif


139E                    END



070F ADDERRORS  0DC6 ADRINTHD   12CE AFTERBANKS 03DA ALLOC
081E ALV0       085E ALV1       089E ALV2       08DE ALV3
091E ALV4       095E ALV5       099E ALV6       09DE ALV7
0A1E ALV8       0A5E ALV9       0A9E ALVA       0AC2 ALVB
0708 BADIO      0D03 BANKNO     12BF BANKSETUP  0000 BASE
081E BEGDAT     4000 BLKSIZ     067B CHECKIT    06AE CHECKSTAT
0220 CHKHRD     06BC CHKS0      06C7 CHKS1      06CD CHKS2
```

*p.158*

```
06E6 CHKS3      06F7 CHKS4      03A1 CHKUNA     0B2C CLIST
0B3B CLIST1     0AFA CMD        0B1F CNSTAT     0D9D CNTX
0B15 COLDSTART  0B04 COMMONBASE 0B84 CONIN      0B8F CONOUT
0B79 CONST      0080 CPMSPT     083E CSV0       087E CSV1
08BE CSV2       08FE CSV3       095E CSV4       099E CSV5
09DE CSV6       0A1E CSV7       0A5E CSV8       0A9E CSV9
0AC2 CSVA       0AE6 CSVB       0D04 CURMEM     001C DATA0
002C DATA1      002E DATA2      002A DATA3      00B4 DBLKAD
052E DBLLOW     0530 DBLSAVE    0519 DBLUPDATE  0782 DEL1
0784 DEL2       0782 DELAY      0037 DENSITYMAS 0CD2 DEVOK
0CD5 DEVTBL     129D DIRBUF     00AC DISKNO     FFFF DMA
00AF DMAADR     00BE DMALEN     00BA DMAS1      00C6 DMAS2F
00C0 DMAS2H     00CA DMAS3      00CE DMAS3F     00BC DMASA
0DD4 DPB0       0DE3 DPB1       0DF2 DPB2       0E01 DPB3
0E10 DPB4       0E1F DPB5       0E2E DPB6       00D1 DPBASE
00D1 DPE0       00E1 DPE1       00F1 DPE2       0101 DPE3
0111 DPE4       0121 DPE5       0131 DPE6       0141 DPE7
0151 DPE8       0161 DPE9       0171 DPEA       0181 DPEB
00B2 DPEPTR     0790 DSCN0      0552 DSKSEL     008E DSPTCH
0246 DTBLT      0AF6 ERFLAG     0D10 EXITREGION 0000 FALSE
139D FDBUF      0B50 FDINTH     041C FILLHST    0763 FINTFIX
0085 FLAGST     0084 FLAGWT     0B47 FLOPPYINT  0687 FLOPPYIO
065C FLOPPYSEEK 0661 FPS1       131D FPYBUF     0006 FPYFLAG
0DD2 FPYTCNT    0DD0 FPYTIME    073A FPYWAIT    0670 FSECSET
06AA FWT1       0B5E HARDINT    FFFF HARDSK     0005 HDFLAG
0B67 HDINTH     0B71 HDSTFLG    00AE HEADNO     031A HOME
0337 HOME1      0340 HOME1A     0357 HOME2      0343 HOMEHARD
02F9 HOMEIT     0321 HOMESOFT   0B03 HOMETOGGLE 048F HRW0
0499 HRW1       04C4 HRW2       04CD HRW3       04D9 HRW4
04E1 HRW5       04E6 HRW6       0504 HRW7       0AEF HSTACT
0008 HSTBLK     0E9C HSTBUF     0AEA HSTDSK     0AED HSTSEC
0400 HSTSIZ     0010 HSTSPT     0AEB HSTTRK     0AF0 HSTWRT
00B8 HTK1       00B9 HTK2       07F8 INITEND    0D1A INT1HND
0D67 INTDONE    005E INTERUPT   0721 INTFIX     0D7F INTINIT
0D9E INTSTK     0051 LAST       062D LDH1       1700 LDRBIOSBAS
0CA9 LIST       0CB8 LIST1      061E LOADHEAD   001E LPTPRT0
0028 LPTPRT1    001F LPTSTS0    0029 LPTSTS1    0DC6 LSTINTSTK
0AFB MASK       0439 MATCH      0D17 MAXCONSOLE 000C MAXDSK
0000 MDISK      0009 MEMPORT    0002 MEMSK      00BB MISCPARAMS
0088 MODE       130A MODESET    0191 MODL0      019D MODL1
01A9 MODL2      00B6 MPARMS     FFFF MPM20      0E7E MVDFB
0E99 MVDFX      0E6B MVDTB      0AE6 NEWDSK     0AEE NEWHST
0AE9 NEWSEC     0AE7 NEWTRK     0461 NEWTRKCMP  0004 NMBCNS
0009 NMBDEV     075F NOFPYRST   0415 NOMATCH    03D4 NOOVF
0D67 NOT1SEC    0D2F NOTICKN    0B1C NULLINT    00A0 PCNT
0B0D PDISP      0005 PLCI0      0006 PLCI1      0007 PLCI2
0008 PLCI3      0001 PLCO0      0002 PLCO1      0003 PLCO2
0004 PLCO3      0000 PLLPT      05D4 PNTFN      05D1 PNTH2
05B3 POINT      0BAD POLCI0     0BEC POLCI1     0C2B POLCI2
0C6A POLCI3     0BDD POLCO0     0C1C POLCO1     0C5B POLCO2
0C9A POLCO3     0083 POLL       0CCB POLLDEVICE 0CBC POLLPT
0DCF PREEMP     0B01 PRETRIES   1307 PRTOK      0BB8 PT0IN
0BC5 PT0IN1     0BCA PT0OUT     0BD9 PT0OUT1    0BAD PT0ST
0BF7 PT1IN      0C04 PT1IN1     0C09 PT1OUT     0C18 PT1OUT1
0BEC PT1ST      0C36 PT2IN      0C43 PT2IN1     0C48 PT2OUT
```

*p.159*

```
0C57 PT2OUT1    0C2B PT2ST      0C75 PT3IN      0C82 PT3IN1
0C87 PT3OUT     0C96 PT3OUT1    0C6A PT3ST      0B9A PTBLJMP
028B READ       036B READHARD   047F READHST    0AF8 READOP
05E4 READSOFT   0308 REALDISK   FFFF RELOC      0643 REMOVELD
02EE RETMOD     0AF7 RSFLAG     0B1A RTNEMPTY   0E60 RWEND
0E3D RWMOVE     03E2 RWOPER     0AFD SAVE1      07D0 SDCONF
07DE SDDBL      07F1 SDL1       07F3 SDOK       0007 SECMSK
0003 SECSHF     00B1 SECTNO     05D6 SECTRAN    007C SEL0
0203 SELDSK     0242 SELERR     059B SELHARD    0CE9 SELMEMORY
022F SELSDP     0556 SELSOFT    0278 SETDEN     0255 SETDMA
0211 SETDSK     0544 SETDVD     0540 SETH14     0532 SETHED
02A1 SETMOD     0273 SETSEC     02C7 SETSEL     026D SETTRK
0547 SHD1       05A1 SLH1       055D SLS1       056B SLS2
0575 SLS3       0584 SLS4       0595 SLSERR     02E3 SMERR
0601 SRW1       0615 SRW2       0D05 STARTCLOCK 0AFC STATUS
1348 STMVTR     0D0B STOPCLOCK  05DB STRN1      05E2 STRN2
001D STS0       002D STS1       002F STS2       002B STS3
1360 SVDBPA     0DC8 SVDHL      135E SVDJT      0DCC SVDRET
0DCA SVDSP      0B0A SWTSYS     0B07 SWTUSER    0B13 SYSDAT
129D SYSTEMINIT 0D1A T20MS      0BA2 TBLJMP     0094 TCNT
12AF TESTBANKSE 0DCE TICKN      0D22 TIMERINT   0D9C TOGCNT
00AD TRAKNO     0B02 TRETRIES   0070 TRK0       064A TRKTST
FFFF TRUE       0AF1 UNACNT     0AF2 UNADSK     0AF5 UNASEC
0AF3 UNATRK     0717 WAIT0      0B15 WARMSTART  0003 WBOTE
0000 WRALL      0001 WRDIR      0296 WRITE      037E WRITEHARD
046D WRITEHST   05F2 WRITESOFT  0AF9 WRTYPE     0002 WRUAL
0B10 XDOS       07F8 XETMOD     0801 XETSEL     1362 XIOSEND
01B5 XLT0       01CF XLT1       01CF XLT2       0000 XLT3
0000 XLT4       0000 XLT5       0000 XLT6
```
