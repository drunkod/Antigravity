#!/usr/bin/env bash

PID_FILE="$HOME/.antigravity-vnc.pid"
LOG_FILE="$HOME/.antigravity-vnc.log"
VPN_PID_FILE="$HOME/.xray-vpn.pid"
VPN_LOG_FILE="$HOME/.xray-vpn.log"
XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/tmp/xdg-runtime-$USER}"

echo "============================================"
echo "📊 Antigravity VNC Status"
echo "============================================"
echo ""

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

echo "🔐 VPN Status:"
XRAY_RUNNING=false
if check_running "Xray VPN   " "xray run"; then
    XRAY_RUNNING=true
fi
echo ""

# VPN connectivity test
if [ "$XRAY_RUNNING" = true ]; then
    echo "🌍 VPN Connection Test:"
    if command -v curl &>/dev/null; then
        VPN_IP=$(curl -s --connect-timeout 5 --proxy "socks5h://127.0.0.1:10808" https://ifconfig.me 2>/dev/null || echo "failed")
        REAL_IP=$(curl -s --connect-timeout 5 https://ifconfig.me 2>/dev/null || echo "unknown")
        if [ "$VPN_IP" != "failed" ]; then
            echo "   Real IP: $REAL_IP"
            echo "   VPN IP:  $VPN_IP"
            if [ "$VPN_IP" != "$REAL_IP" ]; then
                echo "   ✅ VPN is working! IPs are different."
            else
                echo "   ⚠️  IPs are the same — VPN may not be routing"
            fi
        else
            echo "   ⚠️  Could not reach internet through VPN proxy"
        fi
    else
        echo "   (curl not available for testing)"
    fi
    echo ""

    echo "🔧 Proxy Settings:"
    echo "   SOCKS5: 127.0.0.1:10808"
    echo "   HTTP:   127.0.0.1:10809"
    echo "   http_proxy=${http_proxy:-<not set>}"
    echo "   all_proxy=${all_proxy:-<not set>}"
    if [ -f "$HOME/.xray-proxy.env" ]; then
        echo "   env file: ~/.xray-proxy.env ✅"
    else
        echo "   env file: missing"
    fi
    echo ""
fi

# PID file info
if [ -f "$PID_FILE" ]; then
    read -r VNC_PID FLUXBOX_PID WEBSOCKIFY_PID APP_PID DBUS_PID XRAY_PID < "$PID_FILE" 2>/dev/null || true
    echo "📄 PID File Contents:"
    echo "   VNC: ${VNC_PID:-?} | Fluxbox: ${FLUXBOX_PID:-?} | websockify: ${WEBSOCKIFY_PID:-?}"
    echo "   App: ${APP_PID:-?} | DBus: ${DBUS_PID:-N/A} | Xray: ${XRAY_PID:-N/A}"

    echo ""
    echo "📋 PID Status:"
    for name_pid in "VNC:${VNC_PID:-}" "Fluxbox:${FLUXBOX_PID:-}" "websockify:${WEBSOCKIFY_PID:-}" "App:${APP_PID:-}" "DBus:${DBUS_PID:-}" "Xray:${XRAY_PID:-}"; do
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

if [ -f "$VPN_LOG_FILE" ] && [ "$XRAY_RUNNING" = true ]; then
    echo "🔐 VPN log (last 5 lines):"
    tail -5 "$VPN_LOG_FILE" | sed 's/^/   /'
    echo ""
fi

if [ -f "$LOG_FILE" ]; then
    echo "📝 App log (last 5 lines):"
    tail -5 "$LOG_FILE" | sed 's/^/   /'
fi
