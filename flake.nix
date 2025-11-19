{
  description = "Antigravity";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
    in
    {
      packages.${system}.default = pkgs.callPackage (
        { vscode-generic, fetchurl, lib }:
        vscode-generic {
          version = "1.11.3";
          pname = "antigravity";
          vscodeVersion = "1.90.0";
          
          executableName = "antigravity";
          longName = "Antigravity";
          shortName = "antigravity";
          
          src = fetchurl {
            url = "https://edgedl.me.gvt1.com/edgedl/release2/j0qc3/antigravity/stable/1.11.3-6583016683339776/linux-x64/Antigravity.tar.gz";
            hash = "sha256-0000000000000000000000000000000000000000000="; # Replace with real hash
          };
          
          sourceRoot = "Antigravity";
          
          meta = {
            description = "Antigravity app";
            platforms = [ "x86_64-linux" ];
            mainProgram = "antigravity";
          };
        }
      ) {};
    };
}