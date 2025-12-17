#!/usr/bin/env nix-shell
#! nix-shell -i bash -p dejavu_fonts liberation_ttf noto-fonts fontconfig git procps fluxbox tigervnc dbus

export DISPLAY=:99
export NIXPKGS_ALLOW_UNFREE=1

PID_FILE="$HOME/.antigravity-vnc.pid"

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

echo "🚀 Launching Antigravity..."
DISPLAY=:99 ./result/bin/antigravity 2>&1 &
APP_PID=$!

# Save all PIDs for later management
echo "$VNC_PID $FLUXBOX_PID $WEBSOCKIFY_PID $APP_PID $DBUS_SESSION_BUS_PID" > "$PID_FILE"

echo ""
echo "🎮 App running (PID $APP_PID)!"
echo ""
echo "✨ All services running in background"
echo "   Stop services: ./stop-vnc.sh"
echo "   Check status:  ./status-vnc.sh"
echo ""
