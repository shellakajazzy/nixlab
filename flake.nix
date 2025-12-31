{
  description = "Nix flake for my (shellakajazzy's) homelab/network";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.11";

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, ... }@inputs: {
    nixosConfigurations = {
      squeeze = nixpkgs.lib.nixosSystem {
      	system = "x86_64-linux";
	specialArgs = { inherit inputs; };

	modules = [
	  ./hosts/common.nix
	  ./hosts/squeeze/configuration.nix
	  ./modules/nixos/openssh.nix
	];
      };
    };
  };
}
