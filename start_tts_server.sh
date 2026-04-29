#!/bin/bash
# Start the Python TTS Server

cd /opt/New_Serverless_v3

# Kill any existing server on port 6790
fuser -k 6790/tcp 2>/dev/null || true
sleep 1

# Start the new Python TTS server
python3 tts_server.py --host 0.0.0.0 --port 6790 --log-level INFO &

echo "TTS Server started with PID $!"