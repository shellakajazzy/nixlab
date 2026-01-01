{ config, pkgs, ... }:

{
  home.stateVersion = "25.11";

  imports = [
    ../modules/home-manager/sops.nix
    ../modules/home-manager/ssh.nix
  ];

  programs.home-manager.enable = true;
}
