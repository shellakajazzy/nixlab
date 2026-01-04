{ config, pkgs, inputs, ... }:

{
  imports = [
    ../common.nix
    ./hardware-configuration.nix
  ];

  boot.loader.grub.enable = true;
  boot.loader.grub.device = "/dev/sda";
  boot.loader.grub.useOSProber = true;

  networking.hostName = "summon";
  networking.networkmanager.enable = true;

  users.users.summon = {
    isNormalUser = true;
    description = "summon";
    extraGroups = [ "networkmanager" "wheel" ];
    packages = with pkgs; [ git neovim tmux ];
  };
}
