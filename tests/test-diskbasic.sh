#!/usr/bin/env bash
# diskbasic/diskbasic.toml boots Altair Disk Extended BASIC 4.1 off an 8" floppy.
#
# The keystroke file (diskbasic-files.keys) answers the five startup questions, types PRINT 5Q_
# (the _ deletes the Q, so BASIC prints 5), then types MOUNT 0 and FILES. `STARTREK` and `OTHELLO`
# are directory entries that only the disk holds.
set -u
. "$(dirname "$0")/lib.sh"

keys="$here/keys/diskbasic-files.keys"
want=("ALTAIR BASIC REV. 4.1" "[DISK EXTENDED VERSION]" "OK" " 5 " "STARTREK" "OTHELLO")

# From inside its own directory, as the README says.
dir=$(stage diskbasic)
out=$(run_machine "$dir" "$keys" 60 diskbasic.toml)
expect_contains "cd diskbasic && altairsim diskbasic.toml" "$out" "${want[@]}"

# By path from somewhere else: the disk is not in the working directory, so this proves the
# machine file's paths resolve against the file.
out=$(run_machine "$work/stage" "$keys" 60 diskbasic/diskbasic.toml)
expect_contains "altairsim diskbasic/diskbasic.toml from the parent" "$out" "${want[@]}"

finish
