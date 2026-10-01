#!/usr/bin/env bash
# acr/mitstapes.toml boots Mike Douglas's MITS Tapes CP/M disk, with an 88-ACR on the bus.
#
# This tests that the shipped directory boots to A> off its own disk and that CP/M reads the
# image: the first directory entry, 4KBAS32.TAP, can only come off the MITS Tapes disk. DIR stops
# after one line because a CR is already waiting in the keystroke file (acr-dir.keys).
#
# It does not record a tape. Recording takes a monitor command (MOUNT acr0:tape ... mode=record)
# typed after ^E, and a piped keystroke file cannot do that: the simulator takes ^E the moment it
# is read, before the guest has booted.
set -u
. "$(dirname "$0")/lib.sh"

keys="$here/keys/acr-dir.keys"
want=("48K CP/M" "Version 2.2mits (07/28/80)" "A>" "4KBAS32")

# From inside its own directory, as the README says.
dir=$(stage acr)
out=$(run_machine "$dir" "$keys" 60 mitstapes.toml)
expect_contains "cd acr && altairsim mitstapes.toml" "$out" "${want[@]}"

# By path from somewhere else: the disk is not in the working directory.
out=$(run_machine "$work/stage" "$keys" 60 acr/mitstapes.toml)
expect_contains "altairsim acr/mitstapes.toml from the parent" "$out" "${want[@]}"

finish
