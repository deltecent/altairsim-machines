#!/usr/bin/env bash
# newtech/newtech.toml loads MICROPLAY and the score of "The Entertainer", and RUNs. The program
# plays through a Newtech Model 6 Music Board (music6) and prints nothing.
#
# The first check is that the startup list loads the two files and RUNs.
#
# The second check is that MICROPLAY plays to the end of the score. MICROPLAY has no exit: at
# the zero byte that ends the score it loops at 000F. It also passes 000F one time for each note,
# with the Z flag clear. So a copy of the machine file gets a breakpoint at 000F for Z set, and
# the stop must show HL at 0268, the address of the zero byte after the 120 notes.
#
# The input of that run is a pipe that stays open and sends nothing. A run whose input has
# ended stops at once, before the first note is done.
#
# What you hear is not checked; this tests the machine, not the sound.
set -u
. "$(dirname "$0")/lib.sh"

# From inside its own directory, as the README says.
dir=$(stage newtech)
out=$(run_machine "$dir" /dev/null 15 newtech.toml)
expect_contains "cd newtech && altairsim newtech.toml" "$out" \
  "loaded 111 bytes" "(0000-006E)" "loaded 361 bytes" "(0100-0268)" "RUN 0" "[console"

sed 's/"RUN 0"\]/"BREAK 000F IF Z==1", "RUN 0"]/' "$dir/newtech.toml" > "$dir/to-the-end.toml"
mkfifo "$work/quiet"
sleep 6 > "$work/quiet" &
holder=$!
out=$(run_machine "$dir" "$work/quiet" 10 to-the-end.toml)
kill "$holder" 2> /dev/null || true
expect_contains "MICROPLAY plays all 120 notes and stops at the end of the score" "$out" \
  "stopped at 000F" "HL=0268"

finish
