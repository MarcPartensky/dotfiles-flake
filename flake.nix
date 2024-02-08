{
  description = "Barebones NixOS on ZFS config";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-23.11";
    nixpkgs-unstable.url = "nixpkgs/master";
    home-manager = {
      url = "github:nix-community/home-manager/release-23.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, nixpkgs-unstable, home-manager }@inputs:
    let
      mkHost = hostName: system:
        nixpkgs.lib.nixosSystem {
          pkgs = import nixpkgs {
            inherit system;
            # settings to nixpkgs goes to here
            # nixpkgs.pkgs.zathura.useMupdf = true;
            # nixpkgs.config.allowUnfree = false;
          };

          specialArgs = {
            # By default, the system will only use packages from the
            # stable channel.  You can selectively install packages
            # from the unstable channel.  You can also add more
            # channels to pin package version.
            pkgs-unstable = import nixpkgs-unstable {
              inherit system;
              # settings to nixpkgs-unstable goes to here
            };

            # make all inputs availabe in other nix files
            inherit inputs;
          };

          modules = [
            # Root on ZFS related configuration
            ./modules

            # Configuration shared by all hosts
            ./configuration.nix

            # Configuration per host
            ./hosts/${hostName}

            # home-manager
            home-manager.nixosModules.home-manager
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
            }
          ];
        };
    in {
      nixosConfigurations = {
        exampleHost = mkHost "nixos" "x86_64-linux";
      };
    };
}
