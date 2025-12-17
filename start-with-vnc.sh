#!/usr/bin/env nix-shell
#! nix-shell -i bash -p dejavu_fonts liberation_ttf noto-fonts fontconfig git procps fluxbox tigervnc dbus

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

# ===== FIX 1: Start DBus session =====
echo "🔌 Starting DBus session..."
if [ -z "$DBUS_SESSION_BUS_ADDRESS" ]; then
    eval $(dbus-launch --sh-syntax)
    export DBUS_SESSION_BUS_ADDRESS
    echo "   DBus started: $DBUS_SESSION_BUS_ADDRESS"
fi

# ===== FIX 2: Disable Vulkan/GPU features =====
export VK_ICD_FILENAMES=""
export LIBVA_DRIVER_NAME=null
export MESA_LOADER_DRIVER_OVERRIDE=swrast
export GALLIUM_DRIVER=llvmpipe
export __EGL_VENDOR_LIBRARY_FILENAMES=""

# Clone noVNC if needed
if [ ! -d ~/noVNC ]; then
    echo "📦 Cloning noVNC..."
    git clone --depth 1 https://github.com/novnc/noVNC.git ~/noVNC
fi

echo "🚀 Starting VNC Server (Display :$DISPLAY_NUM, Port $VNC_PORT)..."
Xvnc :$DISPLAY_NUM -geometry 1920x1080 -depth 24 -SecurityTypes None -rfbport $VNC_PORT -dpi 96 2>&1 &
VNC_PID=$!
sleep 3

echo "🖥️  Starting Fluxbox..."
DISPLAY=:$DISPLAY_NUM fluxbox 2>/dev/null &
sleep 2

echo "🌐 Starting noVNC proxy on port $WEB_PORT..."
cd ~/noVNC
websockify --web=. $WEB_PORT localhost:$VNC_PORT 2>&1 &
WEBSOCKIFY_PID=$!
sleep 2

echo ""
echo "============================================"
echo "✅ VNC READY!"
echo ""
echo "📺 VNC URL:"
echo "https://$WEB_PORT-firebase-antigravity-1763533608633.cluster-iusnsmywp5clov45nv5gsxt5he.cloudworkstations.dev/vnc.html"
echo "============================================"
echo ""

# Build Antigravity
echo "🔨 Building Antigravity..."
cd ~/antigravity
nix build . --impure

echo ""
echo "🔍 DEBUG: DBus address = $DBUS_SESSION_BUS_ADDRESS"
echo ""

echo "🚀 Launching Antigravity..."
DISPLAY=:$DISPLAY_NUM ./result/bin/antigravity 2>&1 &
APP_PID=$!

echo ""
echo "🎮 App running (PID $APP_PID)!"
echo "Press Ctrl+C to stop."

# Cleanup
cleanup() {
    echo "🧹 Stopping..."
    kill $APP_PID $WEBSOCKIFY_PID $VNC_PID 2>/dev/null
}
trap cleanup EXIT INT TERM

wait $APP_PID