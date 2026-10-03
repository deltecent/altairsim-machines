#!/usr/bin/env bash
# sdsys/ holds an SD Systems SBC-200 with its MSMONR21 monitor, and SDOS and CP/M 2.2 booted from a
# VersaFloppy II.
#
# The monitor prints nothing until it sees a CR (it measures the baud rate from it). `.` is the
# monitor prompt. `C` and a CR cold-boot drive A. A boot stops if a key arrives while it runs, and
# the monitor treats a filler byte as a command, so a keystroke file cannot wait. The keys come
# from a shell function that sleeps between them. The text checked here comes from the guest: the
# SDOS banner and the `[A]` prompt, and the CP/M banner, the `A>` prompt and the directory entry
# `MOVCPM   COM`, which only the disk holds.
set -u
. "$(dirname "$0")/lib.sh"

# monitor_keys <boot?> <after> -- a CR for the baud rate, then (if asked) C, then the text <after>.
monitor_keys() {
  printf '\r'; sleep 3
  if [ "$1" = boot ]; then printf 'C\r'; sleep 10; fi
  [ -n "$2" ] && { printf '%s' "$2"; sleep 5; }
  return 0
}

# From inside its own directory, as the README says.
dir=$(stage sdsys)

out=$(run_machine "$dir" <(monitor_keys none "") 20 sbc200.toml)
expect_contains "cd sdsys && altairsim sbc200.toml" "$out" $'\n.'  # the prompt, on a line of its own

out=$(run_machine "$dir" <(monitor_keys boot "") 30 sdos.toml)
expect_contains "cd sdsys && altairsim sdos.toml" "$out" "32K SD-OS Version 1.8B" "[A]"

out=$(run_machine "$dir" <(monitor_keys boot $'DIR\r') 30 cpm.toml)
expect_contains "cd sdsys && altairsim cpm.toml" "$out" "64k CP/M vers 2.2 for MS-610" "A>" "MOVCPM   COM"

# By path from somewhere else: the disk is not in the working directory, so this proves the
# machine file's paths resolve against the file.
out=$(run_machine "$work/stage" <(monitor_keys boot $'DIR\r') 30 sdsys/cpm.toml)
expect_contains "altairsim sdsys/cpm.toml from the parent" "$out" "64k CP/M vers 2.2 for MS-610" "A>" "MOVCPM   COM"

finish
