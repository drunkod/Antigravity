#!/usr/bin/env nix-shell
#! nix-shell -i bash -p dejavu_fonts liberation_ttf noto-fonts fontconfig git procps curl chromium fluxbox tigervnc xterm

set -e

export DISPLAY=:99
export NIXPKGS_ALLOW_UNFREE=1

echo "============================================"
echo "🚀 Antigravity VNC Launcher (Debug Mode)"
echo "============================================"

# Get real chromium path BEFORE modifying PATH
REAL_CHROMIUM=$(which chromium)
echo "🔍 Real Chromium: $REAL_CHROMIUM"

echo "🛠️  Configuring Fonts..."
export FONTCONFIG_FILE=$(nix-build --no-out-link -E 'with import <nixpkgs> {}; makeFontsConf { fontDirectories = [ dejavu_fonts liberation_ttf noto-fonts ]; }')

echo "🔧 Creating URL interceptor..."
mkdir -p /tmp/fake-bin
rm -f /tmp/auth_url_capture.txt /tmp/interceptor.log
touch /tmp/auth_url_capture.txt /tmp/interceptor.log

# Create interceptor with FULL logging
cat > /tmp/fake-bin/browser-interceptor <<ENDSCRIPT
#!/bin/bash
exec >> /tmp/interceptor.log 2>&1
echo ""
echo "========================================"
echo "[\$(date)] INTERCEPTOR CALLED"
echo "Args: \$@"
echo "DISPLAY: \$DISPLAY"
echo "PWD: \$(pwd)"
echo "========================================"

# Write URL to capture file
echo "\$@" >> /tmp/auth_url_capture.txt

# Find and open URL
for arg in "\$@"; do
    echo "Checking arg: \$arg"
    if [[ "\$arg" == http* ]]; then
        echo "Found URL: \$arg"
        echo "Launching: $REAL_CHROMIUM --no-sandbox --disable-gpu \$arg"
        DISPLAY=:99 $REAL_CHROMIUM --no-sandbox --disable-gpu --disable-dev-shm-usage "\$arg" &
        CHROME_PID=\$!
        echo "Chrome launched with PID: \$CHROME_PID"
        sleep 1
        if kill -0 \$CHROME_PID 2>/dev/null; then
            echo "Chrome is running!"
        else
            echo "Chrome may have exited"
        fi
        exit 0
    fi
done

echo "No http URL found in args, trying first arg..."
if [[ -n "\$1" ]]; then
    echo "Opening: \$1"
    DISPLAY=:99 $REAL_CHROMIUM --no-sandbox --disable-gpu --disable-dev-shm-usage "\$1" &
fi
ENDSCRIPT
chmod +x /tmp/fake-bin/browser-interceptor

# Create symlinks
for cmd in xdg-open x-www-browser google-chrome google-chrome-stable chromium chromium-browser firefox sensible-browser open; do
    ln -sf /tmp/fake-bin/browser-interceptor /tmp/fake-bin/$cmd
done

# Show interceptor log in real-time
tail -F /tmp/interceptor.log 2>/dev/null &
LOGWATCH_PID=$!

# URL watcher
(tail -F /tmp/auth_url_capture.txt 2>/dev/null | while read line; do
    if [[ -n "$line" ]]; then
        echo ""
        echo "📋 URL CAPTURED: $line"
        echo ""
    fi
done) &
WATCHER_PID=$!

# Clone noVNC
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
sleep 2

echo "🌐 Starting noVNC proxy..."
cd ~/noVNC
websockify --web=. 5999 localhost:5900 2>&1 &
WEBSOCKIFY_PID=$!
sleep 2

# Launch Chromium directly (to verify it works)
echo "🌍 Testing Chromium launch..."
DISPLAY=:99 $REAL_CHROMIUM --no-sandbox --disable-gpu --disable-dev-shm-usage about:blank 2>/dev/null &
CHROME_PID=$!
sleep 3

if kill -0 $CHROME_PID 2>/dev/null; then
    echo "✅ Chromium works! PID=$CHROME_PID"
else
    echo "❌ Chromium failed to start"
fi

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
nix build . --impure 2>&1 | grep -v "^evaluating"

# Set all browser environment variables
export PATH=/tmp/fake-bin:$PATH
export BROWSER=/tmp/fake-bin/browser-interceptor
export CHROME_PATH=/tmp/fake-bin/browser-interceptor
export CHROME_EXECUTABLE=/tmp/fake-bin/browser-interceptor
export CHROME_BIN=/tmp/fake-bin/browser-interceptor

echo ""
echo "🧪 Testing interceptor manually..."
/tmp/fake-bin/xdg-open "https://example.com"
sleep 2
echo "Check /tmp/interceptor.log for output"
cat /tmp/interceptor.log
echo ""

echo "🚀 Launching Antigravity..."
DISPLAY=:99 ./result/bin/antigravity --disable-gpu --no-sandbox 2>&1 &
APP_PID=$!

echo ""
echo "🎮 App running (PID $APP_PID)!"
echo ""
echo "📌 Interceptor log: tail -f /tmp/interceptor.log"
echo "📌 URL captures: tail -f /tmp/auth_url_capture.txt"
echo ""
echo "Press Ctrl+C to stop."
echo ""

# Cleanup
cleanup() {
    echo "🧹 Stopping..."
    kill $APP_PID $CHROME_PID $WEBSOCKIFY_PID $VNC_PID $WATCHER_PID $LOGWATCH_PID 2>/dev/null
}
trap cleanup EXIT INT TERM

wait $APP_PID