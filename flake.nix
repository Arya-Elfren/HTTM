{
  inputs = {
    flake-parts.url = "github:hercules-ci/flake-parts";
    nixpkgs.url = "github:NixOs/nixpkgs/nixos-24.05";
    zig2nix.inputs.nixpkgs.follows = "nixpkgs";
    zig2nix.url = "github:Cloudef/zig2nix";
  };

  outputs = { self, ... }@inputs: inputs.flake-parts.lib.mkFlake { inherit inputs; } rec {
    systems = inputs.nixpkgs.lib.systems.flakeExposed;
    perSystem = { pkgs, config, system, ... }: {
      devShells = {
        default = pkgs.mkShell {
          nativeBuildInputs = with pkgs; [
            inputs.zig2nix.outputs.packages.${system}.zig.master.bin
            poop
          ];
        };
      };
    };
  };
}
