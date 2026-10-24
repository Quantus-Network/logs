#!/bin/sh
set -eu

# Defaults match the image. Tests override them; Compose leaves them unset.
PATCH_SH=${GRAYLOG_INIT_PATCH_SH:-/opt/graylog-init/index-set-patch.sh}
MERGE_JQ=${GRAYLOG_INIT_MERGE_JQ:-/opt/graylog-init/index-set-merge.jq}
INPUTS_JSON=${GRAYLOG_INIT_INPUTS_JSON:-/inputs.json}
READY_SLEEP=${GRAYLOG_INIT_READY_SLEEP_SECONDS:-30}
# Bump when init behavior changes (verify in logs after rebuild).
INIT_SCRIPT_REV=7

echo "graylog-init rev=${INIT_SCRIPT_REV} running as: $(id)"

if ! test -x "$PATCH_SH"; then
  echo "✗ Cannot run patch script at $PATCH_SH"
  exit 1
fi
if ! test -r "$MERGE_JQ"; then
  echo "✗ Cannot read merge filter at $MERGE_JQ"
  exit 1
fi
if ! test -r "$INPUTS_JSON"; then
  echo "✗ Cannot read inputs file at $INPUTS_JSON"
  exit 1
fi

# Reject bad limits before any API call. A failed re-run must not create an input.
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
PATCH_TMP=$WORK/patch.json
INPUTS_LIST_TMP=$WORK/inputs.json
INPUTS_LINES_TMP=$WORK/input-lines.json
FULL_TMP=$WORK/index-set.json

echo 'Checking rotation limits...'
"$PATCH_SH" > "$PATCH_TMP"
if ! jq -e '.rotation_strategy.max_size != null and .rotation_strategy.max_size > 0' "$PATCH_TMP" >/dev/null; then
  echo "✗ Patch is missing rotation_strategy.max_size (size-based rotation required)"
  exit 1
fi

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

echo 'API responding, waiting extra '"${READY_SLEEP}"' seconds for full initialization...'
sleep "$READY_SLEEP"

# Graylog 7.0.5 POST /system/inputs saves another input and returns 201.
# It does not report that the title already exists. List first and create
# only when this title and type are absent, so a rotation re-run cannot add
# a second listener on the same port.
echo 'Importing inputs...'
if ! LIST_CODE=$(curl -s -o "$INPUTS_LIST_TMP" -w "%{http_code}" \
  -u "${GRAYLOG_USER}:${GRAYLOG_PASSWORD}" \
  "${GRAYLOG_API}/system/inputs"); then
  echo "✗ Failed to list inputs"
  exit 1
fi
if [ "$LIST_CODE" != "200" ]; then
  echo "✗ Failed to list inputs (HTTP $LIST_CODE)"
  if [ -s "$INPUTS_LIST_TMP" ]; then
    echo "Response: $(cat "$INPUTS_LIST_TMP")"
  fi
  exit 1
fi
if ! jq -e '(.inputs | type) == "array"' "$INPUTS_LIST_TMP" >/dev/null; then
  echo "✗ Input list response has no inputs array"
  exit 1
fi

jq -c '.inputs[]' "$INPUTS_JSON" > "$INPUTS_LINES_TMP"
while IFS= read -r input; do
  [ -n "$input" ] || continue
  TITLE=$(printf '%s' "$input" | jq -r '.title')
  TYPE=$(printf '%s' "$input" | jq -r '.type')
  if [ -z "$TITLE" ] || [ "$TITLE" = "null" ] || [ -z "$TYPE" ] || [ "$TYPE" = "null" ]; then
    echo "✗ Input is missing title or type"
    exit 1
  fi
  if jq -e --arg title "$TITLE" --arg type "$TYPE" \
    'any(.inputs[]; .title == $title and .type == $type)' \
    "$INPUTS_LIST_TMP" >/dev/null; then
    echo "ℹ Input already exists: $TITLE"
    continue
  fi

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
    exit 1
  fi
done < "$INPUTS_LINES_TMP"

echo '✓ Input import completed!'

echo 'Applying default index set overrides (rotation + retention)...'

LIST=$(curl -s -u "${GRAYLOG_USER}:${GRAYLOG_PASSWORD}" "${GRAYLOG_API}/system/indices/index_sets")
DEFAULT_ID=$(echo "$LIST" | jq -r '.index_sets[]? | select(.default == true) | .id' | head -n1)
if [ -z "$DEFAULT_ID" ] || [ "$DEFAULT_ID" = "null" ]; then
  echo '✗ No default index set found (expected exactly one with default=true)'
  exit 1
fi

curl -s -u "${GRAYLOG_USER}:${GRAYLOG_PASSWORD}" "${GRAYLOG_API}/system/indices/index_sets/${DEFAULT_ID}" -o "$FULL_TMP"
if ! [ -s "$FULL_TMP" ]; then
  echo '✗ Empty response from GET /system/indices/index_sets/'"${DEFAULT_ID}"
  exit 1
fi

# Build rotation/retention from patch only; read FULL from file (avoid shell mangling of large JSON).
# Strip time-based / size-optimizing fields — SizeBasedRotationStrategyConfig only accepts type + max_size.
MERGED=$(jq -c --slurpfile patch "$PATCH_TMP" -f "$MERGE_JQ" "$FULL_TMP")

if ! echo "$MERGED" | jq -e '
  .rotation_strategy.max_size != null
  and (.rotation_strategy | has("index_lifetime_min") | not)
  and (.rotation_strategy | has("rotation_period") | not)
' >/dev/null; then
  echo '✗ Internal error: merged rotation_strategy is not size-based; rotation_strategy=' >&2
  echo "$MERGED" | jq -c '.rotation_strategy' >&2
  exit 1
fi

RESPONSE=$(curl -s -w "\n%{http_code}" -X PUT "${GRAYLOG_API}/system/indices/index_sets/${DEFAULT_ID}" \
  -H "Content-Type: application/json" \
  -H "X-Requested-By: cli" \
  -u "${GRAYLOG_USER}:${GRAYLOG_PASSWORD}" \
  -d "$MERGED")

HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | sed '$d')
if [ "$HTTP_CODE" = "200" ]; then
  echo "✓ Default index set updated (max_size=${GRAYLOG_INDEX_MAX_SIZE_BYTES} max_indices=${GRAYLOG_INDEX_MAX_INDICES})"
else
  echo "✗ Index set update failed (HTTP $HTTP_CODE)"
  echo "Response: $BODY"
  exit 1
fi
