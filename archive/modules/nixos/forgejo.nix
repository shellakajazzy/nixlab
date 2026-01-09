{ config, pkgs, inputs, lib, ... }:

{
  services.forgejo = {
    enable = true;

    settings = {
      server = {
        DOMAIN = config.networking.hostName + ".sable-scylla.ts.net";
        ROOT_URL = "http://" + config.networking.hostName + ".sable-scylla.ts.net:3000/";
        HTTP_PORT = 3000;
	SSH_PORT = lib.head config.services.openssh.ports;
      };

      actions = {
        ENABLED = true;
	DEFAULT_ACTIONS_URL = "github";
      };
    };

    database.type = "postgres";
    lfs.enable = true;
  };

  networking.firewall.allowedTCPPorts = [ 3000 ];
}
