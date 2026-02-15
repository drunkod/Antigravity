{
  description = "Antigravity with Git support";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };
    in
    {
      packages.${system}.default =
        let
          terminalDeps = with pkgs; [
            bashInteractive
            coreutils
            gnugrep
            gnused
            findutils
            procps
            which
            less
            tree
            file
            util-linux
            ncurses
          ];

          fullPath = pkgs.lib.makeBinPath (terminalDeps ++ [ pkgs.git ]);
        in
        pkgs.symlinkJoin {
          name = "antigravity-wrapped";
          paths = [ pkgs.antigravity ];
          nativeBuildInputs = [ pkgs.makeWrapper ];

          postBuild = ''
            mkdir -p $out/bin

            ln -sf ${pkgs.bashInteractive}/bin/bash $out/bin/bash
            ln -sf ${pkgs.bashInteractive}/bin/bash $out/bin/sh

            ln -sf ${pkgs.git}/bin/git $out/bin/git

            # Chrome wrapper — auto-detects VPN proxy
            cat > $out/bin/google-chrome <<'EOF'
#!/usr/bin/env bash
echo "[google-chrome] Opening: $@" >&2

# Build proxy arguments if VPN proxy is active
PROXY_ARGS=""
if [ -n "''${PROXY_SOCKS5:-}" ]; then
  PROXY_ARGS="--proxy-server=socks5://$PROXY_SOCKS5"
  echo "[google-chrome] Using VPN proxy: socks5://$PROXY_SOCKS5" >&2
elif [ -n "''${ALL_PROXY:-}" ]; then
  PROXY_ARGS="--proxy-server=$ALL_PROXY"
  echo "[google-chrome] Using proxy: $ALL_PROXY" >&2
fi

exec ${pkgs.chromium}/bin/chromium \
  --no-sandbox \
  --disable-gpu \
  --disable-gpu-compositing \
  --disable-gpu-sandbox \
  --disable-software-rasterizer \
  --disable-dev-shm-usage \
  --disable-vulkan \
  --disable-features=VizDisplayCompositor,Vulkan,UseSkiaRenderer \
  --enable-features=UseOzonePlatform \
  --ozone-platform=x11 \
  --disable-accelerated-2d-canvas \
  --disable-accelerated-video-decode \
  --disable-breakpad \
  $PROXY_ARGS \
  "$@"
EOF
            chmod +x $out/bin/google-chrome

            # xdg-open wrapper — also proxy-aware
            cat > $out/bin/xdg-open <<'EOF'
#!/usr/bin/env bash
echo "[xdg-open] Opening: $@" >&2

PROXY_ARGS=""
if [ -n "''${PROXY_SOCKS5:-}" ]; then
  PROXY_ARGS="--proxy-server=socks5://$PROXY_SOCKS5"
elif [ -n "''${ALL_PROXY:-}" ]; then
  PROXY_ARGS="--proxy-server=$ALL_PROXY"
fi

exec ${pkgs.chromium}/bin/chromium \
  --no-sandbox \
  --disable-gpu \
  --disable-gpu-compositing \
  --disable-gpu-sandbox \
  --disable-software-rasterizer \
  --disable-dev-shm-usage \
  --disable-vulkan \
  --disable-features=VizDisplayCompositor,Vulkan,UseSkiaRenderer \
  --enable-features=UseOzonePlatform \
  --ozone-platform=x11 \
  --disable-accelerated-2d-canvas \
  --disable-accelerated-video-decode \
  --disable-breakpad \
  $PROXY_ARGS \
  "$@"
EOF
            chmod +x $out/bin/xdg-open

            for name in google-chrome-stable chromium chromium-browser chrome; do
              ln -sf google-chrome $out/bin/$name
            done

            wrapProgram $out/bin/antigravity \
              --prefix PATH : "$out/bin:${fullPath}" \
              --set-default SHELL "$out/bin/bash" \
              --set-default CHROME_PATH "$out/bin/google-chrome" \
              --set-default CHROME_EXECUTABLE "$out/bin/google-chrome" \
              --set-default CHROME_BIN "$out/bin/google-chrome" \
              --set-default BROWSER "$out/bin/google-chrome" \
              --set VK_ICD_FILENAMES "" \
              --set LIBVA_DRIVER_NAME "null" \
              --set MESA_LOADER_DRIVER_OVERRIDE "swrast" \
              --set GALLIUM_DRIVER "llvmpipe" \
              --unset XDG_CURRENT_DESKTOP \
              --unset DESKTOP_SESSION \
              --add-flags "--disable-gpu --no-sandbox --disable-vulkan --disable-software-rasterizer"
          '';

          meta = pkgs.antigravity.meta // {
            mainProgram = "antigravity";
          };
        };
    };
}
