#!/usr/bin/env bash
# cpnet/server.toml and cpnet/requester.toml: two machines on one serial line. The requester
# also runs against cpnet/server-ss1.toml, the server with a System Support 1 in place of the
# 88-VI/RTC. That server sets its date from the clock of the board, so its `TOD` prints the
# date of the host.
#
# The server boots MP/M II with the CP/NET server, with no CP/M first. `SERVR0PRRSP` and `NtwrkIP0RSP` are the lines
# of the loader's memory map for the two server processes. The requester boots CP/M 2.2, loads
# CP/NET, and maps its drive B: to drive A: of the server. `B: BNKBDOS  SPR` is the first line of
# DIR B:, and `SPOOL    RSP : MPM      SYS : MPMLDR   COM` ends the last line. Those files are on the
# server disk only.
#
# Each line waits for the prompt (start_machine in lib.sh), because MP/M II discards keys typed
# before its prompt. The server must listen before the requester starts, as the README says.
# DIR B: takes about 11 s.
set -u
. "$(dirname "$0")/lib.sh"

srv_want=("MP/M II V2.1 Loader" "SERVR0PRRSP  C100H  0A00H" "NtwrkIP0RSP  BD00H  0400H" "0A>")
req_want=("CP/NET 1.2 Loader" "SNIOS   SPR  B600H  0300H" "CP/NET 1.2 loading complete."
          "B: BNKBDOS  SPR" "SPOOL    RSP : MPM      SYS : MPMLDR   COM")

net() {   # <cwd> <dir prefix of the machine files> [server machine file]
  start_machine srv 3 "$1" "$2${3:-server.toml}"
  wait_for srv "0A>" 90
  start_machine req 4 "$1" "$2requester.toml"
  wait_for req "A>" 30
  type_line 4 'CPNETLDR\r'
  wait_for req "<Warm Boot>" 30
  type_line 4 'LOGIN\r'
  wait_for req "A>" 30 3
  type_line 4 'NETWORK B:=A:[0]\r'
  wait_for req "A>" 30 4
  type_line 4 'DIR B:\r'
  wait_for req "A>" 90 5
  if [ -n "${3:-}" ]; then
    type_line 3 'TOD\r'
    wait_for srv "0A>" 30 2
  fi
  stop_machine req 4
  stop_machine srv 3
}

# From inside its own directory, as the README says.
dir=$(stage cpnet)
net "$dir" ""
expect_contains "cd cpnet && altairsim server.toml" "$(cat "$work/srv.out")" "${srv_want[@]}"
expect_contains "cd cpnet && altairsim requester.toml" "$(cat "$work/req.out")" "${req_want[@]}"

# The server with the System Support 1.
net "$dir" "" server-ss1.toml
expect_contains "cd cpnet && altairsim server-ss1.toml" "$(cat "$work/srv.out")" \
  "${srv_want[@]}" "$(date '+%a %m/%d/')"
expect_contains "cd cpnet && altairsim requester.toml, with server-ss1.toml" \
  "$(cat "$work/req.out")" "${req_want[@]}"

# By path from somewhere else: the disks are not in the working directory.
net "$work/stage" "cpnet/"
expect_contains "altairsim cpnet/server.toml from the parent" "$(cat "$work/srv.out")" "${srv_want[@]}"
expect_contains "altairsim cpnet/requester.toml from the parent" "$(cat "$work/req.out")" "${req_want[@]}"

# The builds use the sources on SRVBUILD.DSK and REQBUILD.DSK, not the .ASM files beside them.
# Each copy on a disk must be the same bytes as the file in the folder.
disk_has "the sources on SRVBUILD.DSK are the files of the folder" "$dir/SRVBUILD.DSK" "$dir" \
  RESXIOS.ASM SS1XIOS.ASM LDRBIOS.ASM BOOT.ASM AFORMAT.ASM NETWRKIF.ASM
disk_has "the source on REQBUILD.DSK is the file of the folder" "$dir/REQBUILD.DSK" "$dir" SNIOS.ASM

# The DRI files on the build disks are the ones on CPNET.DSK.
dri="$work/cpnet-dri"
req_files=(NDOS.SPR CCP.SPR CPNETLDR.COM NETWORK.COM LOCAL.COM LOGIN.COM LOGOFF.COM CPNETSTS.COM
           DSKRESET.COM ENDLIST.COM MAIL.COM PIP.COM LOGIN.ASM LOGOFF.ASM)
if ! disk_get "$dir/CPNET.DSK" "$dri" "${req_files[@]}" SERVER.RSP; then
  echo "FAIL: CPNET.DSK does not have the requester files and SERVER.RSP" >&2
  failures=$((failures + 1))
else
  disk_has "the requester files on REQBUILD.DSK are the ones on CPNET.DSK" "$dir/REQBUILD.DSK" \
    "$dri" "${req_files[@]}"
  disk_has "SERVER.RSP on SRVBUILD.DSK is the one on CPNET.DSK" "$dir/SRVBUILD.DSK" "$dri" SERVER.RSP
fi

# The folder has its own copies of files of ../mpm2/, so that it stands alone. The copies must
# stay the same as the files in ../mpm2/.
mpm2="$root/examples/mpm2"
bad=0
for f in CPM22.DSK MPMII_1.DSK RESXIOS.ASM SS1XIOS.ASM LDRBIOS.ASM BOOT.ASM AFORMAT.ASM; do
  if ! cmp -s "$dir/$f" "$mpm2/$f"; then
    echo "FAIL: cpnet/$f is not mpm2/$f" >&2
    bad=1
  fi
done
build_files=($(cpmls -f altair "$mpm2/BUILD.DSK" 2> /dev/null | grep -v '^0:$' | tr 'a-z' 'A-Z'))
if [ "${#build_files[@]}" -eq 0 ] || ! disk_get "$mpm2/BUILD.DSK" "$work/mpm2-build" "${build_files[@]}"; then
  echo "FAIL: cannot read mpm2/BUILD.DSK" >&2
  bad=1
fi
if [ "$bad" -eq 0 ]; then
  echo "ok:   the copies of the mpm2 files are the files of ../mpm2/"
else
  failures=$((failures + 1))
fi
disk_has "SRVBUILD.DSK has every file of mpm2/BUILD.DSK" "$dir/SRVBUILD.DSK" "$work/mpm2-build" \
  "${build_files[@]}"

finish
