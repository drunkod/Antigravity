#!/usr/bin/env bash

PID_FILE="$HOME/.antigravity-vnc.pid"
LOG_FILE="$HOME/.antigravity-vnc.log"

echo "============================================"
echo "📊 Antigravity VNC Status"
echo "============================================"
echo ""

# Check all antigravity processes
ANTIGRAVITY_PIDS=$(pgrep -f "antigravity" || true)
if [ -n "$ANTIGRAVITY_PIDS" ]; then
    echo "🎮 Antigravity Processes:"
    pgrep -af "antigravity" | sed 's/^/   /'
    PROCESS_COUNT=$(echo "$ANTIGRAVITY_PIDS" | wc -l)
    echo "   Total: $PROCESS_COUNT processes"
    echo ""
fi

# Check PID file
if [ -f "$PID_FILE" ]; then
    read -r VNC_PID FLUXBOX_PID WEBSOCKIFY_PID APP_PID DBUS_PID < "$PID_FILE"

    check_process() {
        local name="$1"
        local pid="$2"

        if [ -z "$pid" ] || [ "$pid" = "" ]; then
            return
        fi

        if kill -0 "$pid" 2>/dev/null; then
            echo "✅ $name: running (PID $pid)"
        else
            echo "❌ $name: stopped (was PID $pid)"
        fi
    }

    echo "📦 VNC Services:"
    check_process "VNC Server  " "$VNC_PID"
    check_process "Fluxbox     " "$FLUXBOX_PID"
    check_process "noVNC Proxy " "$WEBSOCKIFY_PID"
    check_process "DBus Daemon " "$DBUS_PID"
else
    echo "⚪ No PID file found"
fi

echo ""
echo "📺 VNC URL:"
echo "https://5999-firebase-antigravity-1763533608633.cluster-iusnsmywp5clov45nv5gsxt5he.cloudworkstations.dev/vnc.html"
echo ""

if [ -f "$LOG_FILE" ]; then
    echo "📝 Recent log (last 5 lines):"
    tail -5 "$LOG_FILE" | sed 's/^/   /'
fi
