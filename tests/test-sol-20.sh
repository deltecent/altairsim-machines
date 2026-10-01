#!/usr/bin/env bash
# Five machines. sol-20/trek80.toml, atc.toml, pacman.toml and raiders.toml each mount a 1977
# cassette, type `XE <name>` at SOLOS and start it. trek80-ent.toml pastes TREK80.ENT instead.
#
# The Sol-20's screen is the VDM-1's RAM at 0CC00H, so nothing a game draws reaches the terminal.
# sol-20.exp stops the machine with ATTN, reads the screen with DUMP and looks for a line only the
# running game draws. A SOLOS tape whose checksums are wrong is silent -- nothing loads and nothing
# says why -- so this is the only check that a tape decodes. It needs expect.
#
# What the window shows is not checked; this tests the machine, not the pixels.
set -u
. "$(dirname "$0")/lib.sh"

command -v expect > /dev/null || { echo "tests: expect is not installed" >&2; exit 2; }

# check <label> <cwd> <toml> <text> -- run one machine and look for <text> on its screen.
check() {
  local out
  if out=$(cd "$2" && expect -f "$here/sol-20.exp" "$SIM" "$3" "$4" 90 2>&1); then
    echo "ok:   $1"
  else
    echo "FAIL: $1" >&2
    echo "$out" >&2
    failures=$((failures + 1))
  fi
}

# From inside its own directory, as the README says.
dir=$(stage sol-20)
check "cd sol-20 && altairsim trek80.toml"   "$dir" trek80.toml   "ENTER SPEED FACTOR (9(SLOW)-0(FAST))"
check "cd sol-20 && altairsim atc.toml"      "$dir" atc.toml      "David Mannering"
check "cd sol-20 && altairsim pacman.toml"   "$dir" pacman.toml   "PRESS SPACE BAR TO START"
check "cd sol-20 && altairsim raiders.toml"  "$dir" raiders.toml  'Press "S" anytime to start playing'

# The same game from TREK80.ENT, a SOLOS ENTER script that PASTE types at the keyboard.
check "cd sol-20 && altairsim trek80-ent.toml" "$dir" trek80-ent.toml "ENTER SPEED FACTOR (9(SLOW)-0(FAST))"

# By path from somewhere else: the tape is not in the working directory.
check "altairsim sol-20/trek80.toml from the parent" "$work/stage" sol-20/trek80.toml "ENTER SPEED FACTOR (9(SLOW)-0(FAST))"

finish
