#!/usr/bin/env bash
# fdcplus/fdcplus-type5.toml boots CP/M off the FDC+'s 1.5 MB floppy (drive type 5) with the stock
# DBL boot PROM and no boot command.
#
# This tests the FDC+ boot path: the PROM reads the sector that the board makes up from its own
# memory, that sector's loader reads the real disk, and CP/M reads the directory.
# `A: R        COM` is a directory entry that can only come off that disk. DIR stops after one line
# because a CR is already waiting in the keystroke file (fdcplus-dir.keys).
#
# fdcplus-type7.toml is not tested: it needs an FDC+ drive server on a serial port.
set -u
. "$(dirname "$0")/lib.sh"

keys="$here/keys/fdcplus-dir.keys"
want=("48K CP/M 2.2b v1.2" "For Altair 1.5Mb Floppy" "A>DIR" "A: R        COM")

# From inside its own directory, as the README says.
dir=$(stage fdcplus)
out=$(run_machine "$dir" "$keys" 60 fdcplus-type5.toml)
expect_contains "cd fdcplus && altairsim fdcplus-type5.toml" "$out" "${want[@]}"

# By path from somewhere else: the disk is not in the working directory.
out=$(run_machine "$work/stage" "$keys" 60 fdcplus/fdcplus-type5.toml)
expect_contains "altairsim fdcplus/fdcplus-type5.toml from the parent" "$out" "${want[@]}"

finish
