#!/usr/bin/env bash
# pb1/pb1.toml is an Altair with an SSM PB1 EPROM programmer and the SSM 8080 monitor in a ROM.
#
# First the machine file as shipped: the monitor cold-starts and prints its banner and prompt.
# Then the burn. Keystrokes cannot reach the altairsim> prompt, so the test copies the machine file
# and adds the steps of the README to its startup list: 1K of A5 at 4000, then the burner and the
# two check programs. Then pb1-burn.keys types the four monitor commands of the README:
#   G140 -- the erase check prints P: the chip is erased
#   G100 -- the burner prints nothing, and the monitor comes back
#   G180 -- the verify prints P: the chip holds the data
#   G140 -- the erase check prints F: the chip is not erased now
# The P and F are printed by the SSM programs through the monitor, so they can only come from the
# guest. The test does not need a prompt wait: the guest reads each command when it is ready.
set -u
. "$(dirname "$0")/lib.sh"

keys="$here/keys/pb1-burn.keys"
banner=$'MONITOR V1.0\r\n.'
burn=$'.G140\r\r\nP\r\nMONITOR V1.0\r\n.G100\r\r\n\r\nMONITOR V1.0\r\n.G180\r\r\nP\r\nMONITOR V1.0\r\n.G140\r\r\nF\r\nMONITOR V1.0\r\n.'

dir=$(stage pb1)

# The machine file as shipped. The NUL bytes (pb1-boot.keys) keep the input open until the SSM
# monitor has printed its banner.
out=$(run_machine "$dir" "$here/keys/pb1-boot.keys" 20 pb1.toml)
expect_contains "cd pb1 && altairsim pb1.toml (monitor banner)" "$out" "$banner"

# The same machine with the burn steps in its startup list.
sed 's|^startup .*|startup = ["FILL 4000-43FF A5", "LOAD PROG2708.HEX", "LOAD ERACHK.HEX", "LOAD CPYVFY.HEX", "RUN F000"]|' \
  "$dir/pb1.toml" > "$dir/pb1-burn.toml"
grep -q '^startup = \["FILL' "$dir/pb1-burn.toml" || { echo "FAIL: pb1: startup line not changed" >&2; failures=$((failures + 1)); }

out=$(run_machine "$dir" "$keys" 20 pb1-burn.toml)
expect_contains "cd pb1 && altairsim pb1-burn.toml (erase check, burn, verify)" "$out" "$burn"

# By path from somewhere else: the HEX files are not in the working directory, so this proves the
# machine file's paths resolve against the file.
out=$(run_machine "$work/stage" "$keys" 20 pb1/pb1-burn.toml)
expect_contains "altairsim pb1/pb1-burn.toml from the parent" "$out" "$burn"

finish
