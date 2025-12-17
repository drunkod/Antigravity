#!/usr/bin/env nix-shell
#! nix-shell -i bash -p dejavu_fonts liberation_ttf noto-fonts fontconfig git procps fluxbox tigervnc dbus xdotool xorg.xdpyinfo strace

export DISPLAY_NUM=${DISPLAY_NUM:-99}
VNC_PORT=$((5900 + DISPLAY_NUM - 99))
WEB_PORT=$((5999 + DISPLAY_NUM - 99))

export DISPLAY=:$DISPLAY_NUM
export NIXPKGS_ALLOW_UNFREE=1

echo "============================================"
echo "🚀 Antigravity VNC Launcher (Debug Mode)"
echo "============================================"

echo "🛠️  Configuring Fonts..."
export FONTCONFIG_FILE=$(nix-build --no-out-link -E 'with import <nixpkgs> {}; makeFontsConf { fontDirectories = [ dejavu_fonts liberation_ttf noto-fonts ]; }')

# DBus session
echo "🔌 Starting DBus session..."
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/tmp/xdg-runtime-$USER}"
mkdir -p "$XDG_RUNTIME_DIR"
chmod 700 "$XDG_RUNTIME_DIR"
rm -f "$XDG_RUNTIME_DIR/bus" || true

export DBUS_MACHINE_UUID_FILE="$XDG_RUNTIME_DIR/machine-id"
dbus-uuidgen --ensure="$DBUS_MACHINE_UUID_FILE" >/dev/null

DBUS_DAEMON="$(command -v dbus-daemon || true)"
if [ -n "$DBUS_DAEMON" ]; then
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
    echo "   DBus started: ${DBUS_SESSION_BUS_ADDRESS:-<empty>}"
  fi
fi

# GPU/Vulkan disable
export VK_ICD_FILENAMES=""
export LIBVA_DRIVER_NAME=null
export MESA_LOADER_DRIVER_OVERRIDE=swrast
export GALLIUM_DRIVER=llvmpipe
export __EGL_VENDOR_LIBRARY_FILENAMES=""
export LIBGL_ALWAYS_SOFTWARE=1

# Electron logging
export ELECTRON_ENABLE_LOGGING=1

# noVNC
if [ ! -d ~/noVNC ]; then
    git clone --depth 1 https://github.com/novnc/noVNC.git ~/noVNC
fi

echo "🚀 Starting VNC Server..."
Xvnc :$DISPLAY_NUM -geometry 1920x1080 -depth 24 -SecurityTypes None -rfbport $VNC_PORT -dpi 96 2>&1 &
VNC_PID=$!
sleep 3

echo "🔍 Checking X server..."
if xdpyinfo -display :$DISPLAY_NUM >/dev/null 2>&1; then
    echo "   ✅ X server responding on :$DISPLAY_NUM"
else
    echo "   ❌ X server not responding!"
    exit 1
fi

echo "🖥️  Starting Fluxbox..."
DISPLAY=:$DISPLAY_NUM fluxbox 2>/dev/null &
sleep 2

echo "🌐 Starting noVNC..."
cd ~/noVNC
websockify --web=. $WEB_PORT localhost:$VNC_PORT 2>&1 &
WEBSOCKIFY_PID=$!
sleep 2

echo ""
echo "============================================"
echo "✅ VNC READY!"
echo "📺 https://$WEB_PORT-firebase-antigravity-1763533608633.cluster-iusnsmywp5clov45nv5gsxt5he.cloudworkstations.dev/vnc.html"
echo "============================================"
echo ""

cd ~/antigravity

# First, let's try UNWRAPPED nixpkgs antigravity directly
echo "🔬 TEST 1: Running UNWRAPPED nixpkgs antigravity..."
echo "=================================================="

# Get the unwrapped binary path
UNWRAPPED=$(nix-build '<nixpkgs>' -A antigravity --no-out-link 2>/dev/null)
echo "Unwrapped path: $UNWRAPPED"

echo ""
echo "Running with minimal flags..."
timeout 10 $UNWRAPPED/bin/antigravity --no-sandbox 2>&1 || true

echo ""
echo "=================================================="
echo "🔬 TEST 2: Running with strace to see exit reason..."
echo "=================================================="

# Strace to see what happens at exit
timeout 15 strace -f -e trace=write,exit_group -s 200 \
    $UNWRAPPED/bin/antigravity --no-sandbox 2>&1 | tail -50 || true

echo ""
echo "=================================================="
echo "🔬 TEST 3: Check if it needs a specific working directory..."
echo "=================================================="

# Maybe it needs to run from a specific directory?
cd $UNWRAPPED
timeout 10 ./bin/antigravity --no-sandbox 2>&1 || true
cd ~/antigravity

echo ""
echo "=================================================="
echo "🔬 TEST 4: Try with explicit home/config dirs..."
echo "=================================================="

mkdir -p "$HOME/.config/Antigravity"
mkdir -p "$HOME/.local/share/Antigravity"

export HOME="$HOME"
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_DATA_HOME="$HOME/.local/share"

timeout 10 $UNWRAPPED/bin/antigravity --no-sandbox 2>&1 || true

echo ""
echo "🔍 Checking for any config files created..."
find "$HOME/.config" -name "*ntigravity*" -o -name "*ntigravity*" 2>/dev/null | head -20
find "$HOME/.local" -name "*ntigravity*" -o -name "*ntigravity*" 2>/dev/null | head -20

echo ""
echo "Press Ctrl+C to exit."

cleanup() {
    echo "🧹 Stopping..."
    kill ${WEBSOCKIFY_PID:-} ${VNC_PID:-} ${DBUS_PID:-} 2>/dev/null
}
trap cleanup EXIT INT TERM

# Keep alive
sleep infinity
