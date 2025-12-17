#!/usr/bin/env bash

PID_FILE="$HOME/.antigravity-vnc.pid"

if [ ! -f "$PID_FILE" ]; then
    echo "❌ No PID file found. Services may not be running."
    exit 1
fi

echo "🧹 Stopping Antigravity VNC services..."

read -r VNC_PID FLUXBOX_PID WEBSOCKIFY_PID APP_PID DBUS_PID < "$PID_FILE"

for pid in $APP_PID $WEBSOCKIFY_PID $FLUXBOX_PID $VNC_PID $DBUS_PID; do
    if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
        echo "   Stopping PID $pid"
        kill "$pid" 2>/dev/null
    fi
done

rm -f "$PID_FILE"
echo "✅ All services stopped"
