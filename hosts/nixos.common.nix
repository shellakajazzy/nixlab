{ config, pkgs, ... }:

{
  imports = [ inputs.sops-nix.nixosModules.sops ];

  # setup nix and nix packages
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nixpkgs.config.allowUnfree = true;
  system.stateVersion = "25.11";

  # setup localization
  time.timeZone = "America/Los_Angeles";
  i18n = {
    defaultLocale = "en_US.UTF-8";
    extraLocaleSettings = {
      LC_ADDRESS = "en_US.UTF-8";
      LC_IDENTIFICATION = "en_US.UTF-8";
      LC_MEASUREMENT = "en_US.UTF-8";
      LC_MONETARY = "en_US.UTF-8";
      LC_NAME = "en_US.UTF-8";
      LC_NUMERIC = "en_US.UTF-8";
      LC_PAPER = "en_US.UTF-8";
      LC_TELEPHONE = "en_US.UTF-8";
      LC_TIME = "en_US.UTF-8";
    };
  };
  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };

  # setup firewall
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ ];
    allowedUDPPorts = [ ];
  };

  # setup nix-sops
  environment.systemPackages = with pkgs; [ age ssh-to-age sops ];

  boot.initrd.postDeviceCommands = ''
    cp -r ${../../secrets/sops_key.txt} /run/sops_key.txt
    chmod -R 700 /run/sops_key.txt
  '';

  sops = {
    age.keyFile = "/run/sops_key.txt";

    defaultSopsFile = ../secrets/secrets.yaml;
    defaultSopsFormat = "yaml";
  };

  # setup tailscale as a client
  sops.secrets."tailscale/auth_key".owner = "tailscale-autoconnect";

  environment.systemPackages = with pkgs; [ tailscale jq ];
  services.tailscale.enable = true;

  users.users.tailscale-autoconnect = {
    home = "/var/lib/tailscale-autoconnect";
    createHome = true;
    isSystemUser = true;
    group = "tailscale-autoconnect";
  };
  users.groups.tailscale-autoconnect = { };

  systemd.services = {
    tailscale-autoconnect = {
      description = "Autoconnect to tailscale-network";

      after = [ "network-pre.target" "tailscale.service" "tailscale-autoconnect-perms.service" ];
      wants = [ "network-pre.target" "tailscale.service" ];
      wantedBy = [ "multi-user.target" ];

      script = ''
        sleep 2

	status="$(${pkgs.tailscale}/bin/tailscale status -json | ${pkgs.jq}/bin/jq -r .BackendState)"
	if [ $status = "Running" ]; then exit 0; fi

	${pkgs.tailscale}/bin/tailscale up -authkey $(cat ${config.sops.secrets."tailscale/auth_key".path})
      '';
    };
  };

  # setup ssh into machine
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
