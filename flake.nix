{
  description = "Development environment for DockerUI with SwiftLint and swift-format";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in
      {
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            swiftlint
            swift-format
          ];

          shellHook = ''
            echo "🚀 Development environment loaded!"
            echo "Available commands:"
            echo "  - swiftlint: Run SwiftLint"
            echo "  - swift-format: Format Swift code"
          '';
        };
      }
    );
} 