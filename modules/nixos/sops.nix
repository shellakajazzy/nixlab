{ config, pkgs, inputs, ... }:

{
  imports = [ inputs.sops-nix.nixosModules.sops ];
  environment.systemPackages = with pkgs; [ age ssh-to-age sops ];

  # TODO: use workaround from here https://github.com/Mic92/sops-nix/pull/534#issuecomment-2079752308

  sops = {
    defaultSopsFile = ../../secrets/secrets.yaml;
    defaultSopsFormat = "yaml";
  };
}
