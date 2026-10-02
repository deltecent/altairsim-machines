# Music from a Newtech Model 6 Music Board

An Altair with a **Newtech Model 6 Music Board** in it, and the two things that Newtech
supplied in the manual of the board: the player program **MICROPLAY**, and the score of
**"The Entertainer"** by Scott Joplin.

```
cd examples/newtech
altairsim newtech.toml
```

The machine loads the program and the score from its `startup` list, and runs. On a build
with **SDL3**, you hear the tune on the sound output of your computer. The tune is about
38 seconds long. On a **headless** build, the program runs the same and is silent.

MICROPLAY does not stop at the end of the score. It stays in a loop at address `000F`. To
play the tune again:

1. Press **STOP** (`Ctrl-E`) at the terminal. You get the `altairsim>` prompt.
2. Type `RUN 0`.

You can press STOP while the tune plays, too.

## The board

The Model 6 (Newtech Computer Systems, 1977) is one output port, a **6-bit D/A converter**,
an amplifier and a speaker. It has no sound chip and no timer. A program makes the sound: it
writes a value to the port, waits, and writes the next value. The time of the loop is the
pitch.

| | |
|---|---|
| Board type | `music6` |
| Port | `24`, the address of the board as supplied. The board also answers at `25`, `26` and `27`. |
| Data | The top six bits of the byte. The low two bits do nothing. |

The machine is the built-in `default` Altair with two changes. The processor has a 2 MHz
crystal (`clock_hz = 2000000`), and the Model 6 is added.

**The sound needs the crystal.** MICROPLAY is timed for an 8080 at 2 MHz. At full speed
(`clock_hz = 0`), the loop has no relation to real time, and the board plays nothing.
`SHOW music0` tells you if the board plays. If the board is silent, it gives the reason.

## The files

| File | What it is |
|---|---|
| `newtech.toml` | The machine. |
| `MPLAY.ASM` | MICROPLAY Rev. A, typed from the listing in the manual. |
| `MPLAY.HEX`, `MPLAY.PRN` | The assembled program and its listing. Origin `0000`, 111 bytes. |
| `SCORE.ASM` | The score, 120 notes. Each line shows the note that it holds. |
| `SCORE.HEX` | The assembled score. It loads at `0100`, 361 bytes. |

The two `.HEX` files came from the CP/M assembler, `ASM.COM`, run in the simulator. The bytes
of `MPLAY.HEX` are the same as the bytes in the listing of the manual.

## How MICROPLAY plays a note

A note in the score is three bytes:

| Byte | Content |
|---|---|
| 0 | The pitch constant, a delay count. Zero ends the score. |
| 1 | The duration count, low byte. |
| 2 | The duration count, high byte, plus 1. |

MICROPLAY copies the three bytes into its own instructions, at the labels `XFER1` to `XFER4`.
The program changes its own code, so it must run in RAM.

One half wave takes 114 + 15 × N clock cycles, where N is the pitch constant. At 2 MHz, the
first note (N = `31` hex) is 1178 Hz. A note is eight segments. Each segment has its own
loudness, from the table `TBL1`, and plays the duration count in half waves.

The comments in the manual say that the program complements the accumulator for each half
wave. The instruction in the listing is `XRA M`, and the program here is the listing. The
output goes between the loudness value and zero.

## Where the score comes from

The manual gives the score as note names in a second program, **MICROSCORE**, written in
North Star BASIC. MICROSCORE reads strings such as `D 3S` (D, octave 3, a sixteenth note) and
writes the three bytes for each note into memory at `0100`.

This example does not run MICROSCORE. The bytes in `SCORE.ASM` are the result of the
arithmetic of MICROSCORE for each string in the manual, at its tempo setting of 1.2. The
comment on each line gives the string. The manual writes a flat as `!`. `SCORE.ASM` writes a
flat as `b`, because the assembler ends a statement at `!`.

To play your own tune, put your notes at `0100` in the same three-byte form, end them with a
zero byte, and type `RUN 0`.

## Sources

- Newtech Computer Systems, *Model 6 Music Board Users Manual*, Rev. A, June 1977. A scan is
  on s100computers.com.
- "The Entertainer", Scott Joplin, 1902.
