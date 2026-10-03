#!/usr/bin/env bash
# uio/uio.toml boots Altair 8K BASIC 3.2 from cassette over one 88-UIO board.
#
# This tests both halves of the card: the cassette half at 0x06 loads BASIC from the tape, and the
# serial half at 0x10 is the console. "BYTES FREE" and the banner come from the tape. "42" is a
# BASIC program run by the guest. The NUL bytes in the keystroke file (uio-basic.keys) give the
# tape time to load before the first prompt is answered.
set -u
. "$(dirname "$0")/lib.sh"

keys="$here/keys/uio-basic.keys"
want=("MEMORY SIZE?" "10312 BYTES FREE" "ALTAIR BASIC VERSION 3.2" "[EIGHT-K VERSION]" " 42 ")

# From inside its own directory, as the README says.
dir=$(stage uio)
out=$(run_machine "$dir" "$keys" 30 uio.toml)
expect_contains "cd uio && altairsim uio.toml" "$out" "${want[@]}"

# By path from somewhere else: the tape and the loader are not in the working directory, so this
# proves the machine file's paths resolve against the file.
out=$(run_machine "$work/stage" "$keys" 30 uio/uio.toml)
expect_contains "altairsim uio/uio.toml from the parent" "$out" "${want[@]}"

finish
