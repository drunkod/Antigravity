#!/usr/bin/env bash

PID_FILE="$HOME/.antigravity-vnc.pid"
LOCK_FILE="$HOME/.antigravity-vnc.lock"
VPN_PID_FILE="$HOME/.xray-vpn.pid"
PROXY_ENV_FILE="$HOME/.xray-proxy.env"
XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/tmp/xdg-runtime-$USER}"

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
    read -r VNC_PID FLUXBOX_PID WEBSOCKIFY_PID APP_PID DBUS_PID XRAY_PID < "$PID_FILE" 2>/dev/null || true

    for name_pid in "noVNC:${WEBSOCKIFY_PID:-}" "Fluxbox:${FLUXBOX_PID:-}" "VNC:${VNC_PID:-}" "DBus:${DBUS_PID:-}" "Xray:${XRAY_PID:-}"; do
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
    for pid in ${WEBSOCKIFY_PID:-} ${FLUXBOX_PID:-} ${VNC_PID:-} ${DBUS_PID:-} ${XRAY_PID:-}; do
        if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
            kill -9 "$pid" 2>/dev/null || true
        fi
    done
fi

# 3. Stop Xray VPN from its own PID file
if [ -f "$VPN_PID_FILE" ]; then
    XRAY_VPN_PID=$(cat "$VPN_PID_FILE" 2>/dev/null || echo "")
    if [ -n "$XRAY_VPN_PID" ] && kill -0 "$XRAY_VPN_PID" 2>/dev/null; then
        echo "   Stopping Xray VPN (PID $XRAY_VPN_PID)"
        kill "$XRAY_VPN_PID" 2>/dev/null || true
        sleep 1
        kill -9 "$XRAY_VPN_PID" 2>/dev/null || true
    fi
    rm -f "$VPN_PID_FILE"
fi

# 4. FALLBACK: Kill by process name
echo "   Checking for remaining processes..."

WEBSOCKIFY_PIDS=$(pgrep -f "websockify.*5999" || true)
if [ -n "$WEBSOCKIFY_PIDS" ]; then
    echo "   Stopping websockify (PIDs: $WEBSOCKIFY_PIDS)"
    pkill -9 -f "websockify.*5999" 2>/dev/null || true
fi

FLUXBOX_PIDS=$(pgrep fluxbox || true)
if [ -n "$FLUXBOX_PIDS" ]; then
    echo "   Stopping Fluxbox (PIDs: $FLUXBOX_PIDS)"
    pkill -9 fluxbox 2>/dev/null || true
fi

XVNC_PIDS=$(pgrep -f "Xvnc :99" || true)
if [ -n "$XVNC_PIDS" ]; then
    echo "   Stopping Xvnc (PIDs: $XVNC_PIDS)"
    pkill -9 -f "Xvnc :99" 2>/dev/null || true
fi

XRAY_PIDS=$(pgrep -f "xray run" || true)
if [ -n "$XRAY_PIDS" ]; then
    echo "   Stopping Xray (PIDs: $XRAY_PIDS)"
    pkill -9 -f "xray run" 2>/dev/null || true
fi

DBUS_PIDS=$(pgrep -f "dbus-daemon.*$XDG_RUNTIME_DIR" || true)
if [ -n "$DBUS_PIDS" ]; then
    echo "   Stopping DBus daemons (PIDs: $DBUS_PIDS)"
    pkill -9 -f "dbus-daemon.*$XDG_RUNTIME_DIR" 2>/dev/null || true
fi

# Cleanup
rm -f "$XDG_RUNTIME_DIR/bus" 2>/dev/null || true
rm -f "$PROXY_ENV_FILE" 2>/dev/null || true
rm -f "$PID_FILE" "$LOCK_FILE"

unset http_proxy https_proxy HTTP_PROXY HTTPS_PROXY 2>/dev/null || true
unset all_proxy ALL_PROXY no_proxy NO_PROXY 2>/dev/null || true
unset PROXY_SOCKS5 PROXY_HTTP 2>/dev/null || true

# 5. Final verification
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
check_process "websockify " "websockify.*5999" || ALL_STOPPED=false
check_process "Fluxbox    " "fluxbox" || ALL_STOPPED=false
check_process "Xvnc       " "Xvnc :99" || ALL_STOPPED=false
check_process "Xray VPN   " "xray run" || ALL_STOPPED=false
check_process "DBus       " "dbus-daemon.*$XDG_RUNTIME_DIR" || ALL_STOPPED=false

echo ""
if [ "$ALL_STOPPED" = true ]; then
    echo "✅ All services stopped successfully"
else
    echo "⚠️  Some services are still running"
    echo "   Try: ./kill-all.sh"
fi
