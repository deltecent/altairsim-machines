#!/usr/bin/env bash
# hdsk/hdsk.toml boots CP/M off the 88-HDSK hard disk.
#
# This tests the whole controller path: the HDBL PROM reads the Pack Descriptor Page and loads the
# boot pages, then CP/M reads the directory off the platter. `A: BOOT     ASM` is a directory
# entry read through the controller. DIR stops after one line because a CR is already waiting in
# the keystroke file (hdsk-dir.keys).
set -u
. "$(dirname "$0")/lib.sh"

keys="$here/keys/hdsk-dir.keys"
want=("HDBL 2.00" "48K CP/M 2.2b v1.6" "For MITS 88-HDSK" "A0>" "A: BOOT     ASM")

# From inside its own directory, as the README says.
dir=$(stage hdsk)
out=$(run_machine "$dir" "$keys" 60 hdsk.toml)
expect_contains "cd hdsk && altairsim hdsk.toml" "$out" "${want[@]}"

# By path from somewhere else: the platter is not in the working directory, so this proves the
# machine file's paths resolve against the file.
out=$(run_machine "$work/stage" "$keys" 60 hdsk/hdsk.toml)
expect_contains "altairsim hdsk/hdsk.toml from the parent" "$out" "${want[@]}"

finish
