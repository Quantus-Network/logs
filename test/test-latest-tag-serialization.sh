#!/bin/sh
# :latest is shared. Publishing it from a per-version build, using an eligibility
# decision taken before that build, lets an older version overwrite a newer one.
# Eligibility has to be recomputed from current tags inside one shared queue,
# immediately before the retag.
set -eu

ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
HELPER="$ROOT/.github/scripts/should_promote_latest.sh"
WF="$ROOT/.github/workflows/graylog-init-docker-image.yml"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

test -f "$HELPER" || fail "missing $HELPER"
test -f "$WF" || fail "missing $WF"
command -v git >/dev/null 2>&1 || fail "git is required"

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

git -C "$TMP" init -q
git -C "$TMP" config user.email "test@example.com"
git -C "$TMP" config user.name "test"
git -C "$TMP" commit -q --allow-empty -m init
git -C "$TMP" tag v1.0.0

early=$(cd "$TMP" && bash "$HELPER" v1.0.0) || fail "helper failed for v1.0.0"
if [ "$early" != true ]; then
  fail "v1.0.0 should be eligible before a newer stable tag exists, got '$early'"
fi

git -C "$TMP" tag v1.1.0

# Publication order must not matter once each run rereads tags.
apply_order() {
  latest=
  for ver in "$@"; do
    got=$(cd "$TMP" && bash "$HELPER" "$ver") || fail "helper failed for $ver"
    if [ "$got" = true ]; then
      latest=$ver
    fi
  done
  printf '%s\n' "$latest"
}

result=$(apply_order v1.1.0 v1.0.0)
if [ "$result" != v1.1.0 ]; then
  fail "older publish last rolled :latest back to '$result'"
fi
result=$(apply_order v1.0.0 v1.1.0)
if [ "$result" != v1.1.0 ]; then
  fail "newer publish left :latest at '$result'"
fi

job_body() {
  job=$1
  awk -v job="$job" '
    $0 ~ "^  " job ":$" { capture = 1; next }
    capture && /^  [A-Za-z0-9_]+:$/ { exit }
    capture { print }
  ' "$WF"
}

build=$(job_body build_and_publish_image)
promote=$(job_body promote_latest)
determine=$(job_body determine_version)

test -n "$build" || fail "missing build_and_publish_image job"
test -n "$promote" || fail "missing promote_latest job"
test -n "$determine" || fail "missing determine_version job"

printf '%s\n' "$build" | grep -q 'group: ghcr-graylog-init-${{ needs.determine_version.outputs.version_with_v }}' \
  || fail "versioned image builds must stay serialized per version"
if printf '%s\n' "$build" | grep -E -q ':latest|PROMOTE_LATEST|should_promote_latest'; then
  fail "versioned image build publishes :latest or keeps an early promote decision"
fi
if printf '%s\n' "$determine" | grep -q 'should_promote_latest'; then
  fail "determine_version still decides :latest before the build"
fi
if grep -q 'promote_latest=' "$WF"; then
  fail "workflow stores promote_latest from an earlier job"
fi

printf '%s\n' "$promote" | grep -q 'group: ghcr-graylog-init-latest' \
  || fail "promote job must use one shared concurrency group"
printf '%s\n' "$promote" | grep -q 'cancel-in-progress: false' \
  || fail "promote job must not cancel an in-progress promotion"
printf '%s\n' "$promote" | grep -q 'queue: max' \
  || fail "promote job must keep every queued promotion"
printf '%s\n' "$promote" | grep -q 'needs: \[determine_version, build_and_publish_image\]' \
  || fail "promote job must run after the versioned image exists"
printf '%s\n' "$promote" | grep -F -q "needs.build_and_publish_image.result == 'success'" \
  || fail "promote job must not run when the image build failed"

step=$(printf '%s\n' "$promote" | awk '
  /git fetch --force --tags origin/ { capture = 1 }
  capture { print }
')
test -n "$step" || fail "promotion must fetch tags inside the shared queue"

fetch_line=$(printf '%s\n' "$step" | grep -n 'git fetch --force --tags origin' | head -n 1 | cut -d: -f1)
helper_line=$(printf '%s\n' "$step" | grep -n 'should_promote_latest.sh' | head -n 1 | cut -d: -f1)
push_line=$(printf '%s\n' "$step" | grep -n 'imagetools create' | head -n 1 | cut -d: -f1)
latest_line=$(printf '%s\n' "$step" | grep -n -- '-t "${GHCR_IMAGE_PATH}:latest"' | head -n 1 | cut -d: -f1)

test -n "$fetch_line" || fail "promotion step does not fetch tags"
test -n "$helper_line" || fail "promotion step does not recompute eligibility"
test -n "$push_line" || fail "promotion step does not retag :latest"
test -n "$latest_line" || fail "promotion step does not name the :latest tag"
test "$fetch_line" -lt "$helper_line" || fail "tag fetch must precede the eligibility check"
test "$helper_line" -lt "$push_line" || fail "eligibility check must precede :latest publication"
test "$push_line" -lt "$latest_line" || fail ":latest tag must be the imagetools target"

echo "OK"
