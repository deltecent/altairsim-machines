# MITS Programming System II

The MITS Programming System II monitor loads from a cassette through an **88-ACR**. The package
has a monitor, an editor, two assemblers and a debugger. Each one is on its own tape.

```
cd examples/ps2int
altairsim ps2int.toml
```

The monitor prompt is two spaces and a question mark:

```
  ?
```

**Do not type a word to see what it does.** A word that the monitor does not know is a program
name. The monitor then loads that program from the device that ABS is open to, and waits. When
the monitor starts, ABS is open to the terminal. `Ctrl-C` does not stop a load from the terminal.
To get the prompt back:

1. Press `Ctrl-E`.
2. Type `RUN 0x40`. 0x40 (100 octal) is the restart address of the monitor.

After `OPN ABS,AC` (step 1 of "Load the editor and the assembler"), the monitor searches the
cassette, and `Ctrl-C` gets the prompt back.

## What is different

The built-in `ps2int` machine is the same hardware with 16K of RAM. This directory adds the
tapes, the loader and the steps to edit and assemble a program.

- An **88-VI/RTC** board and sense switch A9 down turn on serial input interrupts. Then
  `Ctrl-C` returns you to the monitor, but not during a load from the terminal. The RTC
  interrupt output of the 88-VI/RTC is not connected, because the monitor has no handler for it.
- The console is Port A of an 88-2SIO at 0x10, strapped to vector 7.
- The machine has 32K of RAM. The steps below move the edit buffer to 0x4000-0x5FFF.
- The sense switches are `0x8C`. The loader is the 4K BASIC 3.2 bootstrap, not the 8K one.

## Load the editor and the assembler

1. Set the cassette as the program load device. At the `?` prompt, type:

   ```
   OPN ABS,AC
   ```

2. Put the editor tape in. Press `Ctrl-E`, then type:

   ```
   UNMOUNT acr0
   MOUNT acr0:tape "PS2-EDT.BIN"
   RUN
   ```

3. Type `EDT` to load the editor. The editor prompt is `*`. Type `E` to go back to the monitor.

4. Move the edit buffer to 0x4000-0x5FFF, above the assembler. The addresses are octal. Type
   each line, and end each `DEP` with `Ctrl-Z`:

   ```
   DEP 5124
   0
   100
   ```

   ```
   DEP 5530
   0
   140
   ```

5. Put the assembler tape in. Press `Ctrl-E`, then type:

   ```
   UNMOUNT acr0
   MOUNT acr0:tape "PS2-AM2.BIN"
   RUN
   ```

6. Type `AM2` to load the assembler. The prompt is `*ASM*`. Type `EOA` to go back to the
   monitor.

## Edit and assemble

1. Type `EDT` to start the editor with an empty buffer. `EDT(R)` keeps the text that is
   already in the buffer.
2. In the editor:
   - `I` inserts text. `Ctrl-Z` ends the insert.
   - `P` shows the text with line numbers. `W` shows it without line numbers.
   - `D line[,line]` deletes lines. `R line` replaces a line. `I line` inserts after a line.
   - `E` goes back to the monitor.
3. End each program with these three lines. `start label` is the entry point. `name` is a
   program name of three characters.

   ```
   BEG start label
   END name
   EOA
   ```

4. Tell the assembler to read the edit buffer as a text file. Do this one time in a session:

   ```
   OPN FIL,EB,A
   ```

5. Type `AM2`, then `FILE`. The assembler shows the errors and the undefined symbols, then
   returns to the monitor. The "Undefined Symbols" heading comes even when there are none.
6. Type `JMP address` to run the program. The address is octal.
7. To run the program by its name: after a good assembly, type `AM2(P)`. This keeps the
   symbols. Then type `RUN name`. After that, the name alone runs the program.

## Save and load source files on tape

1. Type `NUL 4`. This puts four nulls after each line that is written to tape.
2. Type `OPN FIL,AC,A`. This sets the cassette as the file device, for text files.
3. In the editor, type `L` to load a source file, or `S` to save one.
4. After a load, type `OPN FIL,EB,A` again, so that the assembler reads the edit buffer.
5. Before you save with `S`, set the file device back to the cassette with `OPN FIL,AC,A`.

To save to a new tape, mount a new file for recording. See "Tapes" in the altairsim manual.

## Files

| File | What it is |
|---|---|
| `ps2int.toml` | The machine file: the front panel, an 8080, an 88-VI/RTC, an 88-2SIO, an 88-ACR and 32K of RAM. |
| `LDRPS2.HEX` | The bootstrap loader (the 4K BASIC 3.2 loader). The machine file puts it in memory at address 0. |
| `LDRPS2.ASM` | The source for `LDRPS2.HEX`. It is `LDR4K32.ASM` from the Cassette Loaders directory on deramp.com. |
| `PS2-MON.TAP` | The monitor tape. The machine file mounts it. |
| `PS2-EDT.BIN` | The editor tape. |
| `PS2-AM2.BIN` | The assembler, version 2. It loads above the editor. |
| `PS2-ASM.BIN` | The assembler, version 1. It loads at the same address as the editor. |
| `PS2-DBG.BIN` | The debugger. It loads over the editor and can be in memory with AM2. |
| `Programming System II.pdf` | The MITS manual for the package. |
| `DeRamp PS II Usage Notes.pdf` | Mike Douglas's notes: memory use, the load steps, and an AM2 bug and its patch. |

The processor runs at full speed, and each tape loads in a few seconds. To run at the 2 MHz
speed of the real machine, type `SET cpu0 clock_hz=2000000`. To load a tape at the real
300 baud, type `SET acr0:tape rate=real`.

`Ctrl-E` returns you to the `altairsim>` monitor at any time.
