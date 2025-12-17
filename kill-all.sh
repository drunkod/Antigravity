#!/usr/bin/env bash

# Nuclear option - kill everything
echo "💣 Killing ALL VNC and Antigravity processes..."

pkill -9 antigravity 2>/dev/null || true
pkill -9 websockify 2>/dev/null || true
pkill -9 fluxbox 2>/dev/null || true
pkill -9 Xvnc 2>/dev/null || true

# Clean up files
rm -f "$HOME/.antigravity-vnc.pid"
rm -f "$HOME/.antigravity-vnc.lock"
rm -f "$HOME/.antigravity-vnc.log"

echo "✅ All processes killed"
echo ""
ps aux | grep -E "(antigravity|websockify|fluxbox|Xvnc)" | grep -v grep || echo "No processes found"
