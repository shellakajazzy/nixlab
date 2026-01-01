{ config, pkgs, inputs, ... }:

{
  imports = [ inputs.home-manager.nixosModules.home-manager ];

  home-manager = {
    extraSpecialArgs = { inherit inputs; };

    users.squeeze = { config, pkgs, inputs, ... }: {
      home = {
        username = "squeeze";
	homeDirectory = "/home/squeeze";
	packages = [ ];
      };

      imports = [ ./common.nix ];
    };
  };
}
