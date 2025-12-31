{ config, pkgs, ... }:

{
  services.openssh = {
    enable = true;
    ports = [ 22 ];
    settings = {
      PermitRootLogin = "no";
      # TODO: change when I get keys setup
      PasswordAuthentication = true;
      KbdInteractiveAuthentication = true;
    };
  };

  networking.firewall.allowedTCPPorts = [ 22 ];
}
