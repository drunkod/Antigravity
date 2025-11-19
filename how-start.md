nix-shell -p xorg.xorgserver xvfb-run --run "NIXPKGS_ALLOW_UNFREE=1 xvfb-run -a --server-args='-screen 0 1920x1080x24' nix run . --impure -- --disable-gpu --no-sandbox"

NIXPKGS_ALLOW_UNFREE=1 nix run . --impure

$ unset http_proxy https_proxy HTTP_PROXY HTTPS_PROXY no_proxy NO_PROXY && NIXPKGS_ALLOW_UNFREE=1 ~/nixstatic run path:. --impure -- --disable-gpu --no-sandbox

# Unset all proxy variables
unset http_proxy https_proxy HTTP_PROXY HTTPS_PROXY no_proxy NO_PROXY

# Set custom proxy
export http_proxy=http://172.22.138.45:7890
export https_proxy=http://172.22.138.45:7890
export HTTP_PROXY=http://172.22.138.45:7890
export HTTPS_PROXY=http://172.22.138.45:7890

# Run your command
NIXPKGS_ALLOW_UNFREE=1 ~/nixstatic run path:. --impure -- --disable-gpu --no-sandbox