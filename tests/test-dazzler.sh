#!/usr/bin/env bash
# Four machines. dazzler/kscope.toml loads and starts Li-Chen Wang's Kaleidoscope. dazzler/dzmbasic.toml
# boots CP/M and runs DZMBASIC, Microsoft BASIC with Dazzler graphics. dazzler/games.toml boots CP/M
# off the games disk. dazzler/gdemo.toml loads and starts Cromemco's GDEMO.
#
# KSCOPE never stops and prints nothing, so its test is that the startup list loads the 127 bytes
# and RUNs; the picture is in the window.
#
# The keystroke file starts DZMBASIC, initializes the Dazzler, draws a line from (5,5) to
# (50,50) and reads both end points back with DZF. DZF returns the color code of a dot, so a
# lit dot gives 1 and PRINT DZF(5,5)*100+7 gives " 107 ". That proves the board's ports and the
# framebuffer in RAM work, and the Z80: on an 8080 DZOP "I" warm-boots to A>, and "Ok" would
# never follow it.
#
# A blank line follows each statement that touches the Dazzler: the next character typed while the Dazzler
# library is still drawing is lost, as it would be on a real machine, and the blank absorbs it.
#
# GDEMO never stops and prints nothing on this machine, so its test is the same as KSCOPE's: the
# startup list loads the 2691 bytes and RUNs.
#
# The games machine boots CP/M and reads the directory of GAMES.DSK. `A: 4DTICTAC COM` is the first
# line of DIR. DIR stops after one line because a CR is already waiting in the keystroke file
# (dazzler-games.keys). No game is started: a game prints nothing at the terminal.
#
# What the window shows is not checked; this tests the machine, not the pixels.
set -u
. "$(dirname "$0")/lib.sh"

keys="$here/keys/dazzler-dzmbasic.keys"
want=("56K CP/M" "A>DZMBASIC" "Microsoft" "Ok" "107" "108" "DZDONE")

# From inside its own directory, as the README says.
dir=$(stage dazzler)
out=$(run_machine "$dir" /dev/null 15 kscope.toml)
expect_contains "cd dazzler && altairsim kscope.toml" "$out" "loaded 127 bytes" "RUN 0" "[console"

out=$(run_machine "$dir" "$keys" 60 dzmbasic.toml)
expect_contains "cd dazzler && altairsim dzmbasic.toml" "$out" "${want[@]}"

out=$(run_machine "$dir" /dev/null 15 gdemo.toml)
expect_contains "cd dazzler && altairsim gdemo.toml" "$out" "loaded 2691 bytes" "RUN 100" "[console"

out=$(run_machine "$dir" "$here/keys/dazzler-games.keys" 60 games.toml)
expect_contains "cd dazzler && altairsim games.toml" "$out" "machine: games" "56K CP/M" "A: 4DTICTAC COM"

# By path from somewhere else: the disk is not in the working directory.
out=$(run_machine "$work/stage" "$keys" 60 dazzler/dzmbasic.toml)
expect_contains "altairsim dazzler/dzmbasic.toml from the parent" "$out" "${want[@]}"

finish
