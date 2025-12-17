#!/usr/bin/env bash

PID_FILE="$HOME/.antigravity-vnc.pid"

if [ ! -f "$PID_FILE" ]; then
    echo "❌ No PID file found at $PID_FILE"
    echo "   Services may not be running or were started differently"
    exit 1
fi

echo "🧹 Stopping Antigravity VNC services..."

read -r VNC_PID FLUXBOX_PID WEBSOCKIFY_PID APP_PID DBUS_PID < "$PID_FILE"

# Stop in reverse order
for name_pid in "Antigravity:$APP_PID" "noVNC:$WEBSOCKIFY_PID" "Fluxbox:$FLUXBOX_PID" "VNC:$VNC_PID" "DBus:$DBUS_PID"; do
    name="${name_pid%%:*}"
    pid="${name_pid##*:}"

    if [ -n "$pid" ] && [ "$pid" != "" ]; then
        if kill -0 "$pid" 2>/dev/null; then
            echo "   Stopping $name (PID $pid)"
            kill "$pid" 2>/dev/null
        fi
    fi
done

sleep 1

# Force kill any stragglers
for pid in $APP_PID $WEBSOCKIFY_PID $FLUXBOX_PID $VNC_PID $DBUS_PID; do
    if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
        echo "   Force stopping PID $pid"
        kill -9 "$pid" 2>/dev/null
    fi
done

rm -f "$PID_FILE"
echo "✅ All services stopped"
