#!/usr/bin/env nix-shell
#! nix-shell -i bash -p dejavu_fonts liberation_ttf noto-fonts fontconfig git procps fluxbox tigervnc dbus psmisc wget unzip xray proxychains-ng curl

export DISPLAY=:99
export NIXPKGS_ALLOW_UNFREE=1

PID_FILE="$HOME/.antigravity-vnc.pid"
LOG_FILE="$HOME/.antigravity-vnc.log"
LOCK_FILE="$HOME/.antigravity-vnc.lock"
VPN_PID_FILE="$HOME/.xray-vpn.pid"
VPN_LOG_FILE="$HOME/.xray-vpn.log"
PROXY_ENV_FILE="$HOME/.xray-proxy.env"

SOCKS_PORT=10808
HTTP_PORT=10809

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "============================================"
echo "🚀 Antigravity VNC Launcher (with VPN)"
echo "============================================"

# Kill ALL existing Antigravity processes first
echo "🧹 Checking for existing Antigravity instances..."
EXISTING_PIDS=$(pgrep -f "antigravity" || true)
if [ -n "$EXISTING_PIDS" ]; then
    echo "   Found running instances, stopping them..."
    pkill -9 -f "antigravity" 2>/dev/null || true
    sleep 2
    STILL_RUNNING=$(pgrep -f "antigravity" || true)
    if [ -n "$STILL_RUNNING" ]; then
        echo "   ⚠️  Some processes still running: $STILL_RUNNING"
        killall -9 antigravity 2>/dev/null || true
        sleep 1
    fi
    echo "   ✅ Cleaned up old instances"
fi

# Check lock file
if [ -f "$LOCK_FILE" ]; then
    LOCK_PID=$(cat "$LOCK_FILE" 2>/dev/null || echo "")
    if [ -n "$LOCK_PID" ] && kill -0 "$LOCK_PID" 2>/dev/null; then
        echo "⚠️  Antigravity is already running (PID $LOCK_PID)"
        echo "   Run ./stop-vnc.sh to stop it first"
        exit 1
    fi
    rm -f "$LOCK_FILE"
fi

if [ -f "$PID_FILE" ]; then
    echo "🧹 Cleaning up stale PID file..."
    rm -f "$PID_FILE"
fi

echo "🛠️  Configuring Fonts..."
export FONTCONFIG_FILE=$(nix-build --no-out-link -E '
with import <nixpkgs> {};
let
  userFontsDir = builtins.getEnv "HOME" + "/.local/share/fonts";
in
makeFontsConf {
  fontDirectories = [
    dejavu_fonts
    liberation_ttf
    noto-fonts
  ] ++ (if builtins.pathExists userFontsDir then [ userFontsDir ] else []);
}')

# ===== DBus session =====
echo "🔌 Starting DBus session..."
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/tmp/xdg-runtime-$USER}"
mkdir -p "$XDG_RUNTIME_DIR"
chmod 700 "$XDG_RUNTIME_DIR"
rm -f "$XDG_RUNTIME_DIR/bus" || true

export DBUS_MACHINE_UUID_FILE="$XDG_RUNTIME_DIR/machine-id"
dbus-uuidgen --ensure="$DBUS_MACHINE_UUID_FILE" >/dev/null

DBUS_DAEMON="$(command -v dbus-daemon)"
DBUS_PREFIX="$(dirname "$(dirname "$(readlink -f "$DBUS_DAEMON")")")"
DBUS_SESSION_CONF="$DBUS_PREFIX/share/dbus-1/session.conf"

if [ -z "${DBUS_SESSION_BUS_ADDRESS:-}" ]; then
  mapfile -t _dbus_out < <(
    dbus-daemon \
      --config-file="$DBUS_SESSION_CONF" \
      --address="unix:path=$XDG_RUNTIME_DIR/bus" \
      --fork --print-address=1 --print-pid=1
  )
  export DBUS_SESSION_BUS_ADDRESS="${_dbus_out[0]}"
  DBUS_PID="${_dbus_out[1]}"
  echo "   DBus started (PID $DBUS_PID)"
else
  echo "   DBus already running"
  DBUS_PID=""
fi

