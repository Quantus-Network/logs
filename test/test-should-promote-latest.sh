#!/bin/sh
# Isolated check: :latest is only for the newest stable tag.
# An older stable tag and a prerelease must not promote.
set -eu

ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
SCRIPT="$ROOT/.github/scripts/should_promote_latest.sh"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

test -f "$SCRIPT" || fail "missing $SCRIPT"
command -v git >/dev/null 2>&1 || fail "git is required"

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

git -C "$TMP" init -q
git -C "$TMP" config user.email "test@example.com"
git -C "$TMP" config user.name "test"
git -C "$TMP" commit -q --allow-empty -m init
git -C "$TMP" tag v1.0.0
git -C "$TMP" tag v1.2.3
git -C "$TMP" tag v1.2.3-rc.1

assert_promote() {
  selected="$1"
  expected="$2"
  got=$(cd "$TMP" && bash "$SCRIPT" "$selected") || fail "promote script exited non-zero for $selected"
  if [ "$got" != "$expected" ]; then
    fail "$selected: expected $expected, got '$got'"
  fi
}

assert_promote v1.2.3 true
assert_promote v1.0.0 false
assert_promote v1.2.3-rc.1 false

echo "OK"
