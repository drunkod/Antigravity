#!/usr/bin/env bash

# Create Antigravity settings to disable shell integration
mkdir -p ~/.config/Antigravity/User

SETTINGS_FILE="$HOME/.config/Antigravity/User/settings.json"

# Backup existing settings
if [ -f "$SETTINGS_FILE" ]; then
    cp "$SETTINGS_FILE" "$SETTINGS_FILE.backup"
    echo "📦 Backed up existing settings"
fi

# Create/update settings to disable shell integration
cat > "$SETTINGS_FILE" <<'EOF'
{
    "terminal.integrated.shellIntegration.enabled": false,
    "terminal.integrated.defaultProfile.linux": "bash",
    "terminal.integrated.profiles.linux": {
        "bash": {
            "path": "/nix/store/q1fh240ja6y0nq9iy3cyin6lc5js22bv-antigravity-wrapped/bin/bash",
            "icon": "terminal-bash"
        }
    }
}
EOF

echo "✅ Disabled shell integration in Antigravity settings"
echo "   Settings file: $SETTINGS_FILE"
echo ""
echo "Now restart Antigravity:"
echo "  ./stop-vnc.sh && ./start-with-vnc.sh"
