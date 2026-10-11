#!/usr/bin/env bash
# fujinet/fujinet.toml boots CP/M 2.2b off the 88-DCDD with a FujiNet on 88-2SIO channel B.
#
# This tests the boot path and the second disk: DBL loads CP/M, then CP/M reads the directory of
# drive B. `B: FUJIDIR  PRN` is a directory entry that only PRN.DSK holds. DIR stops after one line
# because a CR is already waiting in the keystroke file (fujinet-dir.keys).
#
# The shipped machine file names a real serial device, and that name is different on each computer.
# The test changes the `connect` line in its scratch copy to a socket that nothing listens on.
# The FujiNet itself is not tested: it needs an adapter, or FujiNet-PC, on the other end.
set -u
. "$(dirname "$0")/lib.sh"

keys="$here/keys/fujinet-dir.keys"
want=("56K CP/M 2.2b v2.3" "For Altair 8\" Floppy" "A>DIR B:" "B: FUJIDIR  PRN")

# From inside its own directory, as the README says.
dir=$(stage fujinet)
sed 's|^\( *connect *= *\)"serial:[^"]*"|\1"socket:localhost:1985"|' "$dir/fujinet.toml" > "$dir/fujinet.test" && mv "$dir/fujinet.test" "$dir/fujinet.toml"
grep -q 'socket:localhost:1985' "$dir/fujinet.toml" || { echo "FAIL: test could not change the connect line" >&2; failures=$((failures + 1)); }
out=$(run_machine "$dir" "$keys" 60 fujinet.toml)
expect_contains "cd fujinet && altairsim fujinet.toml" "$out" "${want[@]}"

# By path from somewhere else: the disks are not in the working directory.
out=$(run_machine "$work/stage" "$keys" 60 fujinet/fujinet.toml)
expect_contains "altairsim fujinet/fujinet.toml from the parent" "$out" "${want[@]}"

finish
