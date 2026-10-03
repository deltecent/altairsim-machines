#!/usr/bin/env bash
# cdos/cdos.toml boots CDOS 2.58 off a Cromemco 16FDC.
#
# The RDOS PROM and the FD1793 load CDOS from a mixed-density 8" diskette. DIR then reads the
# directory off the disk: `XMODEM` and `18 Files` can only come from the platter. This needs
# expect because piped keystrokes derail the PROM's ESC-to-abort window (see cdos.exp).
set -u
. "$(dirname "$0")/lib.sh"

command -v expect > /dev/null || { echo "tests: expect is not installed" >&2; exit 2; }

# check <label> <cwd> <toml>
check() {
  local out
  if out=$(cd "$2" && expect -f "$here/cdos.exp" "$SIM" "$3" 2>&1); then
    echo "ok:   $1"
  else
    echo "FAIL: $1" >&2
    echo "$out" >&2
    failures=$((failures + 1))
  fi
}

# From inside its own directory, as the README says.
dir=$(stage cdos)
check "cd cdos && altairsim cdos.toml" "$dir" cdos.toml

# By path from somewhere else: proves the disk path resolves against the machine file.
check "altairsim cdos/cdos.toml from the parent" "$work/stage" cdos/cdos.toml

finish
