{ config, pkgs, ... }:

{
  home.stateVersion = "25.11";

  imports = [
    ./sops.nix
    ./ssh.nix
  ];

  programs.home-manager.enable = true;
}
