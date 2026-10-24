#!/bin/sh
# Repeated graylog-init runs must change both rotation limits while keeping
# the existing GELF input count and ids. Graylog 7.0.5's create call returns
# 201 for a second copy of the same input; this mock does too.
set -eu

ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
INIT_SH="$ROOT/graylog-init.sh"
FIXTURE="$ROOT/test/fixtures/index-set-from-api.json"
PATCH_SH="$ROOT/graylog-index-set-patch.sh"
MERGE_JQ="$ROOT/graylog-index-set-merge.jq"
INPUTS_JSON="$ROOT/graylog-inputs.json"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

command -v python3 >/dev/null 2>&1 || fail "python3 is required"
command -v jq >/dev/null 2>&1 || fail "jq is required"
command -v curl >/dev/null 2>&1 || fail "curl is required"
test -f "$INIT_SH" || fail "missing $INIT_SH"
test -x "$PATCH_SH" || fail "missing executable $PATCH_SH"
test -r "$MERGE_JQ" || fail "missing $MERGE_JQ"
test -r "$INPUTS_JSON" || fail "missing $INPUTS_JSON"
test -r "$FIXTURE" || fail "missing $FIXTURE"

WORKDIR=$(mktemp -d "${TMPDIR:-/tmp}/graylog-init-rotation.XXXXXX")
MOCK="$WORKDIR/mock_api.py"
PORT_FILE="$WORKDIR/port"
SERVER_PID=

cleanup() {
  if [ -n "$SERVER_PID" ]; then
    kill "$SERVER_PID" 2>/dev/null || true
    wait "$SERVER_PID" 2>/dev/null || true
  fi
  rm -rf "$WORKDIR"
}
trap cleanup EXIT

cat > "$MOCK" <<'PY'
import json
import sys
from http.server import BaseHTTPRequestHandler, HTTPServer

with open(sys.argv[1], encoding="utf-8") as handle:
    INDEX_SET = json.load(handle)

STATE = {
    "inputs": [
        {
            "id": "input-1",
            "title": "GELF UDP",
            "type": "org.graylog2.inputs.gelf.udp.GELFUDPInput",
            "global": True,
        }
    ],
    "next_id": 2,
    "post_count": 0,
    "index_set": None,
    "fail_list": False,
}


class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.0"

    def log_message(self, fmt, *args):
        return

    def _send(self, code, payload):
        body = json.dumps(payload).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _body(self):
        length = int(self.headers.get("Content-Length", "0"))
        if length == 0:
            return b""
        return self.rfile.read(length)

    def _path(self):
        return self.path.split("?", 1)[0]

    def do_GET(self):
        path = self._path()
        if path == "/api/system/lbstatus":
            self._send(200, {"status": "ALIVE"})
            return
        if path == "/api/system/inputs":
            if STATE["fail_list"]:
                self._send(500, {"message": "list failed"})
                return
            inputs = STATE["inputs"]
            self._send(200, {"inputs": inputs, "total": len(inputs)})
            return
        if path == "/api/system/indices/index_sets":
            self._send(200, {"index_sets": [{"id": INDEX_SET["id"], "default": True}]})
            return
        if path == "/api/system/indices/index_sets/" + INDEX_SET["id"]:
            self._send(200, INDEX_SET)
            return
        if path == "/api/__test/state":
            stored = STATE["index_set"]
            self._send(200, {
                "post_count": STATE["post_count"],
                "input_ids": [item["id"] for item in STATE["inputs"]],
                "max_size": None if stored is None else stored["rotation_strategy"]["max_size"],
                "max_indices": None if stored is None else stored["retention_strategy"]["max_number_of_indices"],
            })
            return
        self._send(404, {"message": "not found", "path": path})

    def do_POST(self):
        path = self._path()
        raw = self._body()
        if path == "/api/system/inputs":
            payload = json.loads(raw.decode())
            new_id = "input-%d" % STATE["next_id"]
            STATE["next_id"] += 1
            STATE["post_count"] += 1
            STATE["inputs"].append({
                "id": new_id,
                "title": payload.get("title"),
                "type": payload.get("type"),
                "global": payload.get("global", True),
            })
            # Graylog 7.0.5 saves another input and returns 201. It does not
            # report that this title already exists.
            self._send(201, {"id": new_id})
            return
        if path == "/api/__test/reset":
            spec = json.loads(raw.decode() or "{}")
            STATE["inputs"] = spec.get("inputs", [])
            STATE["next_id"] = spec.get("next_id", 1)
            STATE["post_count"] = 0
            STATE["index_set"] = None
            STATE["fail_list"] = False
            self._send(200, {"ok": True})
            return
        if path == "/api/__test/fail-list":
            STATE["fail_list"] = True
            self._send(200, {"ok": True})
            return
        self._send(404, {"message": "not found", "path": path})

    def do_PUT(self):
        path = self._path()
        raw = self._body()
        expected = "/api/system/indices/index_sets/" + INDEX_SET["id"]
        if path != expected:
            self._send(404, {"message": "not found", "path": path})
            return
        STATE["index_set"] = json.loads(raw.decode())
        self._send(200, {"ok": True})


