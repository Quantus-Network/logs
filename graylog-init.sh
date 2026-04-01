#!/bin/sh
set -eu

PATCH_FILE=/opt/graylog-init/index-set-default-overrides.json

echo "graylog-init running as: $(id)"
echo 'Waiting for Graylog API to be fully ready...'

COUNTER=0
MAX_TRIES=60
until curl -s -f -u "${GRAYLOG_USER}:${GRAYLOG_PASSWORD}" "${GRAYLOG_API}/system/lbstatus" > /dev/null 2>&1; do
  COUNTER=$((COUNTER + 1))
  if [ "$COUNTER" -gt "$MAX_TRIES" ]; then
    echo "ERROR: Graylog API did not become ready in time"
    exit 1
  fi
  echo "Waiting for API... attempt ${COUNTER}/${MAX_TRIES}"
  sleep 5
done

echo 'API responding, waiting extra 30 seconds for full initialization...'
sleep 30

echo 'Importing inputs...'
jq -c '.inputs[]' /inputs.json | while read -r input; do
  TITLE=$(echo "$input" | jq -r '.title')
  echo "Creating input: $TITLE"

  RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "${GRAYLOG_API}/system/inputs" \
    -H "Content-Type: application/json" \
    -H "X-Requested-By: cli" \
    -u "${GRAYLOG_USER}:${GRAYLOG_PASSWORD}" \
    -d "$input")

  HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
  BODY=$(echo "$RESPONSE" | sed '$d')

  if [ "$HTTP_CODE" = "201" ]; then
    echo "✓ Successfully created: $TITLE"
  elif [ "$HTTP_CODE" = "400" ] && echo "$BODY" | grep -q "already exists"; then
    echo "ℹ Input already exists: $TITLE"
  else
    echo "✗ Failed to create $TITLE (HTTP $HTTP_CODE)"
    echo "Response: $BODY"
  fi
done

echo '✓ Input import completed!'

echo 'Applying default index set overrides (rotation + retention)...'
if ! test -r "$PATCH_FILE"; then
  echo "✗ Cannot read patch file at $PATCH_FILE"
  exit 1
fi

LIST=$(curl -s -u "${GRAYLOG_USER}:${GRAYLOG_PASSWORD}" "${GRAYLOG_API}/system/indices/index_sets")
DEFAULT_ID=$(echo "$LIST" | jq -r '.index_sets[]? | select(.default == true) | .id' | head -n1)
if [ -z "$DEFAULT_ID" ] || [ "$DEFAULT_ID" = "null" ]; then
  echo '✗ No default index set found (expected exactly one with default=true)'
  exit 1
fi

FULL=$(curl -s -u "${GRAYLOG_USER}:${GRAYLOG_PASSWORD}" "${GRAYLOG_API}/system/indices/index_sets/${DEFAULT_ID}")
# Build rotation/retention objects from patch fields only — never assign $p.rotation_strategy as a
# blob (some jq/API paths left stale keys like index_lifetime_min inside the nested object).
MERGED=$(echo "$FULL" | jq -c --slurpfile patch "$PATCH_FILE" '
  ($patch[0]) as $p
  | del(.rotation_strategy, .retention_strategy)
  | .rotation_strategy = (
      {
        type: $p.rotation_strategy.type,
        rotation_period: $p.rotation_strategy.rotation_period,
        rotate_empty_index_set: $p.rotation_strategy.rotate_empty_index_set
      }
      + (if ($p.rotation_strategy | has("max_rotation_period")) and ($p.rotation_strategy.max_rotation_period != null)
         then {max_rotation_period: $p.rotation_strategy.max_rotation_period} else {} end)
    )
  | .retention_strategy = {
      type: $p.retention_strategy.type,
      max_number_of_indices: $p.retention_strategy.max_number_of_indices
    }
  | .rotation_strategy_class = $p.rotation_strategy_class
  | .retention_strategy_class = $p.retention_strategy_class
  | .use_legacy_rotation = $p.use_legacy_rotation
  | .data_tiering = $p.data_tiering
')
RESPONSE=$(curl -s -w "\n%{http_code}" -X PUT "${GRAYLOG_API}/system/indices/index_sets/${DEFAULT_ID}" \
  -H "Content-Type: application/json" \
  -H "X-Requested-By: cli" \
  -u "${GRAYLOG_USER}:${GRAYLOG_PASSWORD}" \
  -d "$MERGED")

HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | sed '$d')
if [ "$HTTP_CODE" = "200" ]; then
  echo '✓ Default index set updated (rotation + retention; JSON baked into graylog-init image)'
else
  echo "✗ Index set update failed (HTTP $HTTP_CODE)"
  echo "Response: $BODY"
  exit 1
fi
