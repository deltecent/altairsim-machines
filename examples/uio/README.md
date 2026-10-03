# 88-UIO: two boards in one

Altair 8K BASIC 3.2 loads from a cassette through one **88-UIO** board.

```
cd examples/uio
altairsim uio.toml
```

The machine stops at the BASIC prompts. Press Enter at `MEMORY SIZE?` and at `TERMINAL WIDTH?`.
Type `Y` at `WANT SIN-COS-TAN-ATN?`. BASIC then prints:

```
10312 BYTES FREE

ALTAIR BASIC VERSION 3.2
[EIGHT-K VERSION]

OK
```

## What is different

The built-in `basic8k` machine needs two boards. An 88-2SIO is the console. An 88-ACR is the
cassette. This machine has one board, the MITS 88-UIO, which does both jobs.

- The 6850 serial port of the 88-UIO responds to port 0x10. This is where Port A of an 88-2SIO
  responds. The serial port is the console.
- The cassette section responds to port 0x06. This is where an 88-ACR responds. The cassette
  section is the tape.

Both sections use the standard ports. Therefore the MITS bootstrap `LDR8K32.HEX` runs without a
change. 8K BASIC does not know that one board does both jobs. The sense switches are `0x8C`. The
header of the loader gives this value: A15 selects load from cassette, and A11 and A10 select an
88-2SIO terminal.

## Try it

Type a program at the `OK` prompt:

```basic
10 PRINT 6*7
20 PRINT "TAPE OK"
RUN
```

An 88-UIO can do things that an 88-ACR cannot. Press `Ctrl-E` to get the monitor, then type:

```
SHOW uio0                 ; show both sections: serial_port, port, standard, motor
SET uio0 standard=kansas  ; use the Kansas City standard (2400/1200) for the modem
REWIND uio0:tape          ; put the tape back at the start
```

`Ctrl-E` returns you to the `altairsim>` monitor at any time.

## Files

| File | What it is |
|---|---|
| `uio.toml` | The machine file: one 88-UIO, 16K of RAM, the front panel and the console. |
| `8K BASIC Ver 3-2.tap` | Altair 8K BASIC 3.2, a cassette image from the period. |
| `LDR8K32.HEX` | The 8K bootstrap loader. The machine file puts it in memory at address 0. |

The processor runs at full speed, and the tape loads in about one second. To run at the 2 MHz
speed of the real machine, type `SET cpu0 clock_hz=2000000`. A 300-baud cassette then takes about
90 seconds to load.