def main():
    server = HTTPServer(("127.0.0.1", 0), Handler)
    with open(sys.argv[2], "w", encoding="utf-8") as handle:
        handle.write(str(server.server_address[1]))
        handle.write("\n")
    server.serve_forever()


if __name__ == "__main__":
    main()
PY

python3 -u "$MOCK" "$FIXTURE" "$PORT_FILE" &
SERVER_PID=$!

i=0
while [ "$i" -lt 50 ]; do
  if [ -s "$PORT_FILE" ]; then
    break
  fi
  i=$((i + 1))
  sleep 0.1
done
[ -s "$PORT_FILE" ] || fail "mock API did not start"
PORT=$(tr -d '[:space:]' < "$PORT_FILE")
ok=0
i=0
while [ "$i" -lt 50 ]; do
  if curl -sf "http://127.0.0.1:${PORT}/api/system/lbstatus" >/dev/null; then
    ok=1
    break
  fi
  i=$((i + 1))
  sleep 0.1
done
[ "$ok" -eq 1 ] || fail "mock API is not reachable on port $PORT"

state() {
  curl -sf "http://127.0.0.1:${PORT}/api/__test/state" || fail "state endpoint failed"
}

expect_state() {
  label=$1
  post_count=$2
  ids_json=$3
  max_size=$4
  max_indices=$5
  got=$(state)
  if ! echo "$got" | jq -e \
    --argjson posts "$post_count" \
    --argjson ids "$ids_json" \
    --argjson size "$max_size" \
    --argjson indices "$max_indices" \
    '.post_count == $posts and .input_ids == $ids and .max_size == $size and .max_indices == $indices' \
    >/dev/null; then
    fail "$label: $got"
  fi
}

run_init() {
  size=$1
  indices=$2
  log=$3
  GRAYLOG_API="http://127.0.0.1:${PORT}/api" \
  GRAYLOG_USER=admin \
  GRAYLOG_PASSWORD=secret \
  GRAYLOG_INDEX_MAX_SIZE_BYTES="$size" \
  GRAYLOG_INDEX_MAX_INDICES="$indices" \
  GRAYLOG_INIT_PATCH_SH="$PATCH_SH" \
  GRAYLOG_INIT_MERGE_JQ="$MERGE_JQ" \
  GRAYLOG_INIT_INPUTS_JSON="$INPUTS_JSON" \
  GRAYLOG_INIT_READY_SLEEP_SECONDS=0 \
  sh "$INIT_SH" >"$log" 2>&1
}

show_log() {
  echo "---- graylog-init log ----" >&2
  cat "$1" >&2
}

LOG1="$WORKDIR/run1.log"
LOG2="$WORKDIR/run2.log"
LOG_BAD="$WORKDIR/run-bad.log"
LOG_CREATE="$WORKDIR/run-create.log"
LOG_KEEP="$WORKDIR/run-keep.log"
LOG_LIST="$WORKDIR/run-list.log"

if ! run_init 10737418240 10 "$LOG1"; then
  show_log "$LOG1"
  fail "first limit update should succeed"
fi
expect_state "after first limit update" 0 '["input-1"]' 10737418240 10
grep -q 'Input already exists: GELF UDP' "$LOG1" || fail "first limit update should keep the existing input"
if grep -q 'Successfully created' "$LOG1"; then
  show_log "$LOG1"
  fail "first limit update created an input"
fi

if ! run_init 21474836480 4 "$LOG2"; then
  show_log "$LOG2"
  fail "second limit update should succeed"
fi
expect_state "after second limit update" 0 '["input-1"]' 21474836480 4
grep -q 'Input already exists: GELF UDP' "$LOG2" || fail "second limit update should keep the existing input"
if grep -q 'Successfully created' "$LOG2"; then
  show_log "$LOG2"
  fail "second limit update created an input"
fi

if run_init 0 4 "$LOG_BAD"; then
  show_log "$LOG_BAD"
  fail "invalid limit should fail"
fi
expect_state "after invalid limit" 0 '["input-1"]' 21474836480 4
if grep -q 'Successfully created' "$LOG_BAD"; then
  show_log "$LOG_BAD"
  fail "invalid limit created an input"
fi

curl -sf -X POST "http://127.0.0.1:${PORT}/api/__test/reset" \
  -H "Content-Type: application/json" \
  -d '{"inputs":[],"next_id":1}' >/dev/null || fail "reset failed"

if ! run_init 10737418240 10 "$LOG_CREATE"; then
  show_log "$LOG_CREATE"
  fail "first run with no inputs should create one input"
fi
expect_state "after creating the only input" 1 '["input-1"]' 10737418240 10
grep -q 'Successfully created: GELF UDP' "$LOG_CREATE" || fail "first run should create GELF UDP"

if ! run_init 21474836480 4 "$LOG_KEEP"; then
  show_log "$LOG_KEEP"
  fail "second run should keep the input created on the first run"
fi
expect_state "after rotation update of a newly created input" 1 '["input-1"]' 21474836480 4

curl -sf -X POST "http://127.0.0.1:${PORT}/api/__test/fail-list" >/dev/null || fail "fail-list toggle failed"
if run_init 10737418240 10 "$LOG_LIST"; then
  show_log "$LOG_LIST"
  fail "input list failure should fail the run"
fi
expect_state "after input list failure" 1 '["input-1"]' 21474836480 4

echo "OK"
