#!/bin/sh
# Isolated check: a registry manifest probe is exists, not_found, or error.
# Auth and DNS failures must not be classified as a missing tag.
set -eu

ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
SCRIPT="$ROOT/.github/scripts/classify_manifest_probe.sh"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

test -f "$SCRIPT" || fail "missing $SCRIPT"

assert_class() {
  status="$1"
  body="$2"
  expected="$3"
  got=$(printf '%s\n' "$body" | bash "$SCRIPT" "$status") || fail "classifier exited non-zero for status $status"
  if [ "$got" != "$expected" ]; then
    fail "status $status body '$body': expected $expected, got '$got'"
  fi
}

assert_class 0 "" exists
assert_class 1 "manifest unknown" not_found
assert_class 1 "no such host" error
assert_class 1 "unauthorized: authentication required" error

echo "OK"
