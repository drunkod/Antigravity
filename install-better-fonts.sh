#!/usr/bin/env bash

echo "🔤 Installing Better Terminal Fonts"
echo "===================================="
echo ""

# Create fonts directory
mkdir -p ~/.local/share/fonts
cd ~/.local/share/fonts

echo "📦 Downloading JetBrains Mono (best coding font)..."
wget -q https://github.com/JetBrains/JetBrainsMono/releases/download/v2.304/JetBrainsMono-2.304.zip

echo "📦 Extracting fonts..."
unzip -q JetBrainsMono-2.304.zip
mv fonts/ttf/*.ttf .
rm -rf fonts *.zip

echo "📦 Downloading Fira Code (alternative)..."
wget -q https://github.com/tonsky/FiraCode/releases/download/6.2/Fira_Code_v6.2.zip
unzip -q Fira_Code_v6.2.zip -d FiraCode
mv FiraCode/ttf/*.ttf .
rm -rf FiraCode *.zip

echo "📦 Downloading Cascadia Code (Microsoft)..."
wget -q https://github.com/microsoft/cascadia-code/releases/download/v2111.01/CascadiaCode-2111.01.zip
unzip -q CascadiaCode-2111.01.zip
mv ttf/*.ttf .
rm -rf ttf otf woff2 *.zip

echo ""
echo "✅ Fonts installed to ~/.local/share/fonts"
echo ""
echo "Installed fonts:"
ls -1 ~/.local/share/fonts/*.ttf | wc -l
echo ""

# Update font cache
if command -v fc-cache >/dev/null 2>&1; then
    echo "🔄 Updating font cache..."
    fc-cache -f ~/.local/share/fonts
    echo "✅ Font cache updated"
else
    echo "⚠️  fc-cache not found, fonts may not be immediately available"
fi

echo ""
echo "✅ Done! Now run: ./fix-terminal-font.sh"
