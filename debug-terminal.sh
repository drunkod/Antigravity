#!/usr/bin/env bash

echo "🔍 Antigravity Terminal Debug Info"
echo "=================================="

echo "1. Process Info:"
echo "   PID: $$"
echo "   BASH: $BASH"
echo "   SHELL: $SHELL"
echo ""

echo "2. PATH Check:"
echo "$PATH" | tr ':' '\n' | head -5
echo "... (truncated)"
echo ""

echo "3. Command Availability:"
check_cmd() {
    if command -v "$1" >/dev/null 2>&1; then
        echo "   ✅ $1: $(command -v $1)"
    else
        echo "   ❌ $1: NOT FOUND"
    fi
}

check_cmd git
check_cmd ls
check_cmd grep
check_cmd code
echo ""

echo "4. Environment:"
env | grep -E "TERM|SHELL|VSCODE" | sort
echo ""

echo "5. Git Version:"
git --version 2>&1 || echo "Git failed"
