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
    { nixpkgs, zig-overlay, zls-overlay, ... }:
    let
      system = "x86_64-linux";
      zig = zig-overlay.packages.x86_64-linux.master;
      overlays = [
        (final: prev: {
          inherit zig;
        })
      ];
      pkgs = import nixpkgs { inherit system overlays; };
      zls = zls-overlay.packages.x86_64-linux.zls.overrideAttrs (old: {
        nativeBuildInputs = [ zig ];
      });
    in
    {
      devShells.x86_64-linux.default = pkgs.mkShell {
        packages = [
          zls
          zig
        ];
      };
    };
}
