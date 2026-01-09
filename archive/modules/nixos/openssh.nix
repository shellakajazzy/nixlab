{ config, pkgs, ... }:

{
  services.openssh = {
    enable = true;
    ports = [ 22 ];
    settings = {
      # TODO: change when I get keys setup
      PermitRootLogin = "yes";
      PasswordAuthentication = true;
      KbdInteractiveAuthentication = true;
    };
  };

  networking.firewall.allowedTCPPorts = [ 22 ];
}
