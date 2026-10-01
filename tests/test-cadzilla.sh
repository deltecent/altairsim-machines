#!/usr/bin/env bash
# cadzilla/drawdemo.toml boots CP/M and runs DRAWDEMO, the CADzilla ACRTC drawing demo.
#
# The keystroke file types DRAWDEMO at A>, then 25 spaces: one "press any key" for each of the
# 21 screens, with a few to spare. The program steps through every ACRTC drawing command and
# exits to A>. Reaching "21/21" and "drawdemo done." proves the disk, the DBL boot PROM, CP/M,
# the program and the board's I/O ports all work. (Whether the pictures are right is for the
# window; this checks the machine, not the pixels.)
set -u
. "$(dirname "$0")/lib.sh"

keys="$here/keys/cadzilla-drawdemo.keys"
want=("56K CP/M 2.2b v2.3" "For Altair 8\" Floppy" "A>DRAWDEMO"
      "CADzilla drawdemo: the ACRTC drawing commands, 1024x768, 8 bpp" "1/21  DOT" "12/21  CRCL" "21/21  AREA" "drawdemo done.")

# From inside its own directory, as the README says.
dir=$(stage cadzilla)
out=$(run_machine "$dir" "$keys" 60 drawdemo.toml)
expect_contains "cd cadzilla && altairsim drawdemo.toml" "$out" "${want[@]}"

# By path from somewhere else: the disk is not in the working directory.
out=$(run_machine "$work/stage" "$keys" 60 cadzilla/drawdemo.toml)
expect_contains "altairsim cadzilla/drawdemo.toml from the parent" "$out" "${want[@]}"

finish
