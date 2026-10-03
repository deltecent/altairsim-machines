#!/usr/bin/env bash
# icom/ boots CP/M and both revisions of FDOS off the iCOM FD3712/FD3812 controller.
#
# Each machine runs its boot PROM, which reads the operating system off the disk. The banner and
# the prompt come from that system. The directory line is read off the disk through the controller:
# CP/M prints `A: ASM      COM`, FDOS-III prints its `LIST` table, and FDOS-I prints the `L`
# listing (`01  DEMO1.ASM   0B`). FDOS-III takes word commands and FDOS-I takes single letters, so
# the two have their own keystroke files. DIR and L stop after one listing because the extra CRs
# wait in the keystroke file.
set -u
. "$(dirname "$0")/lib.sh"

cpm="$here/keys/icom-cpm-dir.keys"
fdos3="$here/keys/icom-fdos-iii-list.keys"
fdos1="$here/keys/icom-fdos-i-list.keys"

check() {
  local dir=$1 prefix=$2 out
  out=$(run_machine "$dir" "$cpm" 40 cpm22.toml)
  expect_contains "${prefix}cpm22.toml" "$out" "48K CP/M 2.2 v1.0" "for iCOM FD3712 and Altair" "A>DIR" "A: ASM      COM"
  out=$(run_machine "$dir" "$cpm" 40 cpm22-3812.toml)
  expect_contains "${prefix}cpm22-3812.toml" "$out" "48K CP/M 2.23" "iCOM 3812 Double Density Floppy" "A>DIR" "A: WS       COM"
  out=$(run_machine "$dir" "$fdos3" 40 fdos-iii.toml)
  expect_contains "${prefix}fdos-iii.toml" "$out" "ICOM FDOS-III ALTAIR/IMSAI VER. 1.0" "!LIST" "EDIT    00   04   16" "00888 SECTORS FREE"
  out=$(run_machine "$dir" "$fdos1" 40 fdos-i.toml)
  expect_contains "${prefix}fdos-i.toml" "$out" "!L" "01  DEMO1.ASM   0B" "07  COMMANDS    02"
}

# From inside its own directory, as the README says.
dir=$(stage icom)
check "$dir" "cd icom && altairsim "

# By path from somewhere else: the disks are not in the working directory, so this proves the
# machine files' paths resolve against the file.
out=$(run_machine "$work/stage" "$cpm" 40 icom/cpm22.toml)
expect_contains "altairsim icom/cpm22.toml from the parent" "$out" "48K CP/M 2.2 v1.0" "A: ASM      COM"
out=$(run_machine "$work/stage" "$fdos3" 40 icom/fdos-iii.toml)
expect_contains "altairsim icom/fdos-iii.toml from the parent" "$out" "ICOM FDOS-III ALTAIR/IMSAI VER. 1.0" "00888 SECTORS FREE"

finish
