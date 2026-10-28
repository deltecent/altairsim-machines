# Shared helpers for the machine tests. Source this file; do not run it.
#
# The simulator under test is the `altairsim` found on PATH, or the binary named by $ALTAIRSIM.

here=$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)
root=$(cd "$here/.." && pwd)

SIM=${ALTAIRSIM:-$(command -v altairsim || true)}
[ -n "$SIM" ] && [ -x "$SIM" ] || { echo "tests: no altairsim on PATH (or set ALTAIRSIM=/path/to/altairsim)" >&2; exit 2; }

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
failures=0

# stage <dir> -- put a machine directory in a scratch directory and print the path.
# Tests never run in the tracked tree: CP/M writes to the disk, and the image must stay as committed.
#
# By default the directory is copied. With MACHINE_SOURCE=zip the machine is instead UNZIPPED from
# examples/<dir>/<dir>.zip -- the file CI builds and people download -- and a missing zip is a failure.
stage() {
  mkdir -p "$work/stage"
  if [ "${MACHINE_SOURCE:-dir}" = zip ]; then
    [ -f "$root/examples/$1/$1.zip" ] || { echo "tests: examples/$1/$1.zip does not exist -- has CI built it? (git pull)" >&2; exit 2; }
    unzip -q "$root/examples/$1/$1.zip" -d "$work/stage"
  else
    cp -R "$root/examples/$1" "$work/stage/"
  fi
  echo "$work/stage/$1"
}

# run_machine <cwd> <keys-file> <seconds> <machine-file> -- run the simulator with the keystrokes
# on stdin and print everything it wrote. macOS has no timeout(1), so the clock is done here.
run_machine() {
  local cwd=$1 keys=$2 secs=$3 toml=$4 out="$work/out.$$.$RANDOM" pid i
  ( cd "$cwd" && exec "$SIM" "$toml" < "$keys" > "$out" 2>&1 ) &
  pid=$!
  for i in $(seq 1 "$secs"); do
    kill -0 "$pid" 2> /dev/null || break
    sleep 1
  done
  kill "$pid" 2> /dev/null || true
  wait "$pid" 2> /dev/null || true
  cat "$out"
}

# expect_contains <label> <output> <text>... -- every text must appear in the output.
expect_contains() {
  local label=$1 out=$2 want bad=0
  shift 2
  for want in "$@"; do
    case "$out" in
      *"$want"*) ;;
      *) echo "FAIL: $label: '$want' never reached the terminal" >&2; bad=1 ;;
    esac
  done
  if [ "$bad" -eq 1 ]; then
    echo "--- output ---" >&2
    echo "$out" >&2
    echo "--------------" >&2
    failures=$((failures + 1))
  else
    echo "ok:   $label"
  fi
}

# A machine that is typed at line by line, for a guest that discards keys typed before its
# prompt (MP/M II does). Its keyboard is a FIFO that stays open, so the machine keeps running
# while it waits for the next line. The fd is a number from 3 to 9, one for each machine.
#
#   start_machine <name> <fd> <cwd> <machine-file>
#   wait_for <name> <text> <seconds> [<count>]   -- wait until <text> appears <count> times
#   type_line <fd> <text>                        -- printf <text> to the machine's keyboard
#   stop_machine <name> <fd>                     -- end it; its output is in "$work/<name>.out"
start_machine() {
  local name=$1 fd=$2 cwd=$3 toml=$4
  rm -f "$work/$name.in" "$work/$name.out"
  mkfifo "$work/$name.in"
  ( cd "$cwd" && exec "$SIM" "$toml" < "$work/$name.in" > "$work/$name.out" 2>&1 ) &
  eval "pid_$name=$!"
  eval "exec $fd>\"\$work/\$name.in\""
}

wait_for() {
  local name=$1 text=$2 secs=$3 count=${4:-1} i n
  for i in $(seq 1 "$secs"); do
    # -a: a guest can send a NUL (the PS II monitor does), and grep then counts no matches.
    n=$(grep -aoF -- "$text" "$work/$name.out" 2> /dev/null | wc -l)
    [ "$n" -ge "$count" ] && return 0
    sleep 1
  done
  return 1
}

type_line() {
  printf '%b' "$2" >&"$1"
}

stop_machine() {
  local name=$1 fd=$2 pid
  eval "pid=\$pid_$name"
  kill "$pid" 2> /dev/null || true
  wait "$pid" 2> /dev/null || true
  eval "exec $fd>&-"
}

# disk_get <disk> <dest> <file>... -- copy files off an 88-DCDD disk image with cpmtools. The
# return status is 1 when a file is not on the disk.
disk_get() {
  local dsk=$1 dest=$2 f lc
  shift 2
  mkdir -p "$dest"
  for f in "$@"; do
    lc=$(echo "$f" | tr 'A-Z' 'a-z')
    cpmcp -f altair "$dsk" "0:$lc" "$dest/$f" 2> /dev/null || return 1
  done
}

# disk_has <label> <disk> <dir> <file>... -- each file on the 88-DCDD disk image must be the same
# bytes as <dir>/<file>, up to Ctrl-Z bytes that fill its last record. R and PIP fill a text
# file that way. cpmcp (cpmtools) reads the disk.
disk_has() {
  local label=$1 dsk=$2 dir=$3 f n bad=0 got="$work/disk.$RANDOM"
  shift 3
  if ! command -v cpmcp > /dev/null; then
    echo "FAIL: $label: no cpmcp on PATH (install cpmtools)" >&2
    failures=$((failures + 1))
    return
  fi
  for f in "$@"; do
    if ! disk_get "$dsk" "$got" "$f"; then
      echo "FAIL: $label: $(basename "$dsk") has no $f" >&2
      bad=1
    elif n=$(wc -c < "$dir/$f"); ! head -c "$n" "$got/$f" | cmp -s "$dir/$f" - ||
         [ -n "$(tail -c +$((n + 1)) "$got/$f" | tr -d '\032')" ]; then
      echo "FAIL: $label: $f on $(basename "$dsk") is not $dir/$f" >&2
      bad=1
    fi
  done
  if [ "$bad" -eq 0 ]; then
    echo "ok:   $label"
  else
    failures=$((failures + 1))
  fi
}

finish() {
  [ "$failures" -eq 0 ] && exit 0
  echo "$failures check(s) failed" >&2
  exit 1
}
