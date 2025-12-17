#!/usr/bin/env bash

XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/tmp/xdg-runtime-$USER}"

# Nuclear option - kill everything
echo "💣 Killing ALL VNC and Antigravity processes..."

pkill -9 -f "antigravity" 2>/dev/null || true
pkill -9 -f "websockify.*5999" 2>/dev/null || true
pkill -9 fluxbox 2>/dev/null || true
pkill -9 -f "Xvnc :99" 2>/dev/null || true
pkill -9 -f "dbus-daemon.*$XDG_RUNTIME_DIR" 2>/dev/null || true

# Clean up files and sockets
rm -f "$HOME/.antigravity-vnc.pid"
rm -f "$HOME/.antigravity-vnc.lock"
rm -f "$HOME/.antigravity-vnc.log"
rm -f "$XDG_RUNTIME_DIR/bus"

sleep 1

echo "✅ All processes killed"
echo ""
echo "🔍 Remaining processes:"
ps aux | grep -E "(antigravity|websockify|fluxbox|Xvnc :99)" | grep -v grep || echo "   No processes found ✅"
