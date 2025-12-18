#!/usr/bin/env bash

echo "🔍 Antigravity Terminal Debug Info"
echo "=================================="
echo ""

echo "1. Bash Location:"
which bash
ls -la $(which bash)
echo ""

echo "2. Bash Version:"
bash --version | head -1
echo ""

echo "3. SHELL variable:"
echo "$SHELL"
echo ""

echo "4. PATH:"
echo "$PATH" | tr ':' '\n'
echo ""

echo "5. Available commands:"
for cmd in git ls cat grep sed find which ps top; do
    if command -v $cmd >/dev/null 2>&1; then
        echo "  ✅ $cmd: $(which $cmd)"
    else
        echo "  ❌ $cmd: NOT FOUND"
    fi
done
echo ""

echo "6. Terminal info:"
echo "  TERM: $TERM"
echo "  PWD: $PWD"
echo "  USER: $USER"
echo "  HOME: $HOME"
echo ""

echo "7. Test basic commands:"
echo "  ls: $(ls / | wc -l) items in /"
echo "  git: $(git --version)"
echo ""

echo "8. Nix store bash:"
ls -la /nix/store/*bash*/bin/bash 2>/dev/null | head -5
