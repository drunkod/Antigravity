#!/usr/bin/env bash

echo "🎨 Fixing Antigravity Terminal Font"
echo "===================================="
echo ""

SETTINGS_FILE="$HOME/.config/Antigravity/User/settings.json"
BASH_PATH=$(readlink -f ./result/bin/bash 2>/dev/null || echo "bash")

# Backup existing settings
if [ -f "$SETTINGS_FILE" ]; then
    cp "$SETTINGS_FILE" "$SETTINGS_FILE.backup-$(date +%s)"
    echo "📦 Backed up existing settings"
fi

# Create settings with proper font configuration
cat > "$SETTINGS_FILE" <<'EOF'
{
    // ===== TERMINAL FONT CONFIGURATION =====
    "terminal.integrated.fontFamily": "'JetBrains Mono', 'Fira Code', 'Cascadia Code', 'DejaVu Sans Mono', monospace",
    "terminal.integrated.fontSize": 13,
    "terminal.integrated.fontWeight": "normal",
    "terminal.integrated.lineHeight": 1.3,
    "terminal.integrated.letterSpacing": 0,

    // ===== FONT RENDERING =====
    "terminal.integrated.rendererType": "dom",
    "terminal.integrated.smoothScrolling": false,
    "terminal.integrated.fastScrollSensitivity": 5,

    // ===== SHELL CONFIGURATION =====
    "terminal.integrated.shellIntegration.enabled": false,
    "terminal.integrated.defaultProfile.linux": "bash",
    "terminal.integrated.profiles.linux": {
        "bash": {
            "path": "BASH_PATH_PLACEHOLDER",
            "icon": "terminal-bash",
            "args": ["--login"]
        }
    },

    // ===== TERMINAL BEHAVIOR =====
    "terminal.integrated.scrollback": 10000,
    "terminal.integrated.cursorBlinking": true,
    "terminal.integrated.cursorStyle": "line",
    "terminal.integrated.cursorWidth": 2,
    "terminal.integrated.copyOnSelection": true,
    "terminal.integrated.drawBoldTextInBrightColors": true,

    // ===== ENVIRONMENT =====
    "terminal.integrated.env.linux": {
        "TERM": "xterm-256color",
        "COLORTERM": "truecolor"
    },

    // ===== EDITOR FONT (bonus) =====
    "editor.fontFamily": "'JetBrains Mono', 'Fira Code', 'Cascadia Code', 'DejaVu Sans Mono', monospace",
    "editor.fontSize": 13,
    "editor.fontLigatures": true,
    "editor.lineHeight": 20,

    // ===== OTHER =====
    "security.workspace.trust.enabled": false,
    "terminal.explorerKind": "external",
    "workbench.colorTheme": "Default Dark Modern"
}
EOF

# Replace placeholder with actual bash path
sed -i "s|BASH_PATH_PLACEHOLDER|$BASH_PATH|g" "$SETTINGS_FILE"

echo "✅ Settings updated!"
echo ""
echo "Configuration:"
echo "  Font: JetBrains Mono (primary)"
echo "  Fallbacks: Fira Code, Cascadia Code, DejaVu Sans Mono"
echo "  Size: 13px"
echo "  Line height: 1.3"
echo "  Renderer: DOM (more stable)"
echo ""
echo "🔄 Restart Antigravity to apply:"
echo "   ./stop-vnc.sh && ./start-with-vnc.sh"
