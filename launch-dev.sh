#!/usr/bin/env bash
# launch-dev.sh - Development launcher for Antigravity

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export ANTIGRAVITY_DEV_MODE=1

# Start VNC in background
echo "🚀 Starting VNC environment..."
$SCRIPT_DIR/start-with-vnc.sh &
VNC_PID=$!

# Wait for VNC to be ready
sleep 5

# Antigravity is now running via start-with-vnc.sh
echo "✅ Development environment ready!"
echo "📺 Open VNC in browser to access Antigravity"
echo "💻 Use integrated terminal (Ctrl+\`) to run commands"

wait $VNC_PID
