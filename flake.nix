{
  description = "Nix flake for my (shellakajazzy's) homelab/network";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.11";

    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, ... }@inputs: {
    nixosConfigurations = {
      summon = nixpkgs.lib.nixosSystem {
	specialArgs = { inherit inputs; };

	modules = [
	  ./nixos/summon/configuration.nix
	  ./home-manager/summon.nix
	  ./modules/nixos/openssh.nix
	];
      };

      squeeze = nixpkgs.lib.nixosSystem {
        specialArgs = { inherit inputs; };

	modules = [
	  ./nixos/squeeze/configuration.nix
	  ./modules/nixos/openssh.nix
	  ./modules/nixos/nextcloud.nix
	  ./modules/nixos/syncthing.nix
	];
      };
    };
  };
}
