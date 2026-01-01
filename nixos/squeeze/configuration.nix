{ config, pkgs, inputs, ... }:

{
  imports = [ ../common.nix ./hardware-configuration.nix ];

  boot.loader.grub.enable = true;
  boot.loader.grub.device = "/dev/sda";
  boot.loader.grub.useOSProber = true;

  networking.hostName = "squeeze";
  networking.networkmanager.enable = true;

  users.users.squeeze = {
    isNormalUser = true;
    description = "squeeze";
    extraGroups = [ "networkmanager" "wheel" ];
    packages = with pkgs; [ git neovim tmux ];
  };
}
