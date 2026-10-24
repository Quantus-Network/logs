#!/bin/sh
# The index-set patch is built from deploy env, not a baked JSON file.
# Rotation size and index count must be positive integers with no leading zeros.
set -eu

ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
PATCH_SH="$ROOT/graylog-index-set-patch.sh"
MAX_SIZE=10737418240
MAX_INDICES=10

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

command -v jq >/dev/null 2>&1 || fail "jq is required"
test -x "$PATCH_SH" || fail "missing executable $PATCH_SH"

expect_fail() {
  label=$1
  shift
  if "$@" >/dev/null 2>&1; then
    fail "$label should fail"
  fi
}

expect_fail "missing both limits" \
  env -u GRAYLOG_INDEX_MAX_SIZE_BYTES -u GRAYLOG_INDEX_MAX_INDICES "$PATCH_SH"

expect_fail "missing max size" \
  env -u GRAYLOG_INDEX_MAX_SIZE_BYTES GRAYLOG_INDEX_MAX_INDICES=$MAX_INDICES "$PATCH_SH"

expect_fail "missing index count" \
  env -u GRAYLOG_INDEX_MAX_INDICES GRAYLOG_INDEX_MAX_SIZE_BYTES=$MAX_SIZE "$PATCH_SH"

expect_fail "zero max size" \
  env GRAYLOG_INDEX_MAX_SIZE_BYTES=0 GRAYLOG_INDEX_MAX_INDICES=$MAX_INDICES "$PATCH_SH"

expect_fail "zero index count" \
  env GRAYLOG_INDEX_MAX_SIZE_BYTES=$MAX_SIZE GRAYLOG_INDEX_MAX_INDICES=0 "$PATCH_SH"

expect_fail "non-integer max size" \
  env GRAYLOG_INDEX_MAX_SIZE_BYTES=10GiB GRAYLOG_INDEX_MAX_INDICES=$MAX_INDICES "$PATCH_SH"

expect_fail "leading zero max size" \
  env GRAYLOG_INDEX_MAX_SIZE_BYTES=010 GRAYLOG_INDEX_MAX_INDICES=$MAX_INDICES "$PATCH_SH"

OUT=$(env GRAYLOG_INDEX_MAX_SIZE_BYTES=$MAX_SIZE GRAYLOG_INDEX_MAX_INDICES=$MAX_INDICES "$PATCH_SH")

echo "$OUT" | jq -e --argjson max "$MAX_SIZE" --argjson indices "$MAX_INDICES" '
  .use_legacy_rotation == true
  and .data_tiering == null
  and .rotation_strategy_class == "org.graylog2.indexer.rotation.strategies.SizeBasedRotationStrategy"
  and .rotation_strategy.type == "org.graylog2.indexer.rotation.strategies.SizeBasedRotationStrategyConfig"
  and .rotation_strategy.max_size == $max
  and (.rotation_strategy | keys == ["max_size", "type"])
  and .retention_strategy_class == "org.graylog2.indexer.retention.strategies.DeletionRetentionStrategy"
  and .retention_strategy.type == "org.graylog2.indexer.retention.strategies.DeletionRetentionStrategyConfig"
  and .retention_strategy.max_number_of_indices == $indices
' >/dev/null || fail "patch JSON is not 10 GiB size-based with 10 indices: $OUT"

echo "OK"
