#!/bin/sh
# Empty version input must select by SemVer precedence.
# Git --sort=-v:refname ranks v1.2.3-rc.1 above v1.2.3, so the default
# release path republishes the candidate instead of the final release.
set -eu

ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
WF="$ROOT/.github/workflows/graylog-init-docker-image.yml"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

test -f "$WF" || fail "missing $WF"
command -v git >/dev/null 2>&1 || fail "git is required"
command -v bash >/dev/null 2>&1 || fail "bash is required"

STEP=$(awk '
  $0 ~ /^      - name: Get version information$/ { found = 1 }
  found && $0 ~ /^        run: \|$/ { capture = 1; next }
  capture && $0 ~ /^          / { sub(/^          /, ""); print; next }
  capture && $0 ~ /^$/ { print; next }
  capture { exit }
' "$WF")

test -n "$STEP" || fail "could not extract Get version information step"
printf '%s\n' "$STEP" | grep -q 'SPECIFIC_VERSION' || fail "extracted step is not version selection"

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

mkdir -p "$TMP/.github/scripts"
cp "$ROOT/.github/scripts/"*.sh "$TMP/.github/scripts/"

git -C "$TMP" init -q
git -C "$TMP" config user.email "test@example.com"
git -C "$TMP" config user.name "test"
git -C "$TMP" commit -q --allow-empty -m init

clear_tags() {
  git -C "$TMP" tag -l | while IFS= read -r tag; do
    [ -n "$tag" ] || continue
    git -C "$TMP" tag -d "$tag" >/dev/null
  done
}

select_default() {
  clear_tags
  for tag in "$@"; do
    git -C "$TMP" tag "$tag"
  done
  out="$TMP/github_output"
  : > "$out"
  if ! (
    cd "$TMP"
    SPECIFIC_VERSION= GITHUB_OUTPUT="$out" bash -c "$STEP"
  ) >"$TMP/step.out" 2>"$TMP/step.err"; then
    cat "$TMP/step.err" >&2
    fail "Get version information step failed for: $*"
  fi
  got=$(grep '^version_with_v=' "$out" | head -n 1 | cut -d= -f2- || true)
  valid=$(grep '^is_valid_version=' "$out" | head -n 1 | cut -d= -f2- || true)
  [ "$valid" = true ] || fail "is_valid_version='$valid' for: $*"
  [ -n "$got" ] || fail "version_with_v missing for: $*"
  printf '%s\n' "$got"
}

assert_default() {
  expected=$1
  shift
  got=$(select_default "$@") || exit 1
  if [ "$got" != "$expected" ]; then
    fail "tags ($*): expected $expected, got '$got'"
  fi
}

# Candidate tagged first, final release afterward.
assert_default v1.2.3 v1.2.3-rc.1 v1.2.3

# Creation order is not precedence.
assert_default v1.2.3 v1.2.3 v1.2.3-rc.1

# Core versions compare numerically, and a newer prerelease still beats an older final.
assert_default v1.10.0 v1.9.0 v1.10.0
assert_default v1.3.0-rc.1 v1.2.3 v1.3.0-rc.1
assert_default v1.2.3-rc.10 v1.2.3-rc.2 v1.2.3-rc.10

# Spec chain: the final release is the greatest, above every prerelease of the same core.
assert_default v1.0.0 \
  v1.0.0-alpha \
  v1.0.0-alpha.1 \
  v1.0.0-alpha.beta \
  v1.0.0-beta \
  v1.0.0-beta.2 \
  v1.0.0-beta.11 \
  v1.0.0-rc.1 \
  v1.0.0

# A non-numeric identifier outranks a numeric one even when ASCII would not.
assert_default v1.0.0--1 v1.0.0-1 v1.0.0--1

# Leading zeros do not end the comparison while later identifiers still differ.
assert_default v1.0.0-1.10 v1.0.0-01.2 v1.0.0-1.10

# An explicit version is used as given.
clear_tags
git -C "$TMP" tag v1.2.3-rc.1
git -C "$TMP" tag v1.2.3
out="$TMP/github_output"
: > "$out"
if ! (
  cd "$TMP"
  SPECIFIC_VERSION=v1.0.0 GITHUB_OUTPUT="$out" bash -c "$STEP"
) >"$TMP/step.out" 2>"$TMP/step.err"; then
  cat "$TMP/step.err" >&2
  fail "specific version step failed"
fi
got=$(grep '^version_with_v=' "$out" | head -n 1 | cut -d= -f2- || true)
if [ "$got" != v1.0.0 ]; then
  fail "specific version was ignored, got '$got'"
fi

echo "OK"
