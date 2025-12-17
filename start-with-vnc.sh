#!/usr/bin/env nix-shell
#! nix-shell -i bash -p dejavu_fonts liberation_ttf noto-fonts fontconfig git procps fluxbox tigervnc dbus

export DISPLAY=:99
export NIXPKGS_ALLOW_UNFREE=1

PID_FILE="$HOME/.antigravity-vnc.pid"

echo "============================================"
echo "🚀 Antigravity VNC Launcher (Debug Mode)"
echo "============================================"

# Check if already running
if [ -f "$PID_FILE" ]; then
    read -r VNC_PID FLUXBOX_PID WEBSOCKIFY_PID APP_PID DBUS_PID < "$PID_FILE"
    if [ -n "$APP_PID" ] && kill -0 "$APP_PID" 2>/dev/null; then
        echo "⚠️  Antigravity is already running (PID $APP_PID)"
        echo "   Use ./stop-vnc.sh to stop it first"
        exit 1
    fi
    echo "🧹 Cleaning up stale PID file..."
    rm -f "$PID_FILE"
fi

echo "🛠️  Configuring Fonts..."
export FONTCONFIG_FILE=$(nix-build --no-out-link -E 'with import <nixpkgs> {}; makeFontsConf { fontDirectories = [ dejavu_fonts liberation_ttf noto-fonts ]; }')

# ===== FIX 1: Start DBus session (FIXED) =====
echo "🔌 Starting DBus session..."
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/tmp/xdg-runtime-$USER}"
mkdir -p "$XDG_RUNTIME_DIR"
chmod 700 "$XDG_RUNTIME_DIR"

# Clean up old DBus socket
rm -f "$XDG_RUNTIME_DIR/bus" || true

# Create machine-id if needed
export DBUS_MACHINE_UUID_FILE="$XDG_RUNTIME_DIR/machine-id"
dbus-uuidgen --ensure="$DBUS_MACHINE_UUID_FILE" >/dev/null

# Start DBus properly
DBUS_DAEMON="$(command -v dbus-daemon)"
DBUS_PREFIX="$(dirname "$(dirname "$(readlink -f "$DBUS_DAEMON")")")"
DBUS_SESSION_CONF="$DBUS_PREFIX/share/dbus-1/session.conf"

if [ -z "$DBUS_SESSION_BUS_ADDRESS" ]; then
  mapfile -t _dbus_out < <(
    dbus-daemon \
      --config-file="$DBUS_SESSION_CONF" \
      --address="unix:path=$XDG_RUNTIME_DIR/bus" \
      --fork --print-address=1 --print-pid=1
  )
  export DBUS_SESSION_BUS_ADDRESS="${_dbus_out[0]}"
  DBUS_PID="${_dbus_out[1]}"
  echo "   DBus started: $DBUS_SESSION_BUS_ADDRESS (PID $DBUS_PID)"
else
  echo "   DBus already running: $DBUS_SESSION_BUS_ADDRESS"
  DBUS_PID=""
fi

# ===== FIX 2: Disable Vulkan/GPU features =====
export VK_ICD_FILENAMES=""
export LIBVA_DRIVER_NAME=null
export MESA_LOADER_DRIVER_OVERRIDE=swrast
export GALLIUM_DRIVER=llvmpipe
export __EGL_VENDOR_LIBRARY_FILENAMES=""
export LIBGL_ALWAYS_SOFTWARE=1

# Clone noVNC if needed
if [ ! -d ~/noVNC ]; then
    echo "📦 Cloning noVNC..."
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
echo "============================================"
echo ""

# Build Antigravity
echo "🔨 Building Antigravity..."
cd ~/antigravity
nix build . --impure

echo ""
echo "🔍 DEBUG: DBus address = $DBUS_SESSION_BUS_ADDRESS"
echo ""

# Kill any existing antigravity processes
pkill -f "antigravity" 2>/dev/null || true
sleep 1

echo "🚀 Launching Antigravity..."
DISPLAY=:99 ./result/bin/antigravity 2>&1 &
APP_PID=$!

sleep 2

# Verify only one instance is running
ANTIGRAVITY_COUNT=$(pgrep -f "antigravity" | wc -l)
echo "   Antigravity processes running: $ANTIGRAVITY_COUNT"

# Save all PIDs for later management
echo "$VNC_PID $FLUXBOX_PID $WEBSOCKIFY_PID $APP_PID ${DBUS_PID:-}" > "$PID_FILE"

echo ""
echo "🎮 App running (PID $APP_PID)!"
echo ""
echo "✨ All services running in background"
echo "   Stop services: ./stop-vnc.sh"
echo "   Check status:  ./status-vnc.sh"
echo ""
