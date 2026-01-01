{ config, pkgs, inputs, ... }:

{
  imports = [ inputs.sops-nix.homeManagerModules.sops ];

  # import keys for specific machine
  sops.secrets."key_pairs/${config.home.username}/private".path = "${config.home.homeDirectory}/.ssh/${config.home.username}";
  sops.secrets."key_pairs/${config.home.username}/public".path = "${config.home.homeDirectory}/.ssh/${config.home.username}.pub";

  programs.ssh = {
    enable = true;
    enableDefaultConfig = true;
  };
}
