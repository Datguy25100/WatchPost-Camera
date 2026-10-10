#!/usr/bin/env bash
# Copy to run_edge.sh, fill in the 3 values, then: chmod +x run_edge.sh && ./run_edge.sh
export WATCHPOST_URL="https://YOUR-NAME.app.n8n.cloud/webhook/watchpost"
export WATCHPOST_KEY="PUT-YOUR-INGEST_KEY-HERE"
PHONE="192.168.1.50:8080"

cd "$(dirname "$0")"
while true; do
  python3 edge.py --camera "Front door" --ip-webcam "$PHONE" --ai --faces faces --sync-interval 120
  echo "edge.py stopped, restarting in 10s (Ctrl+C to quit)..."
  sleep 10
done
