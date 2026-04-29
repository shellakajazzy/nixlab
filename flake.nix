# ~/~ begin <<README.md#flake.nix>>[init]
{
  description = "Flake containing the configuration for Jason G's homelab network and server";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.11";

    # ~/~ begin <<README.md#flake-inputs>>[init]
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # ~/~ end
    # ~/~ begin <<README.md#flake-inputs>>[1]
    sops-nix.url = "github:Mic92/sops-nix";
    # ~/~ end
    # ~/~ begin <<README.md#flake-inputs>>[2]
    proxmox-nixos.url = "github:SaumonNet/proxmox-nixos";
    # ~/~ end
    # ~/~ begin <<README.md#flake-inputs>>[3]
    copyparty.url = "github:9001/copyparty";
    # ~/~ end
  };

  outputs = { self, nixpkgs, ... } @ inputs: let
    # ~/~ begin <<README.md#flake-declarations>>[init]
    nixpkgSetup = {
      nix.settings.experimental-features = [ "nix-command" "flakes" ];
      nix.settings.trusted-users = [ "@wheel" "root" ];
      nixpkgs.config.allowUnfree = true;
      system.stateVersion = "25.11";
    };
    # ~/~ end
    # ~/~ begin <<README.md#flake-declarations>>[1]
    localizationSetup = {
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
    };
    # ~/~ end
    # ~/~ begin <<README.md#flake-declarations>>[2]
    bootloaderSetup = {
      boot.loader.grub.enable = true;
      boot.loader.grub.devices = [ "nodev" ];
      boot.growPartition = true;
    };
    # ~/~ end
    # ~/~ begin <<README.md#flake-declarations>>[3]
    sshSetup = {
      services.openssh = {
        enable = true;
        ports = [ 22 ];
        settings = {
          PermitRootLogin = "no";
          PubkeyAuthentication = true;
          PasswordAuthentication = false;
          KbdInteractiveAuthentication = false;
        };
      };
    };
    # ~/~ end
    # ~/~ begin <<README.md#flake-declarations>>[4]
    userSetup = hostname: {
      users.mutableUsers = true;
      users.users = {
        root = {
          hashedPassword = "!";
        };
    
        "${hostname}" = {
          isNormalUser = true;
          home = "/home/${hostname}";
          description = "${hostname}";
          group = "users";
          extraGroups = [ "wheel" ];
          initialPassword = "5Mez8Gia";
          openssh.authorizedKeys.keys = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKEmnK6phRQrpbHncPDo83riVYs8b6GzpdF3c6znIb0t homelab" ];
        };
      };
    };
    # ~/~ end
    # ~/~ begin <<README.md#flake-declarations>>[5]
    tailscaleSetup = authKeyPath: let
      pkgs = import nixpkgs { system = "x86_64-linux"; };
    in {
      environment.systemPackages = [ pkgs.tailscale pkgs.jq ];
    
      services.tailscale.enable = true;
      systemd.services.tailscaleAutoconnect = {
        description = "Autoconnect to tailscale";
        after = [ "network-pre.target" "tailscale.service" ];
        wants = [ "network-pre.target" "tailscale.service" ];
        wantedBy = [ "multi-user.target" ];
    
        script = ''
          sleep 2
    
          status="$(${pkgs.tailscale}/bin/tailscale status -json | ${pkgs.jq}/bin/jq -r .BackendState)"
          if [ $status = "Running" ]; then exit 0; fi
          ${pkgs.tailscale}/bin/tailscale up -authkey $(cat ${authKeyPath})
        '';
      };
    };
    # ~/~ end
    # ~/~ begin <<README.md#flake-declarations>>[6]
    tailscaleServe = protocol: port: let
      pkgs = import nixpkgs { system = "x86_64-linux"; };
    in {
      environment.systemPackages = [ pkgs.tailscale ];
    
      services.tailscale.enable = true;
      systemd.services.tailscaleServe = {
        description = "Serve a service using tailscale serve";
        after = [ "network-pre.target" "tailscale.service" "tailscaleAutoconnect.service" ];
        wants = [ "network-pre.target" "tailscale.service" "tailscaleAutoconnect.service" ];
        wantedBy = [ "multi-user.target" ];
    
        script = ''
          sleep 2
    
          ${pkgs.tailscale}/bin/tailscale serve --bg ${protocol}://localhost:${port}
        '';
      };
    };
    # ~/~ end
    # ~/~ begin <<README.md#flake-declarations>>[7]
    networkingSetup = hostname: {
      networking.networkmanager.enable = true;
      networking.hostName = "${hostname}";
    };
    # ~/~ end
    # ~/~ begin <<README.md#flake-declarations>>[8]
    raidDiskSetup = deviceName: {
      device = "${deviceName}";
      type = "disk";
      content = {
        type = "gpt";
        partitions.mdadm = {
          size = "100%";
          content = {
            type = "mdraid";
            name = "raid5";
          };
        };
      };
    };
    # ~/~ end
    # ~/~ begin <<README.md#flake-declarations>>[9]
    virtiofsdSetup = let
      pkgs = import nixpkgs { system = "x86_64-linux"; };
    in {
      environment.systemPackages = [ pkgs.virtiofsd ];
      system.activationScripts.virtiofsd = ''
        mkdir -p /usr/libexec
        ln -sf ${pkgs.virtiofsd}/bin/virtiofsd /usr/libexec/virtiofsd
      '';
    };
    # ~/~ end
    # ~/~ begin <<README.md#flake-declarations>>[10]
    vmTemplate = diskName: hostname: extraModules: nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        nixpkgSetup
        localizationSetup
        sshSetup
        (userSetup "${hostname}")
        (networkingSetup "${hostname}")
    
        ({ config, ... }: tailscaleSetup "/var/lib/secrets/tailscale_auth_key")
    
        inputs.disko.nixosModules.disko
    
        ./hardware-configurations/${hostname}.nix
    
        {
          disko.devices = {
            disk = {
              main = {
                device = diskName;
                type = "disk";
                content = {
                  type = "gpt";
                  partitions = {
                    boot = {
                      size = "1M";
                      type = "EF02";
                      attributes = [ 0 ];
                    };
                    root = {
                      size = "100%";
                      content = {
                        type = "filesystem";
                        format = "ext4";
                        mountpoint = "/";
                      };
                    };
                  };
                };
              };
            };
          };
          boot.loader.grub = {
            enable = true;
            devices = [ "nodev" ];
          };
        }
      ] ++ extraModules;
    };
    # ~/~ end
    # ~/~ begin <<README.md#flake-declarations>>[11]
    tempDevTools = let pkgs = import nixpkgs { system = "x86_64-linux"; }; in { environment.systemPackages = with pkgs; [ tmux neovim git gh ]; };
    # ~/~ end
  in {
    # ~/~ begin <<README.md#nixos-host-declaration>>[init]
    nixosConfigurations.nixoshost = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        # ~/~ begin <<README.md#nixos-host-modules>>[init]
        inputs.disko.nixosModules.disko
        # ~/~ end
        # ~/~ begin <<README.md#nixos-host-modules>>[1]
        inputs.sops-nix.nixosModules.sops
        # ~/~ end
        # ~/~ begin <<README.md#nixos-host-modules>>[2]
        ({ config, ... }: tailscaleSetup "${config.sops.secrets."tailscale_auth_key".path}")
        ({ config, ... }: tailscaleServe "https+insecure" "8006")
        # ~/~ end
        # ~/~ begin <<README.md#nixos-host-modules>>[3]
        inputs.proxmox-nixos.nixosModules.proxmox-ve
        # ~/~ end
        # ~/~ begin <<README.md#nixos-host-modules>>[4]
        ({ config, ... }: virtiofsdSetup)
        # ~/~ end
        # ~/~ begin <<README.md#nixos-host-modules>>[5]
        tempDevTools
        # ~/~ end
    
        nixpkgSetup
        localizationSetup
        sshSetup
        (userSetup "nixoshost")
        (networkingSetup "nixoshost")
    
        ./hardware-configuration.nix
        {
          # ~/~ begin <<README.md#nixos-host-config>>[init]
          disko.devices = {
            disk = {
              main = {
                device = "/dev/sda";
                type = "disk";
                content = {
                  type = "gpt";
                  partitions = {
                    ESP = {
                      type = "EF00";
                      size = "500M";
                      content = {
                        type = "filesystem";
                        format = "vfat";
                        mountpoint = "/boot";
                        mountOptions = [ "umask=0077" ];
                      };
                    };
                    root = {
                      size = "100%";
                      content = {
                        type = "filesystem";
                        format = "ext4";
                        mountpoint = "/";
                      };
                    };
                  };
                };
              };
          
              one = raidDiskSetup "/dev/sdc";
              two = raidDiskSetup "/dev/sdd";
              three = raidDiskSetup "/dev/sde";
              four = raidDiskSetup "/dev/sdf";
              five = raidDiskSetup "/dev/sdg";
              six = raidDiskSetup "/dev/sdh";
              seven = raidDiskSetup "/dev/sdi";
              eight = raidDiskSetup "/dev/sdj";
            };
            mdadm = {
              raid5 = {
                type = "mdadm";
                level = 5;
                content = {
                  type = "gpt";
                  partitions = {
                    primary = {
                      size = "100%";
                      content = {
                        type = "filesystem";
                        format = "ext4";
                        mountpoint = "/mnt/raid";
                      };
                    };
                  };
                };
                extraArgs = [ "--assume-clean" ];
              };
            };
          };
          # ~/~ end
          # ~/~ begin <<README.md#nixos-host-config>>[1]
          boot.loader.grub = {
            device = "nodev";
            efiSupport = true;
            efiInstallAsRemovable = true;
          };
          # ~/~ end
          # ~/~ begin <<README.md#nixos-host-config>>[2]
          sops = {
            age.keyFile = "/run/sops/age/keys.txt";
            defaultSopsFile = ./secrets.yaml;
            defaultSopsFormat = "yaml";
          };
          # ~/~ end
          # ~/~ begin <<README.md#nixos-host-config>>[3]
          boot.initrd.postDeviceCommands = ''
            mkdir -p /run/sops/age
            cp ${./keys.txt} /run/sops/age/keys.txt
            chmod -R 600 /run/sops/age/keys.txt
          '';
          # ~/~ end
          # ~/~ begin <<README.md#nixos-host-config>>[4]
          sops.secrets."tailscale_auth_key" = { };
          # ~/~ end
          # ~/~ begin <<README.md#nixos-host-config>>[5]
          networking.interfaces = {
            eno1.wakeOnLan.enable = true;
            eno2.wakeOnLan.enable = true;
          };
          # ~/~ end
          # ~/~ begin <<README.md#nixos-host-config>>[6]
          services.proxmox-ve = {
            enable = true;
            ipAddress = "0.0.0.0";
          };
          
          nixpkgs.overlays = [
            inputs.proxmox-nixos.overlays.x86_64-linux
            inputs.copyparty.overlays.default
          ];
          # ~/~ end
          # ~/~ begin <<README.md#nixos-host-config>>[7]
          services.proxmox-ve.bridges = [ "vmbr0" ];
          networking.bridges.vmbr0.interfaces = [ "eno2" ];
          networking.useNetworkd = false;
          networking.interfaces.vmbr0 = {
            useDHCP = true;
            macAddress = "f8:bc:12:50:0a:76";
          };
          networking.interfaces.eno2 = {
            useDHCP = false;
            ipv4.addresses = [ ];
            ipv6.addresses = [ ];
          };
          # ~/~ end
          # ~/~ begin <<README.md#nixos-host-config>>[8]
          sops.secrets."copyparty_admin_passwd" = { };
          # ~/~ end
        }
      ];
    };
    # ~/~ end
    # ~/~ begin <<README.md#vm-declarations>>[init]
    nixosConfigurations.fileshare = vmTemplate "/dev/sda" "fileshare" [
      ({ config, ... }: tailscaleServe "http" "3923")
      inputs.copyparty.nixosModules.default
      ({ pkgs, ... }: {
        # ~/~ begin <<README.md#fileshare-vm-config>>[init]
        fileSystems."/mnt/fileshare" = {
          device = "fileshare";
          fsType = "virtiofs";
          options = [
            "nofail"
            "x-systemd.automount"
          ];
        };
        
        systemd.tmpfiles.rules = [
          "d /mnt/fileshare 0755 copyparty copyparty -"
          "f /var/lib/secrets/copyparty_admin_passwd 0600 copyparty copyparty -"
          "d /mnt/fileshare/syncthing 0755 syncthing syncthing -"
          "d /mnt/fileshare/synced 0755 syncthing syncthing -"
        ];
        # ~/~ end
        # ~/~ begin <<README.md#fileshare-vm-config>>[1]
        environment.systemPackages = [ pkgs.copyparty ];
        services.copyparty = {
          enable = true;
          settings.i = "0.0.0.0";
        
          accounts.admin.passwordFile = "/var/lib/secrets/copyparty_admin_passwd";
          groups.admin = [ "admin" ];
        
          volumes."/" = {
            path = "/mnt/fileshare";
            access.rw = [ "admin" ];
            flags = {
              scan = 60;
              e2d = true;
              d2t = true;
            };
          };
        
          openFilesLimit = 8192;
        };
        # ~/~ end
        # ~/~ begin <<README.md#fileshare-vm-config>>[2]
        services.syncthing = {
          enable = true;
          user = "syncthing";
          group = "syncthing";
        
          openDefaultPorts = true;
          guiAddress = "0.0.0.0:8384";
          dataDir = "/mnt/fileshare/syncthing";
        };
        networking.firewall.allowedTCPPorts = [ 8384 22000 ];
        networking.firewall.allowedUDPPorts = [ 22000 21027 ];
        # ~/~ end
      })
    ];
    # ~/~ end
    # ~/~ begin <<README.md#vm-declarations>>[1]
    nixosConfigurations.git = vmTemplate "/dev/sda" "git" [
      ({ config, ... }: tailscaleServe "http" "3000")
      ({ pkgs, ... }: {
        services.forgejo = {
          enable = true;
          lfs.enable = true;
          user = "forgejo";
          group = "forgejo";
          settings.server.ROOT_URL = "https://git.sable-scylla.ts.net";
          useWizard = true;
          
          stateDir = "/mnt/fileshare/git/forgejo";
          repositoryRoot = "/mnt/fileshare/git/repos";
        };
        
        fileSystems."/mnt/fileshare" = {
          device = "fileshare";
          fsType = "virtiofs";
          options = [ "nofail" "x-systemd.automount" ];
        };
        
        systemd.tmpfiles.rules = [ "d /mnt/fileshare/git 0755 forgejo forgejo -" ];
      })
    ];
    # ~/~ end
  };
}
# ~/~ end
