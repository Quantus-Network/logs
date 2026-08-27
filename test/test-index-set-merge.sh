#!/bin/sh
# Isolated check: merge a live Graylog index-set GET with the IaC patch.
# Must produce size-based rotation (5 GiB) and deletion after 10 indices,
# without leftover time-based / size-optimizing fields that Graylog rejects.
set -eu

ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
MERGE_JQ="$ROOT/graylog-index-set-merge.jq"
PATCH="$ROOT/graylog-index-set-default-overrides.json"
FULL="$ROOT/test/fixtures/index-set-from-api.json"
SIZE_BASED_CLASS="org.graylog2.indexer.rotation.strategies.SizeBasedRotationStrategy"
SIZE_BASED_TYPE="org.graylog2.indexer.rotation.strategies.SizeBasedRotationStrategyConfig"
MAX_SIZE=5368709120

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

command -v jq >/dev/null 2>&1 || fail "jq is required"

test -f "$MERGE_JQ" || fail "missing $MERGE_JQ"
test -f "$PATCH" || fail "missing $PATCH"

jq -e --arg class "$SIZE_BASED_CLASS" --arg type "$SIZE_BASED_TYPE" --argjson max "$MAX_SIZE" '
  .rotation_strategy_class == $class
  and .rotation_strategy.type == $type
  and .rotation_strategy.max_size == $max
  and .retention_strategy.max_number_of_indices == 10
' "$PATCH" >/dev/null || fail "patch JSON is not 5 GiB size-based with 10 indices"

MERGED=$(jq -c --slurpfile patch "$PATCH" -f "$MERGE_JQ" "$FULL")

echo "$MERGED" | jq -e --arg class "$SIZE_BASED_CLASS" '
  .rotation_strategy_class == $class
' >/dev/null || fail "merged rotation_strategy_class is not size-based"

echo "$MERGED" | jq -e --argjson max "$MAX_SIZE" '
  .rotation_strategy.max_size == $max
' >/dev/null || fail "merged rotation_strategy.max_size is not 5 GiB (5368709120)"

echo "$MERGED" | jq -e '
  (.rotation_strategy | has("rotation_period") | not)
  and (.rotation_strategy | has("rotate_empty_index_set") | not)
  and (.rotation_strategy | has("index_lifetime_min") | not)
  and (.rotation_strategy | has("index_lifetime_max") | not)
' >/dev/null || fail "merged rotation_strategy still has time-based or size-optimizing fields: $(echo "$MERGED" | jq -c '.rotation_strategy')"

echo "$MERGED" | jq -e '.retention_strategy.max_number_of_indices == 10' >/dev/null \
  || fail "merged retention is not 10 indices"

echo "$MERGED" | jq -e '.use_legacy_rotation == true and .data_tiering == null' >/dev/null \
  || fail "merged use_legacy_rotation/data_tiering not applied from patch"

echo "$MERGED" | jq -e '.id == "default-index-set-id" and .shards == 1 and .replicas == 0' >/dev/null \
  || fail "merged payload dropped identity/shard fields from the API document"

echo "OK"
