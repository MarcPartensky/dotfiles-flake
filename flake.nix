{
  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-23.05";
  ## after reboot, you can track rolling release by using
  #inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
     url = "github:nix-community/home-manager";
     inputs.nixpkgs.follows = "nixpkgs";
    };
    hyprland.url = "github:hyprwm/Hyprland";
  };

  outputs = { self, nixpkgs }@inputs:
    let
      lib = nixpkgs.lib;
      mkHost = { my-config, zfs-root, pkgs, system, ... }:
        lib.nixosSystem {
          inherit system;
          specialArgs = { inherit hyprland; };
          modules = [
            ./modules
            (import ./configuration.nix {
              inherit my-config zfs-root inputs pkgs lib;
            })
            hyprland.nixosModules.default
          ];
        };
    in {
      nixosConfigurations = {
        tower = let
          system = "x86_64-linux";
          pkgs = nixpkgs.legacyPackages.${system};
        in mkHost (import ./hosts/tower { inherit system pkgs; });
      };
    };
}
