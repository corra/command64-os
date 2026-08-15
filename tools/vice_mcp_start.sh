#!/usr/bin/env bash
#
# Start (or stop/check) a VICE instance with its built-in MCP server enabled.
#
# The VICE MCP server has no "launch the emulator" tool of its own -- MCP is
# baked into VICE itself, so something outside MCP has to start the process
# before any client can connect to it. This script is that something. Once
# it's up, attach disks and control the machine over MCP (vice_disk_attach,
# vice_autostart, etc.) rather than via CLI flags here.
#
# Usage:
#   tools/vice_mcp_start.sh start [--machine x64sc] [--port 7000] [--host 127.0.0.1] [--token TOKEN] [--reu-size 16384] [--no-reu]
#   tools/vice_mcp_start.sh stop  [--port 7000]
#   tools/vice_mcp_start.sh status [--port 7000]
#
# A 16MB REU (16384 KiB) is attached by default -- native CASM assembly
# requires a real REU (see src/external/dash/AGENTS.md's "Native Assembly
# Workflow"), and the emulator otherwise starts with standard (no REU)
# expansion. Pass --no-reu to start without one, or --reu-size to change
# the size.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RUN_DIR="$REPO_ROOT/build/vice-mcp"

MACHINE="x64sc"
PORT="7000"
HOST="127.0.0.1"
TOKEN=""
REU_SIZE="16384"
NO_REU=0
CMD="${1:-start}"
shift || true

while [[ $# -gt 0 ]]; do
    case "$1" in
        --machine) MACHINE="$2"; shift 2 ;;
        --port) PORT="$2"; shift 2 ;;
        --host) HOST="$2"; shift 2 ;;
        --token) TOKEN="$2"; shift 2 ;;
        --reu-size) REU_SIZE="$2"; shift 2 ;;
        --no-reu) NO_REU=1; shift ;;
        *) echo "Unknown argument: $1" >&2; exit 2 ;;
    esac
done

mkdir -p "$RUN_DIR"
PID_FILE="$RUN_DIR/${MACHINE}-${PORT}.pid"
LOG_FILE="$RUN_DIR/${MACHINE}-${PORT}.log"
URL="http://${HOST}:${PORT}/mcp"

port_owner_pid() {
    ss -ltnp 2>/dev/null | awk -v p=":$PORT" '$4 ~ p"$" { print $0 }' | grep -oP 'pid=\K[0-9]+' | head -1
}

ping_ok() {
    local resp
    resp="$(curl -sS -m 5 "$URL" \
        -H 'Content-Type: application/json' -H 'Accept: application/json' \
        --data '{"jsonrpc":"2.0","id":0,"method":"vice.ping"}' 2>/dev/null || true)"
    [[ "$resp" == *'"status":"ok"'* ]]
}

cmd_status() {
    local owner
    owner="$(port_owner_pid || true)"
    if [[ -z "$owner" ]]; then
        echo "Nothing is listening on ${HOST}:${PORT}."
        return 1
    fi
    if ping_ok; then
        echo "VICE MCP server is up: PID $owner, $URL"
        return 0
    fi
    echo "PID $owner holds ${HOST}:${PORT} but is NOT answering MCP requests." >&2
    echo "This is the failure mode where VICE logs 'Failed to start HTTP server'" >&2
    echo "yet still leaves a stub socket bound. Kill PID $owner and retry." >&2
    return 1
}

cmd_stop() {
    local owner
    owner="$(port_owner_pid || true)"
    if [[ -z "$owner" ]]; then
        echo "Nothing is listening on ${HOST}:${PORT}; nothing to stop."
        rm -f "$PID_FILE"
        return 0
    fi
    echo "Stopping PID $owner (was serving $URL)..."
    kill "$owner"
    rm -f "$PID_FILE"
}

cmd_start() {
    local existing
    existing="$(port_owner_pid || true)"
    if [[ -n "$existing" ]]; then
        echo "Refusing to start: PID $existing already holds ${HOST}:${PORT}." >&2
        echo "Run 'tools/vice_mcp_start.sh status --port $PORT' to check it, or" >&2
        echo "'tools/vice_mcp_start.sh stop --port $PORT' to clear it first." >&2
        exit 1
    fi

    local bin="$HOME/.local/bin/$MACHINE"
    if [[ ! -x "$bin" ]]; then
        echo "No executable at $bin" >&2
        exit 1
    fi

    local args=(-mcpserver -mcpserverhost "$HOST" -mcpserverport "$PORT")
    [[ -n "$TOKEN" ]] && args+=(-mcpservertoken "$TOKEN")
    if [[ "$NO_REU" -eq 0 ]]; then
        args+=(-reu -reusize "$REU_SIZE")
    fi

    : > "$LOG_FILE"
    setsid nohup "$bin" "${args[@]}" >"$LOG_FILE" 2>&1 </dev/null &
    disown
    local launcher_pid=$!

    # setsid re-parents into a new session; the real emulator PID is whatever
    # ends up bound to the port, not necessarily $launcher_pid.
    local waited=0
    local owner=""
    while (( waited < 20 )); do
        sleep 1
        (( waited += 1 ))
        owner="$(port_owner_pid || true)"
        [[ -n "$owner" ]] && ping_ok && break
        if grep -q "Failed to start HTTP server" "$LOG_FILE" 2>/dev/null; then
            echo "VICE logged 'Failed to start HTTP server on port $PORT'." >&2
            echo "Usually means something else already held the port at bind time." >&2
            echo "Log: $LOG_FILE" >&2
            exit 1
        fi
    done

    if [[ -z "$owner" ]] || ! ping_ok; then
        echo "Timed out waiting for $URL to answer. Log: $LOG_FILE" >&2
        exit 1
    fi

    echo "$owner" > "$PID_FILE"
    echo "VICE MCP server up: PID $owner, $URL"
    if [[ "$NO_REU" -eq 0 ]]; then
        echo "REU attached: ${REU_SIZE} KiB"
    else
        echo "REU: not attached (--no-reu)"
    fi
    echo "Log: $LOG_FILE"
    echo "Attach disks over MCP now, e.g. vice_disk_attach {unit:8, path:...}."
}

case "$CMD" in
    start) cmd_start ;;
    stop) cmd_stop ;;
    status) cmd_status ;;
    *) echo "Usage: $0 {start|stop|status} [--machine x64sc] [--port 7000] [--host 127.0.0.1] [--token TOKEN]" >&2; exit 2 ;;
esac
