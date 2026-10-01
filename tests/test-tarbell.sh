#!/usr/bin/env bash
# Three machines. tarbell/tarbell.toml, tarbelldd.toml and tarbelldd-dma.toml each boot CP/M 2.2 off
# a Tarbell floppy controller with no monitor and no boot command: the controller's own 32-byte
# boot PROM reads track 0 and the disk's loader does the rest.
#
# This tests that boot path -- the PROM, the WD FD177x controller, single and double density, and
# the 8257 DMA controller for the DMA machine -- and that CP/M reads the directory off the disk.
# The first entry of each can only come off that disk. DIR stops after one line because a CR is
# already waiting in the keystroke file (tarbell-dir.keys).
set -u
. "$(dirname "$0")/lib.sh"

keys="$here/keys/tarbell-dir.keys"
sd=("48K CP/M 2.2b v1.5" "SD Tarbell on Altair" "A>DIR" "A: ASM      COM")
dd=("Tarbell 48K CPM 2.2" "Auto-Select ver of 01-29-82" "A>DIR" "A: R        COM")

# From inside its own directory, as the README says.
dir=$(stage tarbell)
out=$(run_machine "$dir" "$keys" 60 tarbell.toml)
expect_contains "cd tarbell && altairsim tarbell.toml" "$out" "${sd[@]}"

out=$(run_machine "$dir" "$keys" 60 tarbelldd.toml)
expect_contains "cd tarbell && altairsim tarbelldd.toml" "$out" "${dd[@]}"

out=$(run_machine "$dir" "$keys" 60 tarbelldd-dma.toml)
expect_contains "cd tarbell && altairsim tarbelldd-dma.toml" "$out" "${dd[@]}"

# By path from somewhere else: the disk is not in the working directory.
out=$(run_machine "$work/stage" "$keys" 60 tarbell/tarbelldd-dma.toml)
expect_contains "altairsim tarbell/tarbelldd-dma.toml from the parent" "$out" "${dd[@]}"

finish
