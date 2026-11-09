#!/usr/bin/env bash
# Six Vector Graphic machines with the Micropolis Disk Controller. Each one boots from the
# Vector Graphic Monitor when B is typed.
#
# The four vgmz machines have a serial console. Each test checks the banner that the disk prints,
# and the prompt. The CP/M machines also read the directory: `A: SYSGEN   COM` is a directory
# entry that only the disk holds.
#
# The two vg3vip machines show their console on the Flashwriter II screen, so nothing that the
# guest prints reaches the terminal. Their test is that the machine file loads and RUNs. What the
# window shows is not checked.
set -u
. "$(dirname "$0")/lib.sh"

keys="$here/keys/vg-dir.keys"
cpm14=("*B" "CP/M ON VECTOR MZ" "46K VERSION 1.411" "LIFEBOAT ASSOCIATES" "A>" "A: SYSGEN   COM")

# From inside its own directory, as the README says.
dir=$(stage vg)
out=$(run_machine "$dir" "$keys" 30 cpm14-lifeboat.toml)
expect_contains "cd vg && altairsim cpm14-lifeboat.toml" "$out" "${cpm14[@]}"

out=$(run_machine "$dir" "$keys" 30 cpm22-lifeboat-56k.toml)
expect_contains "cd vg && altairsim cpm22-lifeboat-56k.toml" "$out" \
  "VECTOR GRAPHIC MONITOR VERSION 4.0 C" "Mon>" "CP/M2 on Micropolis" "56K Vers 2.20B" "A>" "A: SYSGEN   COM"

out=$(run_machine "$dir" "$keys" 30 mdos30.toml 2> /dev/null | tr -d '\000')
expect_contains "cd vg && altairsim mdos30.toml" "$out" "*B" "MICROPOLIS MDOS VS 3.0 - COPYRIGHT 1978" ">DIR"

out=$(run_machine "$dir" "$keys" 30 mdos40.toml)
expect_contains "cd vg && altairsim mdos40.toml" "$out" "*B" "MICROPOLIS MDOS VS 4.0 - COPYRIGHT 1978" ">DIR"

out=$(run_machine "$dir" /dev/null 10 cpm22-56k.toml)
expect_contains "cd vg && altairsim cpm22-56k.toml" "$out" "fw0   vgfwii" "startup> RUN" "[console"

out=$(run_machine "$dir" /dev/null 10 mdos40-56k.toml)
expect_contains "cd vg && altairsim mdos40-56k.toml" "$out" "fw0   vgfwii" "startup> RUN" "[console"

# By path from somewhere else: the disk is not in the working directory, so this proves the
# machine file's paths resolve against the file.
out=$(run_machine "$work/stage" "$keys" 30 vg/cpm14-lifeboat.toml)
expect_contains "altairsim vg/cpm14-lifeboat.toml from the parent" "$out" "${cpm14[@]}"

finish
