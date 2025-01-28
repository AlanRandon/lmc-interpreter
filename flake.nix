{
  inputs = {
    flake-utils.url = "github:numtide/flake-utils";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    zig-overlay = {
      url = "github:mitchellh/zig-overlay";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-utils.follows = "flake-utils";
      };
    };
    zls-overlay = {
      url = "github:zigtools/zls";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        zig-overlay.follows = "zig-overlay";
        flake-utils.follows = "flake-utils";
      };
    };
  };
  outputs =
    { nixpkgs, zig-overlay, zls-overlay, flake-utils, self, ... }:
    flake-utils.lib.eachDefaultSystem
      (system:
      let
        zig = zig-overlay.packages.${system}.master;
        overlays = [
          (final: prev: {
            inherit zig;
          })
        ];
        pkgs = import nixpkgs { inherit system overlays; };
        zls = zls-overlay.packages.${system}.zls.overrideAttrs (old: {
          nativeBuildInputs = [ zig ];
        });
      in
      {
        packages.default = pkgs.stdenv.mkDerivation (finalAttrs: {
          src = ./.;
          name = "lmc-tools";
          nativeBuildInputs = [ zig pkgs.pkg-config ];
          phases = "unpackPhase installPhase";
          installPhase = ''
            	  mkdir -p .cache
            	  zig build install -Doptimize=ReleaseSafe --prefix $out --cache-dir $(pwd)/.zig-cache --global-cache-dir $(pwd)/.cache'';
        });

        apps.lmc-dbg = {
          type = "app";
          program = "${self.packages.${system}.default}/bin/lmc-dbg";
        };

        apps.lmci = {
          type = "app";
          program = "${self.packages.${system}.default}/bin/lmci";
        };

        apps.lmc-as = {
          type = "app";
          program = "${self.packages.${system}.default}/bin/lmc-as";
        };

        apps.default = self.apps.${system}.lmc-dbg;

        devShells.default = pkgs.mkShell {
          packages = [
            zls
            zig
          ];
        };
      });
}
