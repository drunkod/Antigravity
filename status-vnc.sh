#!/usr/bin/env bash

PID_FILE="$HOME/.antigravity-vnc.pid"

if [ ! -f "$PID_FILE" ]; then
    echo "❌ No services running"
    echo "   (PID file not found: $PID_FILE)"
    exit 1
fi

read -r VNC_PID FLUXBOX_PID WEBSOCKIFY_PID APP_PID DBUS_PID < "$PID_FILE"

echo "============================================"
echo "📊 Antigravity VNC Status"
echo "============================================"
echo ""

check_process() {
    local name="$1"
    local pid="$2"

    if [ -z "$pid" ] || [ "$pid" = "" ]; then
        echo "⚪ $name: not tracked"
        return
    fi

    if kill -0 "$pid" 2>/dev/null; then
        echo "✅ $name: running (PID $pid)"
    else
        echo "❌ $name: stopped (was PID $pid)"
    fi
}

check_process "VNC Server  " "$VNC_PID"
check_process "Fluxbox     " "$FLUXBOX_PID"
check_process "noVNC Proxy " "$WEBSOCKIFY_PID"
check_process "Antigravity " "$APP_PID"
check_process "DBus Daemon " "$DBUS_PID"

echo ""
echo "VNC URL:"
echo "https://5999-firebase-antigravity-1763533608633.cluster-iusnsmywp5clov45nv5gsxt5he.cloudworkstations.dev/vnc.html"
echo ""
