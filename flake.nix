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
            # Add more terminal essentials
            less
            tree
            file
            util-linux
          ];

          # Full PATH for terminal
          fullPath = pkgs.lib.makeBinPath (terminalDeps ++ [ pkgs.git ]);
        in
        pkgs.symlinkJoin {
          name = "antigravity-wrapped";
          paths = [ pkgs.antigravity ];
          nativeBuildInputs = [ pkgs.makeWrapper ];

          postBuild = ''
            mkdir -p $out/bin

            # Create proper bash wrapper (not just symlink!)
            cat > $out/bin/bash <<'BASH_EOF'
#!/usr/bin/env bash
# Antigravity bash wrapper - ensures proper environment

# Set up PATH
export PATH="${fullPath}:$PATH"

# Set SHELL to real bash
export SHELL="${pkgs.bashInteractive}/bin/bash"

# Source system bashrc if available
if [ -f /etc/bashrc ]; then
  source /etc/bashrc
fi

# Execute real bash with all arguments
exec "${pkgs.bashInteractive}/bin/bash" "$@"
BASH_EOF
            chmod +x $out/bin/bash

            # sh symlink to bash
            ln -sf bash $out/bin/sh

            # Git symlink
            ln -sf ${pkgs.git}/bin/git $out/bin/git

            # Chrome wrapper - SINGLE PROCESS for external browser only!
            cat > $out/bin/google-chrome <<'EOF'
#!/usr/bin/env bash
echo "[google-chrome] Opening external link: $@" >&2
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
  --no-zygote \
  --single-process \
  "$@"
EOF
            chmod +x $out/bin/google-chrome

            # xdg-open wrapper with same flags
            cat > $out/bin/xdg-open <<'EOF'
#!/usr/bin/env bash
echo "[xdg-open] Opening: $@" >&2
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
  --no-zygote \
  --single-process \
  "$@"
EOF
            chmod +x $out/bin/xdg-open

            # Chrome symlinks
            for name in google-chrome-stable chromium chromium-browser chrome; do
              ln -sf google-chrome $out/bin/$name
            done

            # Wrap Antigravity with proper environment
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
