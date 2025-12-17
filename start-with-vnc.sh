#!/usr/bin/env nix-shell
#! nix-shell -i bash -p dejavu_fonts liberation_ttf noto-fonts fontconfig git procps fluxbox tigervnc dbus

export DISPLAY=:99
export NIXPKGS_ALLOW_UNFREE=1

PID_FILE="$HOME/.antigravity-vnc.pid"
LOG_FILE="$HOME/.antigravity-vnc.log"

echo "============================================"
echo "🚀 Antigravity VNC Launcher"
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

if [ -z "$DBUS_SESSION_BUS_ADDRESS" ]; then
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

# ===== Disable GPU/Vulkan =====
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
nix build . --impure 2>&1 | grep -v "warning: Git tree" || true

# Kill any existing antigravity processes
pkill -f "result/bin/antigravity" 2>/dev/null || true
sleep 1

echo "🚀 Launching Antigravity..."
echo "   Logging to: $LOG_FILE"
DISPLAY=:99 ./result/bin/antigravity > "$LOG_FILE" 2>&1 &
APP_PID=$!

sleep 3

# Check if app is still running
if kill -0 "$APP_PID" 2>/dev/null; then
    ANTIGRAVITY_COUNT=$(pgrep -f "antigravity" | wc -l)
    echo "   ✅ Antigravity started (main PID $APP_PID)"
    echo "   📊 Total processes: $ANTIGRAVITY_COUNT (normal for Electron)"
else
    echo "   ❌ Antigravity crashed! Check log:"
    tail -20 "$LOG_FILE"
    exit 1
fi

# Save PIDs
echo "$VNC_PID $FLUXBOX_PID $WEBSOCKIFY_PID $APP_PID ${DBUS_PID:-}" > "$PID_FILE"

echo ""
echo "✨ All services running in background"
echo "   Stop: ./stop-vnc.sh  |  Status: ./status-vnc.sh"
echo "   Logs: tail -f $LOG_FILE"
echo ""
