#!/usr/bin/env bash

echo "🔤 Testing Font Configuration"
echo "=============================="
echo ""

# Check if fonts are installed
echo "1. Checking for fonts in ~/.local/share/fonts:"
if [ -d ~/.local/share/fonts ]; then
    FONT_COUNT=$(find ~/.local/share/fonts -name "*.ttf" | wc -l)
    echo "   Found $FONT_COUNT .ttf files"

    if [ $FONT_COUNT -gt 0 ]; then
        echo ""
        echo "   Installed fonts:"
        find ~/.local/share/fonts -name "*.ttf" | sed 's|.*/||' | sort -u | head -10
    fi
else
    echo "   ⚠️  Font directory not found"
    echo "   Run: ./install-better-fonts.sh"
fi

echo ""
echo "2. Checking settings file:"
SETTINGS="$HOME/.config/Antigravity/User/settings.json"
if [ -f "$SETTINGS" ]; then
    echo "   ✅ Settings file exists"

    if grep -q "JetBrains Mono" "$SETTINGS"; then
        echo "   ✅ JetBrains Mono configured"
    fi

    FONT_SIZE=$(grep "terminal.integrated.fontSize" "$SETTINGS" | grep -o '[0-9]*')
    if [ -n "$FONT_SIZE" ]; then
        echo "   ✅ Font size: ${FONT_SIZE}px"
    fi
else
    echo "   ❌ Settings file not found"
    echo "   Run: ./fix-terminal-font.sh"
fi

echo ""
echo "3. Font rendering test:"
echo "   The quick brown fox jumps over the lazy dog"
echo "   0123456789 | iIlL1 | oO0 | {}[]()<>"
echo "   ═══════════════════════════════════════"
echo ""
