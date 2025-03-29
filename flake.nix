{
  description = "Development environment for DockerUI with SwiftLint and swift-format";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs?ref=c69a9bffbecde46b4b939465422ddc59493d3e4d";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = {
    self,
    nixpkgs,
    flake-utils,
  }: let
    system = "aarch64-darwin";
    pkgs = nixpkgs.legacyPackages.${system};
    writeZsh = pkgs.writers.makeScriptWriter {interpreter = "${pkgs.zsh}/bin/zsh";};
  in {
    apps.${system} = {
      swiftlint = {
        type = "app";
        name = "swiftlint";
        program = "${pkgs.swiftlint}/bin/swiftlint";
      };
      format-lint = {
        type = "app";
        name = "format-lint";
        program = builtins.toString (
          writeZsh "format-lint" ''
            ${pkgs.swift-format}/bin/swift-format -i -p -r "''${1:-Bulkhead}"
            shift
            ${pkgs.swiftlint}/bin/swiftlint "''${@}"
          ''
        );
      };
    };
  };
}
