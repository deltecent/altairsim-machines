# Burning an EPROM with the SSM PB1

This machine has an **SSM PB1 2708/2716 EPROM programmer** board and the programmer software from
the PB1 manual. You put data in memory and run the burner. After that, you save the burned chip as an
Intel HEX file on your host.

```
cd examples/pb1
altairsim pb1.toml
```

The machine starts the SSM 8080 System Monitor and prints:

```
MONITOR V1.0
.
```

The `.` is the prompt of the SSM monitor. Press `Ctrl-E` to go to the `altairsim>` prompt. Type
`RUN` to go back to the SSM monitor.

## The machine

The machine is a plain Altair with these parts:

- An 8080 processor, 52K of RAM at `0000`-`CFFF`, and the front panel.
- An SSM IO-4 board at ports `00`-`05`. Its serial port A is the console.
- The **PB1** board. Its control port is `10H`. Its 4K programming-socket window is at `D000`.
- The **SSM 8080 System Monitor** in a ROM at `F000`.

The PB1 software is written for the SSM monitor, and it uses these fixed addresses:
control port `10H` and socket window `D000`. RAM stops at `CFFF` so that the window is not RAM.

## The four programs

These routines are from the PB1 manual (copyright Solid State Music, 1978). The source and the
Intel HEX files are the same as in the manual.

| File | Manual | Origin | What it does |
|---|---|---|---|
| `PROG2708.ASM` / `.HEX` | §4.2 | `0100H` | Burns a **2708** (1K) from RAM at `4000` into the socket. |
| `PROG2716.ASM` / `.HEX` | §4.3 | `0100H` | Burns a **2716** (2K) from RAM at `4000`. |
| `ERACHK.ASM` / `.HEX` | §4.4 | `0140H` | Checks that the socket is **erased**. Prints `P` or `F`. |
| `CPYVFY.ASM` / `.HEX` | §4.5 | `0180H` | **Verifies** the burn against the RAM source. Prints `P` or `F`. |

## The SSM monitor at `F021`

Each program ends with `JMP F021H`. The two check programs also `CALL F009H`. Section 3.3 of
the PB1 manual gives the reason. `F021` is the entry address of the SSM monitor. `F009` is its
console-output routine. The machine has the SSM monitor at `F000`, so the programs run as SSM
wrote them:

- A burner returns to the SSM monitor when the burn is complete. The monitor prints its banner
  and its `.` prompt again.
- A check program prints `P` (pass) or `F` (fail) and then returns to the SSM monitor.

To use the programs with a different monitor, change two things. Change the address bytes at
`011F` and `0120` for the exit. Change the `CO` equate for console output.

## Burn a 2708 and make a HEX file

Start the programs with the `G` (go) command of the SSM monitor.

1. Press `Ctrl-E`.
2. Put 1K of data at `4000`, and load the three programs. They have different origins, so all
   three stay in memory:

   ```
   altairsim> FILL 4000-43FF A5        ; or LOAD your-data.hex: the 1K to burn, at 4000
   altairsim> LOAD PROG2708.HEX        ; the SSM 2708 burner (manual §4.2)
   altairsim> LOAD ERACHK.HEX          ; the erase check (manual §4.4)
   altairsim> LOAD CPYVFY.HEX          ; the verify (manual §4.5)
   altairsim> RUN                      ; back to the SSM monitor
   ```

3. Type `G140` and press Enter. The program checks that the chip is erased:

   ```
   G140
   P
   MONITOR V1.0
   .
   ```

4. Type `G100` and press Enter. The burner prints nothing. The burn is complete when the prompt
   comes back:

   ```
   G100

   MONITOR V1.0
   .
   ```

5. Type `G180` and press Enter. The program compares the chip with the data at `4000`:

   ```
   G180
   P
   MONITOR V1.0
   .
   ```

6. Press `Ctrl-E`. Save the socket window to a file on your host:

   ```
   altairsim> SAVE eprom.hex D000-D3FF ; the burned 2708, as an Intel HEX file
   ```

`eprom.hex` is an Intel HEX file. After the burn, the socket window is memory that you can
read. `SAVE` reads it from the bus and writes the HEX file. The board does not write files.

Now the chip is not erased. If you run the erase check (`G140`) again, it prints `F`.

For a **2716**, load `PROG2716.HEX` in place of `PROG2708.HEX`. Burn 2K from `4000`-`47FF`, and
save the 2K window `D000-D7FF`. The two check programs are for the 1K 2708. To check a 2716,
change the `03` at the start of the program to `07`, as the source files show.

---

The board is documented in the altairsim *User Manual*.
