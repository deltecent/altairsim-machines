#!/usr/bin/env bash
# ps2int/ps2int.toml boots the MITS Programming System II monitor from cassette.
#
# This tests the cassette load and the 32K of RAM. The monitor comes off PS2-MON.TAP and prints
# its "  ?" prompt when the tape has loaded, so each line waits for the prompt (start_machine in
# lib.sh). DEP puts two bytes at 40000 octal (0x4000), above the 16K of the built-in `ps2int`
# machine, and EXM reads them back. The console is a one-byte UART, so a line typed before the
# monitor reads the one before it loses characters.
#
# It does not load the editor or the assembler. Each tape change takes monitor commands
# (UNMOUNT, MOUNT) typed after ^E, and the simulator takes no more lines from a piped keyboard
# after ^E. It does not test Ctrl-C either: Ctrl-C ends a search of the cassette, but not every
# time.
set -u
. "$(dirname "$0")/lib.sh"

want=("  ?DEP 40000" "?EXM 40000,40001" $'123\r\n045')

boot() {   # <cwd> <machine-file>
  start_machine ps2 3 "$1" "$2"
  wait_for ps2 "  ?" 30
  type_line 3 'DEP 40000\r'           # DEP prints no prompt for its values: wait for each echo
  wait_for ps2 "DEP 40000" 10
  type_line 3 '123\r'
  wait_for ps2 "123" 10
  type_line 3 '45\r'
  wait_for ps2 "45" 10
  type_line 3 '\032'
  wait_for ps2 "  ?" 10 2
  type_line 3 'EXM 40000,40001\r'
  wait_for ps2 "  ?" 10 3
  stop_machine ps2 3
  cat "$work/ps2.out"
}

# From inside its own directory, as the README says.
dir=$(stage ps2int)
out=$(boot "$dir" ps2int.toml)
expect_contains "cd ps2int && altairsim ps2int.toml" "$out" "${want[@]}"

# By path from somewhere else: the tape and the loader are not in the working directory, so this
# proves the machine file's paths resolve against the file.
out=$(boot "$work/stage" ps2int/ps2int.toml)
expect_contains "altairsim ps2int/ps2int.toml from the parent" "$out" "${want[@]}"

finish