export DBUS_SYSTEM_BUS_ADDRESS=""

# ===== Disable GPU/Vulkan =====
export VK_ICD_FILENAMES=""
export LIBVA_DRIVER_NAME=null
export MESA_LOADER_DRIVER_OVERRIDE=swrast
export GALLIUM_DRIVER=llvmpipe
export __EGL_VENDOR_LIBRARY_FILENAMES=""
export LIBGL_ALWAYS_SOFTWARE=1

# ===== Disable ALSA =====
export ALSA_CONFIG_PATH="/dev/null"

# ============================================================
#  VPN PROXY — Start Xray Client
# ============================================================
VPN_ENABLED=false
XRAY_PID=""

# Determine which config to use
VPN_CONFIG=""
if [ -f "$SCRIPT_DIR/v2ray-client.json" ]; then
    VPN_CONFIG="$SCRIPT_DIR/v2ray-client.json"
elif [ -f "$SCRIPT_DIR/v2ray-client-reality.json" ]; then
    VPN_CONFIG="$SCRIPT_DIR/v2ray-client-reality.json"
fi

if [ -n "$VPN_CONFIG" ]; then
    # Check for placeholder values (only in template configs)
    if grep -q "YOUR_SERVER_ADDRESS\|YOUR-UUID-HERE\|YOUR_PUBLIC_KEY" "$VPN_CONFIG"; then
        echo ""
        echo "⚠️  VPN config found but has placeholder values."
        echo "   Edit $VPN_CONFIG to enable VPN."
        echo "   Continuing WITHOUT VPN..."
        echo ""
    else
        echo ""
        echo "🔐 Starting Xray VPN Proxy..."
        echo "   Config: $VPN_CONFIG"

        # Kill any existing xray
        pkill -f "xray run" 2>/dev/null || true
        sleep 1

        # Start Xray
        xray run -config "$VPN_CONFIG" > "$VPN_LOG_FILE" 2>&1 &
        XRAY_PID=$!
        echo "$XRAY_PID" > "$VPN_PID_FILE"
        sleep 3

        if kill -0 "$XRAY_PID" 2>/dev/null; then
            VPN_ENABLED=true
            echo "   ✅ Xray started (PID $XRAY_PID)"

            # Set proxy environment for ALL child processes
            export http_proxy="http://127.0.0.1:$HTTP_PORT"
            export https_proxy="http://127.0.0.1:$HTTP_PORT"
            export HTTP_PROXY="http://127.0.0.1:$HTTP_PORT"
            export HTTPS_PROXY="http://127.0.0.1:$HTTP_PORT"
            export all_proxy="socks5h://127.0.0.1:$SOCKS_PORT"
            export ALL_PROXY="socks5h://127.0.0.1:$SOCKS_PORT"
            export no_proxy="localhost,127.0.0.1,::1,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16"
            export NO_PROXY="$no_proxy"
            export PROXY_SOCKS5="127.0.0.1:$SOCKS_PORT"
            export PROXY_HTTP="127.0.0.1:$HTTP_PORT"

            # Write env file for other shells
            cat > "$PROXY_ENV_FILE" <<PROXYEOF
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
PROXYEOF

            # Quick connectivity test
            echo "   🔍 Testing VPN connection..."
            if VPN_IP=$(curl -s --connect-timeout 8 --proxy "socks5h://127.0.0.1:$SOCKS_PORT" https://ifconfig.me 2>/dev/null); then
                REAL_IP=$(curl -s --connect-timeout 5 https://ifconfig.me 2>/dev/null || echo "unknown")
                echo "   🌍 Real IP: $REAL_IP"
                echo "   🔒 VPN IP:  $VPN_IP"
                if [ "$VPN_IP" != "$REAL_IP" ]; then
                    echo "   ✅ IP is different — VPN is active!"
                fi
            else
                echo "   ⚠️  VPN proxy running but connectivity test failed"
                echo "      Check log: tail -f $VPN_LOG_FILE"
            fi

            # Test HTTP proxy port too
            if curl -s --connect-timeout 5 --proxy "http://127.0.0.1:$HTTP_PORT" https://ifconfig.me > /dev/null 2>&1; then
                echo "   ✅ HTTP proxy (port $HTTP_PORT) working"
            else
                echo "   ⚠️  HTTP proxy (port $HTTP_PORT) test failed"
            fi
        else
            echo "   ❌ Xray failed to start!"
            echo "   Last log lines:"
            tail -10 "$VPN_LOG_FILE"
            echo "   Continuing WITHOUT VPN..."
            XRAY_PID=""
            rm -f "$VPN_PID_FILE"
        fi
    fi
else
    echo ""
    echo "ℹ️  No VPN config found. To enable VPN:"
    echo "   Edit v2ray-client.json with your server details."
    echo ""
fi
# ============================================================

# Clone noVNC if needed
if [ ! -d ~/noVNC ]; then
    echo "📦 Cloning noVNC..."
    # Clone noVNC without proxy (it's a direct github fetch)
    env -u http_proxy -u https_proxy -u all_proxy \
        git clone --depth 1 https://github.com/novnc/noVNC.git ~/noVNC
fi

echo "🚀 Starting VNC Server..."
Xvnc :99 -geometry 1920x1080 -depth 24 -SecurityTypes None -rfbport 5900 -dpi 96 2>&1 &
VNC_PID=$!
sleep 3

echo "🖥️  Starting Fluxbox..."
DISPLAY=:99 fluxbox 2>/dev/null &
FLUXBOX_PID=$!
sleep 2

echo "🌐 Starting noVNC proxy..."
cd ~/noVNC
websockify --web=. 5999 localhost:5900 2>&1 &
WEBSOCKIFY_PID=$!
sleep 2

echo ""
echo "============================================"
echo "✅ VNC READY!"
echo ""
echo "📺 VNC URL:"
echo "https://5999-firebase-antigravity-1763533608633.cluster-iusnsmywp5clov45nv5gsxt5he.cloudworkstations.dev/vnc.html"
if [ "$VPN_ENABLED" = true ]; then
echo ""
echo "🔐 VPN: ACTIVE (all traffic routed through proxy)"
echo "   SOCKS5: 127.0.0.1:$SOCKS_PORT | HTTP: 127.0.0.1:$HTTP_PORT"
fi
echo "============================================"
echo ""

# Build Antigravity
echo "🔨 Building Antigravity..."
cd ~/antigravity
nix build . --impure 2>&1 | grep -v "warning: Git tree" || true

echo "🚀 Launching Antigravity..."
echo "   Logging to: $LOG_FILE"

# Final safety check
pkill -9 -f "antigravity" 2>/dev/null || true
sleep 1

# Launch with logging
# Proxy env vars are inherited from the exported environment
DISPLAY=:99 ./result/bin/antigravity --verbose 2>&1 | \
  grep -v "Failed to connect to the bus" | \
  grep -v "ALSA lib" | \
  grep -v "PcmOpen" > "$LOG_FILE" &

APP_PID=$!
echo "$APP_PID" > "$LOCK_FILE"

sleep 3

# Verify it's running
if ! kill -0 "$APP_PID" 2>/dev/null; then
    echo "   ❌ Antigravity crashed! Check log:"
    tail -20 "$LOG_FILE"
    rm -f "$LOCK_FILE"
    exit 1
fi

ANTIGRAVITY_COUNT=$(pgrep -f "antigravity" | wc -l)
echo "   ✅ Antigravity started (main PID $APP_PID)"
echo "   📊 Electron processes: $ANTIGRAVITY_COUNT"

# Save PIDs
echo "$VNC_PID $FLUXBOX_PID $WEBSOCKIFY_PID $APP_PID ${DBUS_PID:-} ${XRAY_PID:-}" > "$PID_FILE"

echo ""
echo "✨ All services running in background"
echo "   Stop: ./stop-vnc.sh  |  Status: ./status-vnc.sh"
echo "   Logs: tail -f $LOG_FILE"
if [ "$VPN_ENABLED" = true ]; then
echo "   VPN log: tail -f $VPN_LOG_FILE"
echo "   For other shells: source ~/.xray-proxy.env"
echo "   Force-proxy an app: proxychains4 -f proxychains.conf <cmd>"
fi
echo ""
