{
  description = "Nix flake for my (shellakajazzy's) homelab/network";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.11";

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    disko = {
      url = "github:/nix-community/disko/latest";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, ... }@inputs: let
    system = "x86_64-linux";
    opensshPubKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGmwNpXbFUK5jSHWmMNMLQFE+cNJRpLEPrmE+gligiO4 homelab";

    mkHostConfig = hostname: diskname: nixpkgs.lib.nixosSystem {
      inherit system;
      specialArgs = { inherit inputs hostname diskname opensshPubKey; };

      modules = [
        ./hosts/common.nix

        ./hosts/${hostname}.nix
	./hosts/hardware-configs/${hostname}.nix
      ];
    };
  in {
    nixosConfigurations = {
      internal = mkHostConfig "internal" "/dev/sda";
    };
  };
}
