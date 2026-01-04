{ config, pkgs, inputs, ... }:

{
  imports = [ inputs.home-manager.nixosModules.home-manager ];

  home-manager = {
    extraSpecialArgs = { inherit inputs; };

    users.summon = { config, pkgs, inputs, ... }: {
      home = {
        username = "summon";
	homeDirectory = "/home/summon";
	packages = [ ];
      };

      imports = [
        ./common.nix
	../slumber/deploy.nix
      ];
    };
  };
}
