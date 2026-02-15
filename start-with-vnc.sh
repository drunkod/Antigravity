#!/usr/bin/env nix-shell
#! nix-shell -i bash -p dejavu_fonts liberation_ttf noto-fonts fontconfig git procps fluxbox tigervnc dbus psmisc wget unzip xray proxychains-ng curl xterm xdotool chromium xrdb

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
# Match actual app binaries, not paths like .../antigravity/v2ray-client.json
APP_PATTERN="bin/antigravity"

echo "============================================"
echo "🚀 Antigravity VNC Launcher (with VPN)"
echo "============================================"

# Kill ALL existing Antigravity app processes first
echo "🧹 Checking for existing Antigravity instances..."
EXISTING_PIDS=$(pgrep -f "$APP_PATTERN" || true)
if [ -n "$EXISTING_PIDS" ]; then
    echo "   Found running instances, stopping them..."
    pkill -9 -f "$APP_PATTERN" 2>/dev/null || true
    sleep 2
    STILL_RUNNING=$(pgrep -f "$APP_PATTERN" || true)
    if [ -n "$STILL_RUNNING" ]; then
        echo "   ⚠️  Some processes still running: $STILL_RUNNING"
        kill -9 $STILL_RUNNING 2>/dev/null || true
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

# Capture real IP before any proxy is set
REAL_IP=$(curl -s --connect-timeout 5 https://ifconfig.me 2>/dev/null || echo "unknown")

# Determine which config to use
VPN_CONFIG=""
if [ -f "$SCRIPT_DIR/v2ray-client.json" ]; then
    VPN_CONFIG="$SCRIPT_DIR/v2ray-client.json"
elif [ -f "$SCRIPT_DIR/v2ray-client-reality.json" ]; then
    VPN_CONFIG="$SCRIPT_DIR/v2ray-client-reality.json"
fi

if [ -n "$VPN_CONFIG" ]; then
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

        pkill -f "xray run" 2>/dev/null || true
        sleep 1

        xray run -config "$VPN_CONFIG" > "$VPN_LOG_FILE" 2>&1 &
        XRAY_PID=$!
        echo "$XRAY_PID" > "$VPN_PID_FILE"
        sleep 3

        if kill -0 "$XRAY_PID" 2>/dev/null; then
            VPN_ENABLED=true
            echo "   ✅ Xray started (PID $XRAY_PID)"

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

            echo "   🔍 Testing VPN connection..."
            if VPN_IP=$(curl -s --connect-timeout 8 --proxy "socks5h://127.0.0.1:$SOCKS_PORT" https://ifconfig.me 2>/dev/null); then
                echo "   🌍 Real IP: $REAL_IP"
                echo "   🔒 VPN IP:  $VPN_IP"
                if [ "$VPN_IP" != "$REAL_IP" ]; then
                    echo "   ✅ IP is different — VPN is active!"
                else
                    echo "   ⚠️  IPs match — check server config"
                fi
            else
                echo "   ⚠️  VPN proxy running but connectivity test failed"
                echo "      Check log: tail -f $VPN_LOG_FILE"
            fi

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

# ============================================================
#  Create a Chromium launcher script that Fluxbox can use
# ============================================================
echo "🌐 Creating browser launcher..."
mkdir -p "$HOME/.local/bin"

CHROMIUM_REAL="$(command -v chromium 2>/dev/null || true)"

if [ -n "$CHROMIUM_REAL" ]; then
    cat > "$HOME/.local/bin/browser" <<BROWSEREOF
#!/usr/bin/env bash
# Chromium launcher for VNC desktop

PROXY_ARGS=""
if [ -n "\${PROXY_SOCKS5:-}" ]; then
    PROXY_ARGS="--proxy-server=socks5://\$PROXY_SOCKS5"
elif [ -n "\${ALL_PROXY:-}" ]; then
    PROXY_ARGS="--proxy-server=\$ALL_PROXY"
fi

exec "$CHROMIUM_REAL" \\
    --no-sandbox \\
    --disable-gpu \\
    --disable-gpu-compositing \\
    --disable-gpu-sandbox \\
    --disable-software-rasterizer \\
    --disable-dev-shm-usage \\
    --disable-vulkan \\
    --disable-features=VizDisplayCompositor,Vulkan,UseSkiaRenderer \\
    --enable-features=UseOzonePlatform \\
    --ozone-platform=x11 \\
    --disable-accelerated-2d-canvas \\
    --disable-accelerated-video-decode \\
    --disable-breakpad \\
    --user-data-dir="\$HOME/.chromium-vnc" \\
    \$PROXY_ARGS \\
    "\$@"
BROWSEREOF
    chmod +x "$HOME/.local/bin/browser"
    BROWSER_CMD="$HOME/.local/bin/browser"
    echo "   ✅ Browser launcher: $BROWSER_CMD"
    echo "   ✅ Chromium binary:  $CHROMIUM_REAL"
else
    BROWSER_CMD=""
    echo "   ⚠️  Chromium not found — browser menu disabled"
fi

# ============================================================
#  Configure Fluxbox menu, keys, and settings
# ============================================================
echo "🖥️  Configuring Fluxbox..."
mkdir -p "$HOME/.fluxbox"

TERMINAL_BIN="$(command -v xterm 2>/dev/null || true)"
SHELL_BIN="$(command -v bash 2>/dev/null || command -v sh 2>/dev/null || echo "/bin/sh")"

if [ -z "$TERMINAL_BIN" ]; then
    echo "   ⚠️  No terminal emulator found in PATH"
fi

# Build the menu file
cat > "$HOME/.fluxbox/menu" <<MENUEOF
[begin] (Antigravity Desktop)
  [submenu] (Terminal)
    [exec] (XTerm) {${TERMINAL_BIN} -fa "DejaVu Sans Mono" -fs 11}
    [exec] (XTerm Dark) {${TERMINAL_BIN} -bg black -fg white -fa "DejaVu Sans Mono" -fs 11}
    [exec] (XTerm Large) {${TERMINAL_BIN} -bg black -fg green -fa "DejaVu Sans Mono" -fs 14}
    [exec] (Bash Login) {${TERMINAL_BIN} -e ${SHELL_BIN} --login}
  [end]
MENUEOF

if [ -n "$BROWSER_CMD" ]; then
cat >> "$HOME/.fluxbox/menu" <<MENUEOF
  [submenu] (Web Browser)
    [exec] (Chromium) {${BROWSER_CMD}}
    [exec] (Chromium — google.com) {${BROWSER_CMD} https://www.google.com}
    [exec] (Chromium — check IP) {${BROWSER_CMD} https://ifconfig.me}
  [end]
MENUEOF
fi

cat >> "$HOME/.fluxbox/menu" <<MENUEOF
  [submenu] (Tools)
    [exec] (File Listing) {${TERMINAL_BIN} -fa "DejaVu Sans Mono" -fs 11 -e ${SHELL_BIN} -lc 'ls -la ~; echo "---"; read -rp "Press Enter..."'}
    [exec] (Disk Usage) {${TERMINAL_BIN} -fa "DejaVu Sans Mono" -fs 11 -e ${SHELL_BIN} -lc 'df -h; echo "---"; read -rp "Press Enter..."'}
    [exec] (Processes) {${TERMINAL_BIN} -fa "DejaVu Sans Mono" -fs 11 -e ${SHELL_BIN} -lc 'ps aux; echo "---"; read -rp "Press Enter..."'}
    [exec] (Network Info) {${TERMINAL_BIN} -fa "DejaVu Sans Mono" -fs 11 -e ${SHELL_BIN} -lc 'echo "Hostname: \$(hostname)"; echo; ip addr 2>/dev/null || ifconfig 2>/dev/null; echo "---"; read -rp "Press Enter..."'}
  [end]
  [submenu] (VPN)
    [exec] (VPN Status) {${TERMINAL_BIN} -fa "DejaVu Sans Mono" -fs 11 -hold -e ${SHELL_BIN} -lc 'cd ~/antigravity && ${SHELL_BIN} status-vnc.sh'}
    [exec] (Check VPN IP) {${TERMINAL_BIN} -fa "DejaVu Sans Mono" -fs 11 -hold -e ${SHELL_BIN} -lc 'echo "=== VPN IP ==="; curl -s --connect-timeout 5 --proxy socks5h://127.0.0.1:10808 https://ifconfig.me 2>/dev/null || echo FAILED; echo; echo "=== Direct IP ==="; env -u http_proxy -u https_proxy -u all_proxy -u HTTP_PROXY -u HTTPS_PROXY -u ALL_PROXY curl -s --connect-timeout 5 https://ifconfig.me 2>/dev/null || echo FAILED; echo'}
    [exec] (VPN Log) {${TERMINAL_BIN} -fa "DejaVu Sans Mono" -fs 11 -e ${SHELL_BIN} -lc 'tail -50f ~/.xray-vpn.log'}
    [exec] (App Log) {${TERMINAL_BIN} -fa "DejaVu Sans Mono" -fs 11 -e ${SHELL_BIN} -lc 'tail -50f ~/.antigravity-vnc.log'}
  [end]
  [separator]
  [submenu] (Fluxbox)
    [workspaces] (Workspaces)
    [submenu] (Styles)
      [stylesdir] (/usr/share/fluxbox/styles)
      [stylesdir] (~/.fluxbox/styles)
    [end]
    [config] (Configure)
    [reconfig] (Reconfigure)
    [restart] (Restart Fluxbox)
  [end]
  [separator]
  [exit] (Exit Fluxbox)
[end]
MENUEOF

# Build keybindings
cat > "$HOME/.fluxbox/keys" <<KEYSEOF
# Ctrl+Alt+T = terminal
Control Mod1 T :Exec ${TERMINAL_BIN} -fa "DejaVu Sans Mono" -fs 11 -bg black -fg white
KEYSEOF

if [ -n "$BROWSER_CMD" ]; then
cat >> "$HOME/.fluxbox/keys" <<KEYSEOF
# Ctrl+Alt+B = browser
Control Mod1 B :Exec ${BROWSER_CMD}
KEYSEOF
fi

cat >> "$HOME/.fluxbox/keys" <<'KEYSEOF'

# Window management
Mod1 Tab :NextWindow {groups} (workspace=[current])
Mod1 Shift Tab :PrevWindow {groups} (workspace=[current])
Mod1 F4 :Close
Mod1 F9 :Minimize
Mod1 F10 :Maximize
Mod1 F5 :KillWindow

# Titlebar: drag to move, right-drag to resize
OnTitlebar Mouse1 :MacroCmd {Raise} {Focus} {StartMoving}
OnTitlebar Mouse3 :MacroCmd {Raise} {Focus} {StartResizing NearestCorner}

# Desktop: right-click = menu, scroll = switch workspace
OnDesktop Mouse3 :RootMenu
OnDesktop Mouse2 :WorkspaceMenu
OnDesktop Mouse4 :PrevWorkspace
OnDesktop Mouse5 :NextWorkspace

# Window snapping (Super+arrow)
Mod4 Left  :MacroCmd {ResizeTo 50% 100%} {MoveTo 0 0 Left}
Mod4 Right :MacroCmd {ResizeTo 50% 100%} {MoveTo 0 0 Right}
Mod4 Up    :Maximize
KEYSEOF

cat > "$HOME/.fluxbox/init" <<'INITEOF'
session.screen0.toolbar.visible: true
session.screen0.toolbar.placement: BottomCenter
session.screen0.toolbar.widthPercent: 100
session.screen0.toolbar.height: 24
session.screen0.toolbar.tools: prevworkspace, workspacename, nextworkspace, iconbar, systemtray, clock
session.screen0.workspaces: 4
session.screen0.workspaceNames: Main,Web,Term,Misc
session.screen0.tab.placement: TopLeft
session.screen0.tab.width: 64
session.screen0.window.focus.alpha: 255
session.screen0.window.unfocus.alpha: 200
session.screen0.menu.alpha: 230
session.menuFile: ~/.fluxbox/menu
session.keyFile: ~/.fluxbox/keys
session.configVersion: 13
INITEOF

cat > "$HOME/.Xresources" <<'XREOF'
XTerm*faceName: DejaVu Sans Mono
XTerm*faceSize: 11
XTerm*background: #1e1e1e
XTerm*foreground: #d4d4d4
XTerm*cursorColor: #ffffff
XTerm*scrollBar: true
XTerm*rightScrollBar: true
XTerm*saveLines: 10000
XTerm*selectToClipboard: true
XTerm*metaSendsEscape: true
XTerm*eightBitInput: false
XTerm*termName: xterm-256color
XTerm*color0:  #1e1e1e
XTerm*color1:  #f44747
XTerm*color2:  #6a9955
XTerm*color3:  #dcdcaa
XTerm*color4:  #569cd6
XTerm*color5:  #c586c0
XTerm*color6:  #4ec9b0
XTerm*color7:  #d4d4d4
XTerm*color8:  #808080
XTerm*color9:  #f44747
XTerm*color10: #6a9955
XTerm*color11: #dcdcaa
XTerm*color12: #569cd6
XTerm*color13: #c586c0
XTerm*color14: #4ec9b0
XTerm*color15: #ffffff
XREOF

echo "   ✅ Fluxbox menu, keys, and theme configured"

# Clone noVNC if needed
if [ ! -d ~/noVNC ]; then
    echo "📦 Cloning noVNC..."
    env -u http_proxy -u https_proxy -u all_proxy -u HTTP_PROXY -u HTTPS_PROXY -u ALL_PROXY \
        git clone --depth 1 https://github.com/novnc/noVNC.git ~/noVNC
fi

echo "🚀 Starting VNC Server..."
Xvnc :99 -geometry 1920x1080 -depth 24 -SecurityTypes None -rfbport 5900 -dpi 96 2>&1 &
VNC_PID=$!
sleep 3

# Load Xresources for xterm theming
if [ -f "$HOME/.Xresources" ]; then
    DISPLAY=:99 xrdb -merge "$HOME/.Xresources" 2>/dev/null || true
fi

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
echo ""
echo "🖥️  Right-click desktop → menu | Ctrl+Alt+T → terminal | Ctrl+Alt+B → browser"
echo "============================================"
echo ""

# Build Antigravity
echo "🔨 Building Antigravity..."
cd ~/antigravity
nix build . --impure 2>&1 | grep -v "warning: Git tree" || true

# Verify VPN survived the build
if [ "$VPN_ENABLED" = true ]; then
    if kill -0 "$XRAY_PID" 2>/dev/null; then
        echo "   ✅ VPN still running after build (PID $XRAY_PID)"
    else
        echo "   ⚠️  VPN died during build! Restarting..."
        xray run -config "$VPN_CONFIG" > "$VPN_LOG_FILE" 2>&1 &
        XRAY_PID=$!
        echo "$XRAY_PID" > "$VPN_PID_FILE"
        sleep 3
        if kill -0 "$XRAY_PID" 2>/dev/null; then
            echo "   ✅ VPN restarted (PID $XRAY_PID)"
        else
            echo "   ❌ VPN restart failed"
            VPN_ENABLED=false
        fi
    fi
fi

echo "🚀 Launching Antigravity..."
echo "   Logging to: $LOG_FILE"

# Kill only app processes, not xray config paths containing "antigravity"
pkill -9 -f "$APP_PATTERN" 2>/dev/null || true
sleep 1

DISPLAY=:99 ./result/bin/antigravity --verbose 2>&1 | \
  grep -v "Failed to connect to the bus" | \
  grep -v "ALSA lib" | \
  grep -v "PcmOpen" > "$LOG_FILE" &

APP_PID=$!
echo "$APP_PID" > "$LOCK_FILE"

sleep 3

if ! kill -0 "$APP_PID" 2>/dev/null; then
    echo "   ❌ Antigravity crashed! Check log:"
    tail -20 "$LOG_FILE"
    rm -f "$LOCK_FILE"
    exit 1
fi

ANTIGRAVITY_COUNT=$(pgrep -f "$APP_PATTERN" | wc -l)
echo "   ✅ Antigravity started (main PID $APP_PID)"
echo "   📊 Electron processes: $ANTIGRAVITY_COUNT"

# Final VPN check after everything is launched
if [ "$VPN_ENABLED" = true ]; then
    if kill -0 "$XRAY_PID" 2>/dev/null; then
        echo "   🔐 VPN confirmed running (PID $XRAY_PID)"
    else
        echo "   ⚠️  VPN is not running!"
    fi
fi

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
