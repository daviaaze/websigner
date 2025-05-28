{
  description = "WebSigner - Digital signature application by Softplan";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        
        # Allow unfree packages (needed for proprietary software)
        pkgsWithUnfree = import nixpkgs {
          inherit system;
          config.allowUnfree = true;
        };
      in
      {
        packages = {
          websigner = pkgsWithUnfree.callPackage ./websigner.nix { };
          default = self.packages.${system}.websigner;
        };

        # Development shell for building and testing
        devShells.default = pkgsWithUnfree.mkShell {
          buildInputs = with pkgsWithUnfree; [
            dpkg
            file
            binutils
            patchelf
          ];
          
          shellHook = ''
            echo "WebSigner development environment"
            echo "Available commands:"
            echo "  nix build .#websigner  - Build the WebSigner package"
            echo "  nix run .#websigner    - Run WebSigner directly"
            echo "  dpkg --contents websigner-setup-64.deb  - Inspect .deb contents"
          '';
        };

        # Apps for easy running
        apps = {
          websigner = flake-utils.lib.mkApp {
            drv = self.packages.${system}.websigner;
            exePath = "/bin/websigner";
          };
          default = self.apps.${system}.websigner;
        };
      });
}
