#!/usr/bin/env bash

# Create Antigravity settings to disable shell integration
# and point to the correct bash binary

mkdir -p ~/.config/Antigravity/User
SETTINGS_FILE="$HOME/.config/Antigravity/User/settings.json"

# 1. Determine the correct path to bash
# We want the one inside the Antigravity build if possible, or just "bash"
if [ -f "./result/bin/bash" ]; then
    # Resolve the absolute path to the symlink destination or the symlink itself
    # Using the result link ensures it matches the current build
    BASH_PATH="$(readlink -f ./result/bin/bash)"
    echo "🔍 Found build bash: $BASH_PATH"
else
    # Fallback to just "bash" (relies on PATH being set correctly by wrapper)
    BASH_PATH="bash"
    echo "⚠️  Build not found, falling back to 'bash' in PATH"
fi

# 2. Backup existing settings
if [ -f "$SETTINGS_FILE" ]; then
    cp "$SETTINGS_FILE" "$SETTINGS_FILE.backup"
    echo "📦 Backed up existing settings to $SETTINGS_FILE.backup"
fi

# 3. Write new settings
# We disable shell integration to prevent the "immediate close" and "__vsc_prompt_cmd_original" errors
cat > "$SETTINGS_FILE" <<EOF
{
    "terminal.integrated.shellIntegration.enabled": false,
    "terminal.integrated.defaultProfile.linux": "bash",
    "terminal.integrated.profiles.linux": {
        "bash": {
            "path": "$BASH_PATH",
            "icon": "terminal-bash",
            "args": ["--login"]
        }
    },
    "terminal.explorerKind": "external",
    "security.workspace.trust.enabled": false
}
EOF

echo "✅ Updated settings in $SETTINGS_FILE"
echo "   - Shell Integration: Disabled"
echo "   - Default Profile: bash ($BASH_PATH)"
echo ""
echo "👉 Now restart Antigravity: ./stop-vnc.sh && ./start-with-vnc.sh"
