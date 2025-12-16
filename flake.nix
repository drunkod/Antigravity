{
  description = "Antigravity with Git support";

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
        version = "1.11.17";

        src = pkgs.fetchurl {
          url = "https://edgedl.me.gvt1.com/edgedl/release2/j0qc3/antigravity/stable/1.11.17-6639170008514560/linux-x64/Antigravity.tar.gz";
          sha256 = "sha256-RUh4n14wrRPvNB7xEvOjmbLWsODMlee/WgYlsIpacSA=";
        };

        nativeBuildInputs = with pkgs; [
          autoPatchelfHook
          wrapGAppsHook3
          makeWrapper
        ];

        buildInputs = with pkgs; [
          stdenv.cc.cc.lib
          alsa-lib atk cairo cups dbus expat fontconfig freetype
          gdk-pixbuf glib gtk3 libdrm libnotify libpulseaudio
          libuuid libxkbcommon xorg.libxkbfile mesa nspr nss pango
          systemd xorg.libX11 xorg.libXScrnSaver xorg.libXcomposite
          xorg.libXcursor xorg.libXdamage xorg.libXext xorg.libXfixes
          xorg.libXi xorg.libXrandr xorg.libXrender xorg.libXtst
          xorg.libxcb xorg.libxshmfence
        ];

        sourceRoot = "Antigravity";
        dontBuild = true;
        dontConfigure = true;

        installPhase = ''
          runHook preInstall

          mkdir -p $out/lib/antigravity
          cp -r . $out/lib/antigravity/
          chmod +x $out/lib/antigravity/antigravity

          mkdir -p $out/bin

          # Chrome wrapper with ALL crash-prevention flags
          cat > $out/bin/google-chrome <<'EOF'
#!/usr/bin/env bash
echo "[google-chrome] Called with: $@" >&2
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
echo "[xdg-open] Called with: $@" >&2
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

          # Git symlink
          ln -sf ${pkgs.git}/bin/git $out/bin/git

          # Main wrapper with environment fixes
          makeWrapper $out/lib/antigravity/antigravity $out/bin/antigravity \
            --prefix PATH : "$out/bin:${pkgs.git}/bin" \
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
            --unset GIO_LAUNCHED_DESKTOP_FILE_PID \
            --add-flags "--disable-gpu --no-sandbox --disable-vulkan --disable-software-rasterizer"

          runHook postInstall
        '';

        meta = with pkgs.lib; {
          description = "Antigravity with Git and Chrome";
          mainProgram = "antigravity";
        };
      };
    };
}