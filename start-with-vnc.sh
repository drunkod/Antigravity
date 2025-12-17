#!/usr/bin/env nix-shell
#! nix-shell -i bash -p dejavu_fonts liberation_ttf noto-fonts fontconfig git procps fluxbox tigervnc dbus

export DISPLAY_NUM=${DISPLAY_NUM:-99}
VNC_PORT=$((5900 + DISPLAY_NUM - 99))
WEB_PORT=$((5999 + DISPLAY_NUM - 99))

export DISPLAY=:$DISPLAY_NUM
export NIXPKGS_ALLOW_UNFREE=1

PID_FILE="$HOME/.antigravity-vnc.pid"

echo "============================================"
echo "🚀 Antigravity VNC Launcher"
echo "============================================"

# Fonts
export FONTCONFIG_FILE=$(nix-build --no-out-link -E 'with import <nixpkgs> {}; makeFontsConf { fontDirectories = [ dejavu_fonts liberation_ttf noto-fonts ]; }')

# DBus session
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
  fi
fi

# Software rendering
export LIBGL_ALWAYS_SOFTWARE=1
export MESA_LOADER_DRIVER_OVERRIDE=swrast
export GALLIUM_DRIVER=llvmpipe

# noVNC
if [ ! -d ~/noVNC ]; then
    git clone --depth 1 https://github.com/novnc/noVNC.git ~/noVNC
fi

# Start VNC
echo "🚀 Starting VNC Server..."
Xvnc :$DISPLAY_NUM -geometry 1920x1080 -depth 24 -SecurityTypes None -rfbport $VNC_PORT -dpi 96 2>&1 &
VNC_PID=$!
sleep 3

# Window manager
echo "🖥️  Starting Fluxbox..."
DISPLAY=:$DISPLAY_NUM fluxbox 2>/dev/null &
FLUXBOX_PID=$!
sleep 1

# noVNC proxy
echo "🌐 Starting noVNC..."
cd ~/noVNC
websockify --web=. $WEB_PORT localhost:$VNC_PORT 2>&1 &
WEBSOCKIFY_PID=$!
sleep 1

echo ""
echo "============================================"
echo "✅ VNC READY!"
echo "📺 https://$WEB_PORT-firebase-antigravity-1763533608633.cluster-iusnsmywp5clov45nv5gsxt5he.cloudworkstations.dev/vnc.html"
echo "============================================"
echo ""

# Build and run
cd ~/antigravity
echo "🔨 Building Antigravity..."
nix build . --impure

echo "🚀 Launching Antigravity..."
./result/bin/antigravity 2>&1 &
APP_PID=$!

# Save PIDs for later cleanup
echo "$VNC_PID $FLUXBOX_PID $WEBSOCKIFY_PID $APP_PID ${DBUS_PID:-}" > "$PID_FILE"

echo "🎮 App running (PID $APP_PID)"
echo ""
echo "✨ Services are running in background"
echo "   To stop all services, run: ./stop-vnc.sh"
echo ""
