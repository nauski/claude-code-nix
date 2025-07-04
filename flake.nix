{
  description = "Nix package for Claude Code - AI coding assistant in your terminal";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    let
      overlay = final: prev: {
        claude-code = final.callPackage ./package.nix { };
      };
    in
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfree = true;
          overlays = [ overlay ];
        };
      in
      {
        packages = {
          default = pkgs.claude-code;
          claude-code = pkgs.claude-code;
        };
        
        apps = {
          default = {
            type = "app";
            program = "${pkgs.claude-code}/bin/claude";
          };
          claude-code = {
            type = "app";
            program = "${pkgs.claude-code}/bin/claude";
          };
        };

        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            nixpkgs-fmt
            nix-prefetch-git
            cachix
          ];
        };
      }) // {
        overlays.default = overlay;
      };
}