{
  description = "Antigravity - Electron-based app";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/3de8f8d73e35724bf9abef41f1bdbedda1e14a31";
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
      packages.${system}.default = pkgs.stdenv.mkDerivation rec {
        pname = "antigravity";
        version = "1.11.3";

        src = pkgs.fetchurl {
          url = "https://edgedl.me.gvt1.com/edgedl/release2/j0qc3/antigravity/stable/1.11.3-6583016683339776/linux-x64/Antigravity.tar.gz";
          sha256 = "sha256-Al2lEvl5mnFU4sx1vAkIIBOCwazy6DePnaI1y4SlYVs=";
        };

        nativeBuildInputs = with pkgs; [
          autoPatchelfHook
          wrapGAppsHook3
          makeWrapper
        ];

        buildInputs = with pkgs; [
          stdenv.cc.cc.lib
          alsa-lib
          atk
          cairo
          cups
          dbus
          expat
          fontconfig
          freetype
          gdk-pixbuf
          glib
          gtk3
          libdrm
          libnotify
          libpulseaudio
          libuuid
          libxkbcommon
          xorg.libxkbfile
          mesa
          nspr
          nss
          pango
          systemd
          xorg.libX11
          xorg.libXScrnSaver
          xorg.libXcomposite
          xorg.libXcursor
          xorg.libXdamage
          xorg.libXext
          xorg.libXfixes
          xorg.libXi
          xorg.libXrandr
          xorg.libXrender
          xorg.libXtst
          xorg.libxcb
          xorg.libxshmfence
          chromium
        ];

        sourceRoot = "Antigravity";

        dontBuild = true;
        dontConfigure = true;

        installPhase = ''
          runHook preInstall

          mkdir -p $out/lib/antigravity
          cp -r . $out/lib/antigravity/

          chmod +x $out/lib/antigravity/antigravity

          # Create custom xdg-open wrapper that launches Chromium
          mkdir -p $out/lib/antigravity/bin
          cat > $out/lib/antigravity/bin/xdg-open <<'XDGEOF'
#!/bin/sh
unset http_proxy https_proxy HTTP_PROXY HTTPS_PROXY no_proxy NO_PROXY
exec ${pkgs.chromium}/bin/chromium --new-window --no-sandbox "$@"
XDGEOF
          chmod +x $out/lib/antigravity/bin/xdg-open

          # Create main wrapper
          mkdir -p $out/bin
          makeWrapper $out/lib/antigravity/antigravity $out/bin/antigravity \
            --prefix LD_LIBRARY_PATH : "${pkgs.lib.makeLibraryPath buildInputs}" \
            --prefix PATH : "$out/lib/antigravity/bin" \
            --set BROWSER "$out/lib/antigravity/bin/xdg-open" \
            --add-flags "\''${NIXOS_OZONE_WL:+\''${WAYLAND_DISPLAY:+--ozone-platform-hint=auto --enable-features=WaylandWindowDecorations}}"

          runHook postInstall
        '';

        meta = with pkgs.lib; {
          description = "Antigravity - Electron-based application";
          homepage = "https://antigravity.dev";
          license = licenses.unfree;
          platforms = [ "x86_64-linux" ];
          mainProgram = "antigravity";
        };
      };

      apps.${system}.default = {
        type = "app";
        program = "${self.packages.${system}.default}/bin/antigravity";
      };
    };
}