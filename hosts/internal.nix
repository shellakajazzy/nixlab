{ inputs, config, pkgs, lib, ... }:

{
  imports = [ inputs.sops-nix.nixosModules.sops ];
}
