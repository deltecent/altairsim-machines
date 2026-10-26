#!/usr/bin/env bash
# mpm2/mpm2.toml boots MP/M II 2.1 off the 88-DCDD: the DBL PROM loads BOOT, BOOT loads MPMLDR
# from the system tracks, and MPMLDR loads MPM.SYS. No CP/M runs. mpm2/mpm2-ss1.toml boots
# the same way off MPM2SS1.DSK, whose XIOS is for the System Support 1. Its XIOS is one page
# longer (`BNKXIOS SPR  B100H  1A00H`), and it sets the date of MP/M II from the clock of the
# board, so `TOD` prints the date of the host.
#
# `BNKXIOS SPR  B200H  1900H` is the line of the loader's memory map for the Altair XIOS, which
# only this disk holds. `0A>` is the prompt of MP/M II console 0. `Directory for User  0:` is
# the heading of the DIR of MP/M II, and `A: MPM      SYS` is a DIR line off the disk: MPM.SYS is its first file. `B: ABORT    PRL`
# and `BOOT     ASM` (on C:) are off MPMII_1.DSK and MPMII_2.DSK. MP/M II discards keys typed before its prompt, so
# each line waits for the prompt (start_machine in lib.sh). The boot takes less than a second at full speed.
set -u
. "$(dirname "$0")/lib.sh"

dirs=("MP/M II V2.1 Loader" "MP/M II V2.1" "0A>" "Directory for User  0:" "A: MPM      SYS"
      "B: ABORT    PRL" "BOOT     ASM")
want=("BNKXIOS SPR  B200H  1900H" "${dirs[@]}")

boot() {   # <cwd> <machine-file> [command]
  start_machine mpm2 3 "$1" "$2"
  wait_for mpm2 "0A>" 90
  type_line 3 'DIR\r'
  wait_for mpm2 "0A>" 30 2
  type_line 3 'DIR B:\r'
  wait_for mpm2 "0A>" 30 3
  type_line 3 'DIR C:\r'
  wait_for mpm2 "0A>" 30 4
  if [ -n "${3:-}" ]; then
    type_line 3 "$3\r"
    wait_for mpm2 "0A>" 30 5
  fi
  stop_machine mpm2 3
  cat "$work/mpm2.out"
}

# From inside its own directory, as the README says.
dir=$(stage mpm2)
out=$(boot "$dir" mpm2.toml)
expect_contains "cd mpm2 && altairsim mpm2.toml" "$out" "${want[@]}"

# By path from somewhere else: the disk is not in the working directory.
out=$(boot "$work/stage" mpm2/mpm2.toml)
expect_contains "altairsim mpm2/mpm2.toml from the parent" "$out" "${want[@]}"

# The System Support 1 machine. TOD prints the month and day of the host, with the weekday.
out=$(boot "$dir" mpm2-ss1.toml TOD)
expect_contains "cd mpm2 && altairsim mpm2-ss1.toml" "$out" \
  "BNKXIOS SPR  B100H  1A00H" "${dirs[@]}" "$(date '+%a %m/%d/')"

# The build uses the sources on BUILD.DSK, not the .ASM files beside it. Each copy on the
# disk must be the same bytes as the file in the folder.
disk_has "the sources on BUILD.DSK are the files of the folder" "$dir/BUILD.DSK" "$dir" \
  RESXIOS.ASM SS1XIOS.ASM LDRBIOS.ASM BOOT.ASM AFORMAT.ASM

finish
