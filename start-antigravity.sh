#!/usr/bin/env nix-shell
#! nix-shell -i bash -p xorg.xorgserver xvfb-run

export NIXPKGS_ALLOW_UNFREE=1

echo "🚀 Starting Antigravity..."
echo ""
echo "Access points:"
echo "  - Main interface: http://localhost:9092"
echo "  - Onboarding: http://localhost:PORT (check output)"
echo "  - Monitoring: http://localhost:9101/antigravity"
echo ""
echo "Press Ctrl+C to stop, or close this terminal"
echo "----------------------------------------"
echo ""

xvfb-run -a \
  --server-args="-screen 0 1920x1080x24 +extension GLX" \
  nix run . --impure -- \
    --disable-gpu \
    --no-sandbox \
    --disable-dev-shm-usage 2>&1 | grep -v "ERROR:dbus" | grep -v "ERROR:ui/gl"