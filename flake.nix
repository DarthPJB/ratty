{
  description = "Ratty: a GPU-rendered terminal emulator with inline 3D graphics";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { self, nixpkgs }:
    let
      supportedSystems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      forEachSystem = nixpkgs.lib.genAttrs supportedSystems;
    in
    {
      packages = forEachSystem (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          ratty = pkgs.callPackage ./nix/default.nix { };
          default = self.packages.${system}.ratty;
        }
      );

      devShells = forEachSystem (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          default = pkgs.mkShell {
            inputsFrom = [ self.packages.${system}.default ];
            packages = with pkgs; [
              rust-analyzer
              cargo
              clippy
              rustfmt
            ];
          };
        }
      );

      formatter = forEachSystem (system: nixpkgs.legacyPackages.${system}.nixfmt-rfc-style);
    };
}
