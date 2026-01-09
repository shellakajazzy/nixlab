{ inputs, config, pkgs, lib, hostname, diskname, opensshPubKey, ... }:

{
  imports = [
    inputs.sops-nix.nixosModules.sops
    inputs.disko.nixosModules.disko
  ];

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

  # setup users
  users = {
    mutableUsers = false;
    users = {
      root.hashedPassword = "!";
      ${hostname} = {
	isNormalUser = true;
	home = "/home/${hostname}";
	descriptiion = "${hostname}";
	extraGroups = [ "wheel" "networkmanager" ];
	openssh.authorizedKeys.keys = [ "${opensshPubKey}" ];
      };
    };
  };

  # setup hostname and networking
  networking.networkmanager.enable = true;
  networking.hostName = "${hostname}";

  # setup tailscale as a client
  sops.secrets."tailscale_auth_key".owner = "tailscale-autoconnect";

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

	${pkgs.tailscale}/bin/tailscale up -authkey $(cat ${config.sops.secrets."tailscale_auth_key".path})
      '';
    };
  };

  # setup ssh into machine
  services.openssh = {
    enable = true;
    ports = [ 22 ];
    settings = {
      PermitRootLogin = "no";
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
    };
  };

  networking.firewall.allowedTCPPorts = [ 22 ];

  # setup bootloader
  boot.loader.grub = {
    enable = true;
    devices = lib.mkForce [ "${diskname}" ];
    useOSProbe = true;
  };

  # should be compatible with all NixOS machines I am deploying
  disko.devices = {
    disk.main = {
      device = "${diskname}";
      type = "disk";
      content = {
        type = "gpt";
	partitions = {
	  boot = {
	    size = "1M";
	    type = "EF02";
	  };
	  esp = {
	    size = "500M";
	    type = "EF00";
	    content = {
	      type = "filesystem";
	      format = "vfat";
	      mountpoint = "/boot";
	      mountOptions = [ "umask=077" ];
	    };
	  };
	  root = {
	    end = "-2G";
	    size = "100%";
	    content = {
	      type = "filesystem";
	      format = "ext4";
	      mountpoint = "/";
	    };
	  };
	  swap = {
	    size = "100%";
	    content = {
	      type = "swap";
	      discardPolicy = "both";
	      resumeDevice = true;
	    };
	  };
	};
      };
    };
  };
}
