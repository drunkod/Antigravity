#!/usr/bin/env nix-shell
#! nix-shell -i bash -p xray curl

#############################################################
#  V2Ray/Xray VMess/VLESS VPN Proxy — Standalone Start Script
#############################################################
#
#  Configs:
#    v2ray-client.json          — VMess + WS (current)
#    v2ray-client-reality.json  — VLESS + TCP + Reality (template)
#
#  Usage:
#    ./start-vpn.sh                  # uses v2ray-client.json
#    ./start-vpn.sh reality          # uses v2ray-client-reality.json
#    ./start-vpn.sh /path/to/cfg     # uses custom config file
#
#############################################################

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VPN_PID_FILE="$HOME/.xray-vpn.pid"
VPN_LOG_FILE="$HOME/.xray-vpn.log"
PROXY_ENV_FILE="$HOME/.xray-proxy.env"

SOCKS_PORT=10808
HTTP_PORT=10809

# ── Determine config file ──────────────────────────────────
CONFIG_ARG="${1:-}"

if [ "$CONFIG_ARG" = "reality" ]; then
    CONFIG_FILE="$SCRIPT_DIR/v2ray-client-reality.json"
elif [ -n "$CONFIG_ARG" ] && [ -f "$CONFIG_ARG" ]; then
    CONFIG_FILE="$CONFIG_ARG"
else
    CONFIG_FILE="$SCRIPT_DIR/v2ray-client.json"
fi

if [ ! -f "$CONFIG_FILE" ]; then
    echo "❌ Config file not found: $CONFIG_FILE"
    exit 1
fi

echo "============================================"
echo "🔐 Xray VPN Proxy"
echo "============================================"
echo "   Config: $CONFIG_FILE"
echo ""

# ── Validate config (check for placeholders — only in template files) ──
if grep -q "YOUR_SERVER_ADDRESS\|YOUR-UUID-HERE\|YOUR_PUBLIC_KEY" "$CONFIG_FILE"; then
    echo "⚠️  Config still has placeholder values!"
    echo ""
    echo "   Edit $CONFIG_FILE and replace:"
    echo "     YOUR_SERVER_ADDRESS → your server IP/domain"
    echo "     YOUR-UUID-HERE      → your UUID"
    if grep -q "YOUR_PUBLIC_KEY" "$CONFIG_FILE"; then
        echo "     YOUR_REALITY_SNI    → Reality camouflage SNI"
        echo "     YOUR_SHORT_ID       → Reality short ID"
        echo "     YOUR_PUBLIC_KEY     → Reality public key"
    fi
    echo ""
    exit 1
fi

# ── Stop existing instance ─────────────────────────────────
if [ -f "$VPN_PID_FILE" ]; then
    OLD_PID=$(cat "$VPN_PID_FILE" 2>/dev/null || echo "")
    if [ -n "$OLD_PID" ] && kill -0 "$OLD_PID" 2>/dev/null; then
        echo "🧹 Stopping existing Xray (PID $OLD_PID)..."
        kill "$OLD_PID" 2>/dev/null || true
        sleep 2
        kill -9 "$OLD_PID" 2>/dev/null || true
    fi
    rm -f "$VPN_PID_FILE"
fi

# Also kill any stray xray processes
pkill -f "xray run" 2>/dev/null || true
sleep 1

# ── Start Xray ─────────────────────────────────────────────
echo "🚀 Starting Xray..."
xray run -config "$CONFIG_FILE" > "$VPN_LOG_FILE" 2>&1 &
XRAY_PID=$!
echo "$XRAY_PID" > "$VPN_PID_FILE"

sleep 3

# ── Verify it started ──────────────────────────────────────
if ! kill -0 "$XRAY_PID" 2>/dev/null; then
    echo "❌ Xray failed to start! Last log lines:"
    tail -20 "$VPN_LOG_FILE"
    rm -f "$VPN_PID_FILE"
    exit 1
fi

# ── Verify ports are listening ─────────────────────────────
echo "🔍 Checking proxy ports..."
PORTS_OK=true

for port in $SOCKS_PORT $HTTP_PORT; do
    if curl -s --connect-timeout 2 "http://127.0.0.1:$port" > /dev/null 2>&1 || \
       bash -c "echo > /dev/tcp/127.0.0.1/$port" 2>/dev/null; then
        echo "   ✅ Port $port is listening"
    else
        echo "   ⚠️  Port $port may not be listening yet (could be starting)"
    fi
done

# ── Test proxy connectivity ────────────────────────────────
echo "🔍 Testing proxy connection..."
if curl -s --connect-timeout 10 --proxy "socks5h://127.0.0.1:$SOCKS_PORT" https://ifconfig.me > /tmp/vpn-ip-test 2>/dev/null; then
    VPN_IP=$(cat /tmp/vpn-ip-test)
    REAL_IP=$(curl -s --connect-timeout 5 https://ifconfig.me 2>/dev/null || echo "unknown")
    echo "   ✅ VPN is working!"
    echo "   🌍 Real IP:  $REAL_IP"
    echo "   🔒 VPN IP:   $VPN_IP"
    if [ "$VPN_IP" != "$REAL_IP" ]; then
        echo "   ✅ IP is different — VPN is active!"
    else
        echo "   ⚠️  IP is the same — VPN may not be routing correctly"
    fi
else
    echo "   ⚠️  Could not verify VPN connection (proxy test failed)"
    echo "      Xray is running but connection might not be working yet."
    echo "      Check log: tail -f $VPN_LOG_FILE"
fi
rm -f /tmp/vpn-ip-test

# ── Write proxy environment file ───────────────────────────
cat > "$PROXY_ENV_FILE" <<EOF
# Source this file to enable proxy for your shell:
#   source ~/.xray-proxy.env
export http_proxy="http://127.0.0.1:$HTTP_PORT"
export https_proxy="http://127.0.0.1:$HTTP_PORT"
export HTTP_PROXY="http://127.0.0.1:$HTTP_PORT"
export HTTPS_PROXY="http://127.0.0.1:$HTTP_PORT"
export all_proxy="socks5h://127.0.0.1:$SOCKS_PORT"
export ALL_PROXY="socks5h://127.0.0.1:$SOCKS_PORT"
export no_proxy="localhost,127.0.0.1,::1,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16"
export NO_PROXY="localhost,127.0.0.1,::1,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16"
export PROXY_SOCKS5="127.0.0.1:$SOCKS_PORT"
export PROXY_HTTP="127.0.0.1:$HTTP_PORT"
EOF

echo ""
echo "============================================"
echo "✅ VPN Proxy is RUNNING"
echo "============================================"
echo ""
echo "   Xray PID:     $XRAY_PID"
echo "   SOCKS5 Proxy: 127.0.0.1:$SOCKS_PORT"
echo "   HTTP Proxy:   127.0.0.1:$HTTP_PORT"
echo "   Log file:     $VPN_LOG_FILE"
echo ""
echo "   To use in current shell:"
echo "     source ~/.xray-proxy.env"
echo ""
echo "   To force-proxy any app:"
echo "     proxychains4 -f proxychains.conf <command>"
echo ""
echo "   Stop:   ./stop-vpn.sh"
echo ""
