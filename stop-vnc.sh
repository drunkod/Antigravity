#!/usr/bin/env bash

PID_FILE="$HOME/.antigravity-vnc.pid"
LOCK_FILE="$HOME/.antigravity-vnc.lock"

echo "🧹 Stopping Antigravity VNC services..."

# 1. Kill all antigravity processes first
ANTIGRAVITY_PIDS=$(pgrep -f "antigravity" || true)
if [ -n "$ANTIGRAVITY_PIDS" ]; then
    echo "   Stopping Antigravity..."
    pkill -15 -f "antigravity" 2>/dev/null || true
    sleep 2
    pkill -9 -f "antigravity" 2>/dev/null || true
fi

# 2. Stop services from PID file if it exists
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

    # Force kill stragglers from PID file
    for pid in $WEBSOCKIFY_PID $FLUXBOX_PID $VNC_PID $DBUS_PID; do
        if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
            kill -9 "$pid" 2>/dev/null || true
        fi
    done
fi

# 3. FALLBACK: Kill by process name (in case PID file is missing/stale)
echo "   Checking for remaining processes..."

# Kill websockify
WEBSOCKIFY_PIDS=$(pgrep -f "websockify.*5999" || true)
if [ -n "$WEBSOCKIFY_PIDS" ]; then
    echo "   Stopping websockify (PIDs: $WEBSOCKIFY_PIDS)"
    pkill -9 -f "websockify.*5999" 2>/dev/null || true
fi

# Kill Fluxbox
FLUXBOX_PIDS=$(pgrep fluxbox || true)
if [ -n "$FLUXBOX_PIDS" ]; then
    echo "   Stopping Fluxbox (PIDs: $FLUXBOX_PIDS)"
    pkill -9 fluxbox 2>/dev/null || true
fi

# Kill Xvnc
XVNC_PIDS=$(pgrep Xvnc || true)
if [ -n "$XVNC_PIDS" ]; then
    echo "   Stopping Xvnc (PIDs: $XVNC_PIDS)"
    pkill -9 Xvnc 2>/dev/null || true
fi

# Kill DBus (be careful - only kill session bus we started)
if [ -n "${DBUS_PID:-}" ] && kill -0 "$DBUS_PID" 2>/dev/null; then
    echo "   Stopping DBus (PID $DBUS_PID)"
    kill -9 "$DBUS_PID" 2>/dev/null || true
fi

# Cleanup files
rm -f "$PID_FILE" "$LOCK_FILE"

# 4. Final verification
sleep 1

echo ""
echo "🔍 Verification:"

check_process() {
    local name="$1"
    local pattern="$2"
    local pids=$(pgrep -f "$pattern" 2>/dev/null || true)
    if [ -n "$pids" ]; then
        echo "   ⚠️  $name still running: $pids"
        return 1
    else
        echo "   ✅ $name stopped"
        return 0
    fi
}

ALL_STOPPED=true

check_process "Antigravity" "antigravity" || ALL_STOPPED=false
check_process "websockify " "websockify" || ALL_STOPPED=false
check_process "Fluxbox    " "fluxbox" || ALL_STOPPED=false
check_process "Xvnc       " "Xvnc" || ALL_STOPPED=false

echo ""
if [ "$ALL_STOPPED" = true ]; then
    echo "✅ All services stopped successfully"
else
    echo "⚠️  Some services are still running"
    echo "   Run: ps aux | grep -E '(antigravity|websockify|fluxbox|Xvnc)'"
fi
