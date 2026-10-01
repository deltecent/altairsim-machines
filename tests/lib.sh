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
# <dir>/<dir>.zip -- the file CI builds and people download -- and a missing zip is a failure.
stage() {
  mkdir -p "$work/stage"
  if [ "${MACHINE_SOURCE:-dir}" = zip ]; then
    [ -f "$root/$1/$1.zip" ] || { echo "tests: $1/$1.zip does not exist -- has CI built it? (git pull)" >&2; exit 2; }
    unzip -q "$root/$1/$1.zip" -d "$work/stage"
  else
    cp -R "$root/$1" "$work/stage/"
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

finish() {
  [ "$failures" -eq 0 ] && exit 0
  echo "$failures check(s) failed" >&2
  exit 1
}
