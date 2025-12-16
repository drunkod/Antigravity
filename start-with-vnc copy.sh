#!/usr/bin/env nix-shell
#! nix-shell -i bash -p dejavu_fonts liberation_ttf noto-fonts fontconfig git procps curl strace

export DISPLAY=:99
export NIXPKGS_ALLOW_UNFREE=1

echo "🛠️  Configuring Fonts..."
export FONTCONFIG_FILE=$(nix-build --no-out-link -E 'with import <nixpkgs> {}; makeFontsConf { fontDirectories = [ dejavu_fonts liberation_ttf noto-fonts ]; }')

echo "🔧 Creating comprehensive URL interceptor..."
mkdir -p /tmp/fake-bin

# Create interceptors for ALL possible browser launch methods
for cmd in xdg-open x-www-browser google-chrome chromium firefox sensible-browser; do
cat <<'EOF' > /tmp/fake-bin/$cmd
#!/bin/sh
echo "**********************************************************************" >&2
echo "[$0] Captured: $@" >&2
echo "**********************************************************************" >&2
echo "$@" >> /tmp/auth_url_capture.txt
EOF
chmod +x /tmp/fake-bin/$cmd
done

export PATH=/tmp/fake-bin:$PATH
export BROWSER=/tmp/fake-bin/xdg-open
echo "" > /tmp/auth_url_capture.txt

# Watcher (same as before)
(tail -F /tmp/auth_url_capture.txt | while read url; do
  if [[ "$url" == http* ]]; then
      echo ""
      echo "🔥🔥🔥 AUTH URL CAPTURED 🔥🔥🔥"
      echo "$url"
      echo ""
  fi
done) &
WATCHER_PID=$!

# VNC setup (same as before)
if [ ! -d ~/noVNC ]; then
    git clone --depth 1 https://github.com/novnc/noVNC.git ~/noVNC
fi

echo "🚀 Starting services..."
Xvnc :99 -geometry 1920x1080 -depth 24 -SecurityTypes None -rfbport 5900 -dpi 96 &
VNC_PID=$!
sleep 3

DISPLAY=:99 fluxbox &
sleep 2

cd ~/noVNC
websockify --web=. 5999 localhost:5900 &
WEBSOCKIFY_PID=$!
sleep 2

echo "✅ VNC: https://5999-firebase-antigravity-1763533608633.cluster-iusnsmywp5clov45nv5gsxt5he.cloudworkstations.dev/vnc.html"

echo "🔨 Building App..."
cd ~/antigravity
nix build .

echo "🚀 Launching App with tracing..."
# Run with strace to see ALL system calls
strace -f -e trace=execve -s 9999 ./result/bin/antigravity --disable-gpu --no-sandbox --enable-features="DnsOverHttps" --dns-over-https-templates="https://xbox-dns.ru/dns-query" 2>&1 | tee /tmp/strace.log &
APP_PID=$!

# Watch for URLs in strace output
tail -F /tmp/strace.log | grep --line-buffered "http" &

wait $APP_PID
kill $VNC_PID $WEBSOCKIFY_PID $WATCHER_PID 2>/dev/null