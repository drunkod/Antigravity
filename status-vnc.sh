#!/usr/bin/env bash

PID_FILE="$HOME/.antigravity-vnc.pid"
LOG_FILE="$HOME/.antigravity-vnc.log"
XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/tmp/xdg-runtime-$USER}"

echo "============================================"
echo "📊 Antigravity VNC Status"
echo "============================================"
echo ""

# Check all relevant processes
check_running() {
    local name="$1"
    local pattern="$2"
    local pids=$(pgrep -f "$pattern" 2>/dev/null || true)

    if [ -n "$pids" ]; then
        echo "✅ $name: running"
        pgrep -af "$pattern" | sed 's/^/   /'
        return 0
    else
        echo "❌ $name: not running"
        return 1
    fi
}

echo "🎮 Application Status:"
check_running "Antigravity" "antigravity"
echo ""

echo "📦 VNC Services:"
check_running "Xvnc       " "Xvnc :99"
check_running "Fluxbox    " "fluxbox"
check_running "websockify " "websockify.*5999"
check_running "DBus (ours)" "dbus-daemon.*$XDG_RUNTIME_DIR"
echo ""

# Show PID file info if it exists
if [ -f "$PID_FILE" ]; then
    read -r VNC_PID FLUXBOX_PID WEBSOCKIFY_PID APP_PID DBUS_PID < "$PID_FILE"
    echo "📄 PID File Contents:"
    echo "   VNC: $VNC_PID | Fluxbox: $FLUXBOX_PID | websockify: $WEBSOCKIFY_PID"
    echo "   App: $APP_PID | DBus: ${DBUS_PID:-N/A}"

    # Check if PIDs are still valid
    echo ""
    echo "📋 PID Status:"
    for name_pid in "VNC:$VNC_PID" "Fluxbox:$FLUXBOX_PID" "websockify:$WEBSOCKIFY_PID" "App:$APP_PID" "DBus:$DBUS_PID"; do
        name="${name_pid%%:*}"
        pid="${name_pid##*:}"
        if [ -n "$pid" ] && [ "$pid" != "" ]; then
            if kill -0 "$pid" 2>/dev/null; then
                echo "   ✅ $name ($pid) - alive"
            else
                echo "   💀 $name ($pid) - dead"
            fi
        fi
    done
    echo ""
fi

echo "📺 VNC URL:"
echo "https://5999-firebase-antigravity-1763533608633.cluster-iusnsmywp5clov45nv5gsxt5he.cloudworkstations.dev/vnc.html"
echo ""

if [ -f "$LOG_FILE" ]; then
    echo "📝 Recent log (last 5 lines):"
    tail -5 "$LOG_FILE" | sed 's/^/   /'
fi
