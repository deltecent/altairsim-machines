#!/usr/bin/env bash
# d7a/music3.toml plays MUSIC3 on a Z80 with a Cromemco D+7A; d7a/music3-build.toml builds it.
#
# The player machine has no console program. The test checks that MUSIC3.HEX loads at 0100 and
# that the program reaches its HLT. Under a startup RUN the machine runs at full speed, so the
# song ends at once. The test does not hear the sound.
#
# The build machine boots CP/M 2.2b off MUSIC3.DSK. `A: L80      COM` is a directory entry that
# only the disk holds. DIR stops after one line because CRs are already waiting in the
# keystroke file (d7a-dir.keys).
set -u
. "$(dirname "$0")/lib.sh"

play_want=("loaded 1296 bytes" "MUSIC3.HEX (0100-060F)" "HLT at 0114")
build_want=("MUSIC3 build machine" "56K CP/M 2.2b v2.3" "For Altair 8\" Floppy" "A>" "A: L80      COM")

# From inside its own directory, as the README says.
dir=$(stage d7a)
out=$(run_machine "$dir" "$here/keys/d7a-play.keys" 20 music3.toml)
expect_contains "cd d7a && altairsim music3.toml" "$out" "${play_want[@]}"
out=$(run_machine "$dir" "$here/keys/d7a-dir.keys" 60 music3-build.toml)
expect_contains "cd d7a && altairsim music3-build.toml" "$out" "${build_want[@]}"

# By path from somewhere else: the HEX file and the disk are not in the working directory.
out=$(run_machine "$work/stage" "$here/keys/d7a-play.keys" 20 d7a/music3.toml)
expect_contains "altairsim d7a/music3.toml from the parent" "$out" "${play_want[@]}"
out=$(run_machine "$work/stage" "$here/keys/d7a-dir.keys" 60 d7a/music3-build.toml)
expect_contains "altairsim d7a/music3-build.toml from the parent" "$out" "${build_want[@]}"

finish
