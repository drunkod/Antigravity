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
          ];
        in
        pkgs.symlinkJoin {
          name = "antigravity-wrapped";
          paths = [ pkgs.antigravity ];
          nativeBuildInputs = [ pkgs.makeWrapper ];

          postBuild = ''
            # Extra tools for in-app terminal
            mkdir -p $out/bin
            ln -sf ${pkgs.bashInteractive}/bin/bash $out/bin/bash
            ln -sf ${pkgs.bashInteractive}/bin/sh $out/bin/sh
            ln -sf ${pkgs.git}/bin/git $out/bin/git

            # Wrap the *already wrapped* nixpkgs antigravity binary (preserves GApps env)
            wrapProgram $out/bin/antigravity \
              --prefix PATH : "${pkgs.lib.makeBinPath terminalDeps}:$out/bin" \
              --set-default SHELL "${pkgs.bashInteractive}/bin/bash" \
              --set NIXOS_OZONE_WL "0" \
              --set ELECTRON_OZONE_PLATFORM_HINT "x11" \
              --set GDK_BACKEND "x11" \
              --set LIBGL_ALWAYS_SOFTWARE "1" \
              --set VK_ICD_FILENAMES "" \
              --set LIBVA_DRIVER_NAME "null" \
              --set MESA_LOADER_DRIVER_OVERRIDE "swrast" \
              --set GALLIUM_DRIVER "llvmpipe" \
              --unset XDG_CURRENT_DESKTOP \
              --unset DESKTOP_SESSION \
              --unset GIO_LAUNCHED_DESKTOP_FILE_PID \
              --add-flags "--no-sandbox --disable-dev-shm-usage --ozone-platform=x11 --enable-features=UseOzonePlatform --disable-gpu --use-gl=swiftshader"
          '';

          meta = pkgs.antigravity.meta // {
            mainProgram = "antigravity";
            description = "Antigravity (nixos-unstable pkgs.antigravity) wrapped for VNC/X11 stability";
          };
        };
    };
}
