{ config, pkgs, inputs, ... }:

{
  imports = [ inputs.sops-nix.nixosModules.sops ];
  environment.systemPackages = with pkgs; [ age ssh-to-age sops ];

  boot.initrd.postDeviceCommands = ''
    cp -r ${../../secrets/sops_key.txt} /run/sops_key.txt
    chmod -R 700 /run/sops_key.txt
  '';

  sops = {
    age.keyFile = "/run/sops_key.txt";

    defaultSopsFile = ../../secrets/secrets.yaml;
    defaultSopsFormat = "yaml";
  };
}
