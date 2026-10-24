#!/bin/sh
# Print the default index-set patch from deploy env.
# Size-based rotation and deletion retention stay fixed; only the two limits vary.
set -eu

fail() {
  echo "✗ $1" >&2
  exit 1
}

require_positive_int() {
  name=$1
  value=$2
  case $value in
    ''|*[!0-9]*|0*)
      fail "$name must be a positive integer with no leading zeros (got '${value}')"
      ;;
  esac
}

: "${GRAYLOG_INDEX_MAX_SIZE_BYTES:?GRAYLOG_INDEX_MAX_SIZE_BYTES is required}"
: "${GRAYLOG_INDEX_MAX_INDICES:?GRAYLOG_INDEX_MAX_INDICES is required}"

require_positive_int GRAYLOG_INDEX_MAX_SIZE_BYTES "$GRAYLOG_INDEX_MAX_SIZE_BYTES"
require_positive_int GRAYLOG_INDEX_MAX_INDICES "$GRAYLOG_INDEX_MAX_INDICES"

jq -n \
  --argjson max_size "$GRAYLOG_INDEX_MAX_SIZE_BYTES" \
  --argjson max_indices "$GRAYLOG_INDEX_MAX_INDICES" \
  '{
    use_legacy_rotation: true,
    data_tiering: null,
    rotation_strategy_class: "org.graylog2.indexer.rotation.strategies.SizeBasedRotationStrategy",
    rotation_strategy: {
      type: "org.graylog2.indexer.rotation.strategies.SizeBasedRotationStrategyConfig",
      max_size: $max_size
    },
    retention_strategy_class: "org.graylog2.indexer.retention.strategies.DeletionRetentionStrategy",
    retention_strategy: {
      type: "org.graylog2.indexer.retention.strategies.DeletionRetentionStrategyConfig",
      max_number_of_indices: $max_indices
    }
  }'
