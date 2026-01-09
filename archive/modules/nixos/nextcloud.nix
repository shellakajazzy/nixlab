{ config, pkgs, inputs, ... }:

{
  imports = [ inputs.sops-nix.nixosModules.sops ];
  sops.secrets."nextcloud/admin/default-pass" = {
    owner = "nextcloud";
    group = "nextcloud";
    mode = "0400";
  };

  fileSystems."/mnt/VMShare" = {
    device = "VMShare";
    fsType = "virtiofs";
    options = [
      "nofail"
      "x-systemd.automount"
    ];
  };

  services.nextcloud = {
    enable = true;
    package = pkgs.nextcloud32;
    hostName = config.networking.hostName + ".sable-scylla.ts.net";
    datadir = "/mnt/VMShare/nextcloud/data";

    settings = {
      trusted_domains = [ "sable-scylla.ts.net" ];
      loglevel = 1;
    };

    database.createLocally = true;
    config = {
      dbtype = "sqlite";

      adminuser = "admin";
      adminpassFile = config.sops.secrets."nextcloud/admin/default-pass".path;
    };
  };

  networking.firewall.allowedTCPPorts = [ 80 ];
}
