#!/usr/bin/env nix-shell
#! nix-shell -i bash -p dejavu_fonts liberation_ttf noto-fonts fontconfig git procps fluxbox tigervnc dbus psmisc

export DISPLAY=:99
export NIXPKGS_ALLOW_UNFREE=1

PID_FILE="$HOME/.antigravity-vnc.pid"
LOG_FILE="$HOME/.antigravity-vnc.log"
LOCK_FILE="$HOME/.antigravity-vnc.lock"

echo "============================================"
echo "🚀 Antigravity VNC Launcher"
echo "============================================"

# Kill ALL existing Antigravity processes first
echo "🧹 Checking for existing Antigravity instances..."
EXISTING_PIDS=$(pgrep -f "antigravity" || true)
if [ -n "$EXISTING_PIDS" ]; then
    echo "   Found running instances, stopping them..."
    pkill -9 -f "antigravity" 2>/dev/null || true
    sleep 2
    # Verify they're dead
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

# Check PID file
if [ -f "$PID_FILE" ]; then
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

echo "🚀 Launching Antigravity..."
echo "   Logging to: $LOG_FILE"

# Final safety check - make absolutely sure no antigravity is running
pkill -9 -f "antigravity" 2>/dev/null || true
sleep 1

# Enable Electron/Chrome logging
export ELECTRON_ENABLE_LOGGING=1
export ELECTRON_LOG_FILE="$HOME/.antigravity-electron.log"

# Launch with logging and verbose flags
DISPLAY=:99 ./result/bin/antigravity --verbose --log-level=debug > "$LOG_FILE" 2>&1 &
APP_PID=$!

# Create lock file immediately
echo "$APP_PID" > "$LOCK_FILE"

sleep 3

# Verify it's running
if ! kill -0 "$APP_PID" 2>/dev/null; then
    echo "   ❌ Antigravity crashed! Check log:"
    tail -20 "$LOG_FILE"
    rm -f "$LOCK_FILE"
    exit 1
fi

# Count processes (should be 2-4 for Electron: main + renderer + helpers)
ANTIGRAVITY_COUNT=$(pgrep -f "antigravity" | wc -l)
echo "   ✅ Antigravity started (main PID $APP_PID)"
echo "   📊 Electron processes: $ANTIGRAVITY_COUNT"

# Verify we don't have duplicate main processes
MAIN_PROCESSES=$(pgrep -f "result/bin/antigravity" | wc -l)
if [ "$MAIN_PROCESSES" -gt 1 ]; then
    echo "   ⚠️  WARNING: Multiple main processes detected!"
    pgrep -af "antigravity"
fi

# Save PIDs
echo "$VNC_PID $FLUXBOX_PID $WEBSOCKIFY_PID $APP_PID ${DBUS_PID:-}" > "$PID_FILE"

echo ""
echo "✨ All services running in background"
echo "   Stop: ./stop-vnc.sh  |  Status: ./status-vnc.sh"
echo "   Logs: tail -f $LOG_FILE"
echo ""
