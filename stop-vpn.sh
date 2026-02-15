#!/usr/bin/env bash

#############################################################
#  Stop Xray VPN Proxy
#############################################################

VPN_PID_FILE="$HOME/.xray-vpn.pid"
VPN_LOG_FILE="$HOME/.xray-vpn.log"
PROXY_ENV_FILE="$HOME/.xray-proxy.env"

echo "🔐 Stopping Xray VPN Proxy..."

# Stop from PID file
if [ -f "$VPN_PID_FILE" ]; then
    XRAY_PID=$(cat "$VPN_PID_FILE" 2>/dev/null || echo "")
    if [ -n "$XRAY_PID" ] && kill -0 "$XRAY_PID" 2>/dev/null; then
        echo "   Stopping Xray (PID $XRAY_PID)..."
        kill "$XRAY_PID" 2>/dev/null || true
        sleep 2
        if kill -0 "$XRAY_PID" 2>/dev/null; then
            kill -9 "$XRAY_PID" 2>/dev/null || true
        fi
        echo "   ✅ Xray stopped"
    else
        echo "   Xray was not running (stale PID file)"
    fi
    rm -f "$VPN_PID_FILE"
else
    echo "   No PID file found"
fi

# Kill any remaining xray processes
REMAINING=$(pgrep -f "xray run" || true)
if [ -n "$REMAINING" ]; then
    echo "   Cleaning up remaining xray processes: $REMAINING"
    pkill -9 -f "xray run" 2>/dev/null || true
fi

# Unset proxy env vars in current shell
unset http_proxy https_proxy HTTP_PROXY HTTPS_PROXY 2>/dev/null || true
unset all_proxy ALL_PROXY no_proxy NO_PROXY 2>/dev/null || true
unset PROXY_SOCKS5 PROXY_HTTP 2>/dev/null || true

# Remove env file
rm -f "$PROXY_ENV_FILE"

echo ""
echo "✅ VPN Proxy stopped"
echo ""
echo "   Note: proxy env vars are only cleared in THIS shell."
echo "   Running apps may still have old proxy settings."
echo "   Restart apps or run: unset http_proxy https_proxy all_proxy"
echo ""
