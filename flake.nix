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
            mkdir -p $out/bin
            ln -sf ${pkgs.bashInteractive}/bin/bash $out/bin/bash
            ln -sf ${pkgs.bashInteractive}/bin/sh $out/bin/sh
            ln -sf ${pkgs.git}/bin/git $out/bin/git

            wrapProgram $out/bin/antigravity \
              --prefix PATH : "${pkgs.lib.makeBinPath terminalDeps}:$out/bin" \
              --set-default SHELL "${pkgs.bashInteractive}/bin/bash" \
              --set DISPLAY ":99" \
              --set ELECTRON_OZONE_PLATFORM_HINT "x11" \
              --set GDK_BACKEND "x11" \
              --set LIBGL_ALWAYS_SOFTWARE "1" \
              --set MESA_LOADER_DRIVER_OVERRIDE "swrast" \
              --set GALLIUM_DRIVER "llvmpipe" \
              --add-flags "--no-sandbox --disable-gpu --in-process-gpu"
          '';

          meta = pkgs.antigravity.meta // {
            mainProgram = "antigravity";
          };
        };
    };
}
