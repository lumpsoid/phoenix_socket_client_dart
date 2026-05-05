#!/usr/bin/env bash
set -euo pipefail

PHOENIX_DIR="test/test_server"
PORT=4000
BASE_URL="localhost:$PORT"
SOCKET_URL="ws://$BASE_URL/socket/websocket"

# Cleanup trap
cleanup() {
  echo "[runner] Stopping Phoenix server (PID $PHOENIX_PID)..."
  kill "$PHOENIX_PID" 2>/dev/null || true
  wait "$PHOENIX_PID" 2>/dev/null || true
  echo "[runner] Done."
}

# Start Phoenix
echo "[runner] Starting Phoenix test server..."
cd "$PHOENIX_DIR"
PORT=$PORT mix phx.server &> /tmp/phoenix_test.log &
PHOENIX_PID=$!
cd - > /dev/null

trap cleanup EXIT INT TERM

# Wait for readiness
echo "[runner] Waiting for Phoenix to be ready..."
TIMEOUT=30
ELAPSED=0

until curl -sf "http://$BASE_URL/health" > /dev/null 2>&1; do
  sleep 0.25
  ELAPSED=$((ELAPSED + 1))
  if [ $ELAPSED -ge $((TIMEOUT * 4)) ]; then
    echo "[runner] ERROR: Phoenix did not start within ${TIMEOUT}s"
    cat /tmp/phoenix_test.log
    exit 1
  fi
done

echo "[runner] Phoenix is ready."

# Run Dart tests
echo "[runner] Running Dart integration tests..."
dart test -P phoenix_test_server "$@"
