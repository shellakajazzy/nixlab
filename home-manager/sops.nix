{ config, pkgs, inputs, ... }:

{
  imports = [ inputs.sops-nix.homeManagerModules.sops ];

  home.file.".config/sops/age/keys.txt".source = ../secrets/sops_key.txt;

  sops = {
    age.keyFile = "${config.home.homeDirectory}/.config/sops/age/keys.txt";
    defaultSopsFile = ../secrets/secrets.yaml;
    defaultSopsFormat = "yaml";

    secrets."key_pairs/sops_key/public" = { };
  };
}
