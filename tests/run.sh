#!/usr/bin/env bash
# Run every machine test against the altairsim on PATH (or $ALTAIRSIM).
#
#   tests/run.sh            all tests
#   tests/run.sh hdsk       just tests/test-hdsk.sh
set -u
cd "$(dirname "$0")"
if [ "$#" -gt 0 ]; then set -- $(for n in "$@"; do echo "test-$n.sh"; done); else set -- test-*.sh; fi
failed=0
for t in "$@"; do
  echo "== $t"
  bash "./$t" || failed=$((failed + 1))
done
[ "$failed" -eq 0 ] && echo "all tests passed" || { echo "$failed test file(s) failed" >&2; exit 1; }
