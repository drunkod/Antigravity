#!/usr/bin/env bash

PID_FILE="$HOME/.antigravity-vnc.pid"

if [ ! -f "$PID_FILE" ]; then
    echo "❌ No services running (no PID file found)"
    exit 1
fi

read -r VNC_PID FLUXBOX_PID WEBSOCKIFY_PID APP_PID DBUS_PID < "$PID_FILE"

echo "📊 Antigravity VNC Status"
echo "=========================="

check_pid() {
    local name=$1
    local pid=$2
    if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
        echo "✅ $name (PID $pid) - Running"
    else
        echo "❌ $name (PID $pid) - Not running"
    fi
}

check_pid "VNC Server  " "$VNC_PID"
check_pid "Fluxbox     " "$FLUXBOX_PID"
check_pid "noVNC       " "$WEBSOCKIFY_PID"
check_pid "Antigravity " "$APP_PID"
check_pid "DBus        " "$DBUS_PID"
