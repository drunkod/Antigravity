#!/usr/bin/env bash

PID_FILE="$HOME/.antigravity-vnc.pid"
LOCK_FILE="$HOME/.antigravity-vnc.lock"

echo "🧹 Stopping Antigravity VNC services..."

# Kill all antigravity processes first
ANTIGRAVITY_PIDS=$(pgrep -f "antigravity" || true)
if [ -n "$ANTIGRAVITY_PIDS" ]; then
    echo "   Stopping all Antigravity processes..."
    pkill -15 -f "antigravity" 2>/dev/null || true
    sleep 2
    # Force kill if still alive
    pkill -9 -f "antigravity" 2>/dev/null || true
fi

# Stop other services from PID file
if [ -f "$PID_FILE" ]; then
    read -r VNC_PID FLUXBOX_PID WEBSOCKIFY_PID APP_PID DBUS_PID < "$PID_FILE"

    for name_pid in "noVNC:$WEBSOCKIFY_PID" "Fluxbox:$FLUXBOX_PID" "VNC:$VNC_PID" "DBus:$DBUS_PID"; do
        name="${name_pid%%:*}"
        pid="${name_pid##*:}"

        if [ -n "$pid" ] && [ "$pid" != "" ]; then
            if kill -0 "$pid" 2>/dev/null; then
                echo "   Stopping $name (PID $pid)"
                kill "$pid" 2>/dev/null || true
            fi
        fi
    done

    sleep 1

    # Force kill stragglers
    for pid in $WEBSOCKIFY_PID $FLUXBOX_PID $VNC_PID $DBUS_PID; do
        if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
            kill -9 "$pid" 2>/dev/null || true
        fi
    done
fi

# Cleanup files
rm -f "$PID_FILE" "$LOCK_FILE"

# Final verification
REMAINING=$(pgrep -f "antigravity" || true)
if [ -n "$REMAINING" ]; then
    echo "   ⚠️  Some processes still running: $REMAINING"
    killall -9 antigravity 2>/dev/null || true
fi

echo "✅ All services stopped"
