{
  description = "Nix flake for my (shellakajazzy's) homelab/network";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.11";
  };

  outputs = { self, nixpkgs, ... }: {
    nixosConfigurations = {
      squeeze = nixpkgs.lib.nixosSystem {
      	system = "x86_64-linux";

	modules = [
	  ./hosts/common.nix
	  ./hosts/squeeze/configuration.nix
	  ./modules/nixos/openssh.nix
	];
      };
    };
  };
}
