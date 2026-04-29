[![Entangled badge](https://img.shields.io/badge/entangled-Use%20the%20source!-%2300aeff)](https://entangled.github.io/)

# `nixlab`
The configuration files / design documents for my homelab network and server.

## Hardware & Network Anatomy
My home server is a Dell PowerEdge T420, which is running NixOS with `proxmox-nixos` on top of it.

## Nix Flake
I use NixOS for both the host and the VMs running on it.
I will store all of the configurations in a single flake file.

[`./flake.nix`](./flake.nix):
``` {.nix file="flake.nix"}
{
  description = "Flake containing the configuration for Jason G's homelab network and server";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.11";

    <<flake-inputs>>
  };

  outputs = { self, nixpkgs, ... } @ inputs: let
    <<flake-declarations>>
  in {
    <<nixos-host-declaration>>
    <<vm-declarations>>
  };
}
```

## Declarations
These are functions that are shared between multiple configs.

### Nix (The Package Manager) Setup
This enables flakes and other experimental features for the Nix package manager, as well as various other features.

`flake-declarations`:
``` {.nix #flake-declarations}
nixpkgSetup = {
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nix.settings.trusted-users = [ "@wheel" "root" ];
  nixpkgs.config.allowUnfree = true;
  system.stateVersion = "25.11";
};
```

### Localization Setup
Required for NixOS configurations.

`flake-declarations`:
``` {.nix #flake-declarations}
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
```

### Bootloader Setup
GRUB is my bootloader of choice.

`flake-declarations`:
``` {.nix #flake-declarations}
bootloaderSetup = {
  boot.loader.grub.enable = true;
  boot.loader.grub.devices = [ "nodev" ];
  boot.growPartition = true;
};
```

### SSH Setup
I am using SSH to access my machines.

`flake-declarations`:
``` {.nix #flake-declarations}
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
```

### User Setup
The user should have the same name as the machine, and the root user should not be able to be logged into.

`flake-declarations`:
``` {.nix #flake-declarations}
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
```

The normal user on every machine needs to have their password changed manually by me.

### Tailscale
I am using Tailscale to network the VMs and the host together to my client devices.

`flake-declarations`:
``` {.nix #flake-declarations}
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
```

#### Tailscale Serve
I will often want to run `tailscale serve` so that I have a nice URL to access my services.

`flake-declarations`:
``` {.nix #flake-declarations}
tailscaleServe = pathName: protocol: port: let
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

      ${pkgs.tailscale}/bin/tailscale serve --bg ${pathName} ${protocol}://localhost:${port}
    '';
  };
};
```

### Networking Setup
This sets up the hostname of the machine as well as getting networking up.

`flake-declarations`:
``` {.nix #flake-declarations}
networkingSetup = hostname: {
  networking.networkmanager.enable = true;
  networking.hostName = "${hostname}";
};
```

## Host Configuration

`nixos-host-declaration`:
``` {.nix #nixos-host-declaration}
nixosConfigurations.nixoshost = nixpkgs.lib.nixosSystem {
  system = "x86_64-linux";
  modules = [
    <<nixos-host-modules>>

    nixpkgSetup
    localizationSetup
    sshSetup
    (userSetup "nixoshost")
    (networkingSetup "nixoshost")

    ./hardware-configuration.nix
    {
      <<nixos-host-config>>
    }
  ];
};
```

### deployment
The NixOS Host Machine is deployed using `nixos-anywhere`.
However, I also need to transfer over an age key for my secrets, so here is a script to do all of that.

[`deploy-host.sh`](deploy-host.sh):
``` {.sh file="deploy-host.sh"}
extra_files=$(mktemp -d)
mkdir -pv ${extra_files}/run/sops/age
cp --verbose --archive ./keys.txt ${extra_files}/run/sops/age/keys.txt
chmod 600 ${extra_files}/run/sops/age/keys.txt

nix run github:nix-community/nixos-anywhere --                                  \
  --flake .#nixoshost                                                           \
  --generate-hardware-config nixos-generate-config ./hardware-configuration.nix \
  --extra-files "${extra_files}"                                                \
  --target-host $1
```

To deploy, just run the following:
```sh
$ sh deploy-host.sh [USER@IP_ADDR]
```

This should work on any machine that is on the same network as the host and is running Nix on UNIX-like operating system.

### Disk Setup
The NixOS Host Machine is running on my Dell PowerEdge T420 with 8x 1TB hard drives and a single 256GB SSD.
It should be configured to run RAID on the hard drives and a normal boot disk setup on the SSD.
To achieve this, I will be using `disko` to partition and manage my hard drives.


First, I need to import `disko`.

`flake-inputs`:
``` {.nix #flake-inputs}
disko = {
  url = "github:nix-community/disko";
  inputs.nixpkgs.follows = "nixpkgs";
};
```

Then, I need to add `disko` as a NixOS module to my host's configuration.

`nixos-host-modules`:
``` {.nix #nixos-host-modules}
inputs.disko.nixosModules.disko
```

For the RAID disks, I also want to abstract out their configuration in the

`flake-declarations`:
``` {.nix #flake-declarations}
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
```

Finally, I setup the disks in the host's NixOS configuration.

`nixos-host-config`:
``` {.nix #nixos-host-config}
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
```

### Bootloader Config
Because the host is deployed using `nixos-anywhere`, I need to set special boot options for it.

`nixos-host-config`:
``` {.nix #nixos-host-config}
boot.loader.grub = {
  device = "nodev";
  efiSupport = true;
  efiInstallAsRemovable = true;
};
```

### Secrets
I am using `sops-nix` to manage my secrets.
Only the host will be able to decrypt the `secrets.yaml` file, and will share secrets with the VMs through a directory share.
This way, the VMs will only have access to the secrets they need to have access to.

First, I need to add `sops-nix` to my flake inputs:

`flake-inputs`:
``` {.nix #flake-inputs}
sops-nix.url = "github:Mic92/sops-nix";
```

Then, I need to include the `sops-nix` NixOS module.

`nixos-host-modules`:
``` {.nix #nixos-host-modules}
inputs.sops-nix.nixosModules.sops
```

Finally, I can open the `secrets.yaml` file in the host's configuration.

`nixos-host-config`:
``` {.nix #nixos-host-config}
sops = {
  age.keyFile = "/run/sops/age/keys.txt";
  defaultSopsFile = ./secrets.yaml;
  defaultSopsFormat = "yaml";
};
```

Additionally, I need to ensure that the age key is present on the host machine for it to be able to unencrypt the secrets.

`nixos-host-config`:
``` {.nix #nixos-host-config}
boot.initrd.postDeviceCommands = ''
  mkdir -p /run/sops/age
  cp ${./keys.txt} /run/sops/age/keys.txt
  chmod -R 600 /run/sops/age/keys.txt
'';
```

#### Tailscale
The host can directly access the `tailscale_auth_key` from the output path from decrypting the secret.

First, I need to access the secret using `sops-nix`.

`nixos-host-config`:
``` {.nix #nixos-host-config}
sops.secrets."tailscale_auth_key" = { };
```

Then, I simply import the Tailscale setup as a module.

`nixos-host-modules`:
``` {.nix #nixos-host-modules}
({ config, ... }: tailscaleSetup "${config.sops.secrets."tailscale_auth_key".path}")
({ config, ... }: tailscaleServe "/" "https+insecure" "8006")
```

### Wake on Lan
I usually do not keep my server turned on when I am not using it (usually at night).
Thus, I need wake on lan enabled to turn my server powered on.

`nixos-host-config`:
``` {.nix #nixos-host-config}
networking.interfaces = {
  eno1.wakeOnLan.enable = true;
  eno2.wakeOnLan.enable = true;
};
```

## Proxmox Setup
I am using [proxmox-nixos](https://github.com/SaumonNet/proxmox-nixos) for both declarative and imperative VMs.
I want to use something like [Proxmox](https://www.proxmox.com/en/) so that I can play around with VMs quickly and easily through a web interface but the flake also allows me to create and manage VMs declaratively.

First, I have to import the flake.

`flake-inputs`:
``` {.nix #flake-inputs}
proxmox-nixos.url = "github:SaumonNet/proxmox-nixos";
```

Then, add it to the host's modules.

`nixos-host-modules`:
``` {.nix #nixos-host-modules}
inputs.proxmox-nixos.nixosModules.proxmox-ve
```

Next, I need to enable and configure the Proxmox service and the overlay.

`nixos-host-config`:
``` {.nix #nixos-host-config}
services.proxmox-ve = {
  enable = true;
  ipAddress = "0.0.0.0";
};

nixpkgs.overlays = [
  inputs.proxmox-nixos.overlays.x86_64-linux
  inputs.copyparty.overlays.default
];
```

I also want to setup `virtiofsd` so that I can passthrough directories to VMs.

`flake-declarations`:
``` {.nix #flake-declarations}
virtiofsdSetup = let
  pkgs = import nixpkgs { system = "x86_64-linux"; };
in {
  environment.systemPackages = [ pkgs.virtiofsd ];
  system.activationScripts.virtiofsd = ''
    mkdir -p /usr/libexec
    ln -sf ${pkgs.virtiofsd}/bin/virtiofsd /usr/libexec/virtiofsd
  '';
};
```

`nixos-host-modules`:
```  {.nix #nixos-host-modules}
({ config, ... }: virtiofsdSetup)
```

Finally, I need to setup networking for Proxmox.

`nixos-host-config`:
``` {.nix #nixos-host-config}
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
```

## VM Template
This is the template for the declarative VMs deployed on top of the Proxmox host.

`flake-declarations`:
``` {.nix #flake-declarations}
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
```

### Deployment
Here is a script to deploy the VMs, which is meant to be run on the Proxmox host in the directory of the Git repo.

[`deploy-vm.sh`](deploy-vm.sh):
``` {.sh file="deploy-vm.sh"}
extra_files=$(mktemp -d)
mkdir -pv ${extra_files}/var/lib/secrets
sudo cp --verbose --archive /run/secrets/tailscale_auth_key ${extra_files}/var/lib/secrets/tailscale_auth_key
sudo chown $USER ${extra_files}/var/lib/secrets/tailscale_auth_key
chmod 600 ${extra_files}/run/secrets/tailscale_auth_key

<<vm-deployment-extra-files>>

nix run github:nix-community/nixos-anywhere --                                        \
  --flake .#$1                                                                        \
  --generate-hardware-config nixos-generate-config ./hardware-configurations/$1.nix   \
  --extra-files ${extra_files}                                                        \
  --target-host $2
```

## Fileshare
I am using [`copyparty`](https://github.com/9001/copyparty) for managing my storage and [Syncthing](https://syncthing.net/) in order to have shared folders accross devices.

I need to first import `copyparty` as an input to the flake.

`flake-inputs`:
``` {.nix #flake-inputs}
copyparty.url = "github:9001/copyparty";
```

`vm-declarations`:
``` {.nix #vm-declarations}
nixosConfigurations.fileshare = vmTemplate "/dev/sda" "fileshare" [
  ({ config, ... }: tailscaleServe "/" "http" "3923")
  inputs.copyparty.nixosModules.default
  ({ pkgs, ... }: {
    <<fileshare-vm-config>>
  })
];
```

First, I need to setup the passthrough to the fileshare directory on the Proxmox host using VirtioFS.

`fileshare-vm-config`:
``` {.nix #fileshare-vm-config}
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
```

Next, I need to setup the `copyparty` service.

`fileshare-vm-config`:
``` {.nix #fileshare-vm-config}
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
```

In order to setup `copyparty`, I need to define the `admin` user and use `nix-sops` to declare their password declaratively.

`nixos-host-config`:
``` {.nix #nixos-host-config}
sops.secrets."copyparty_admin_passwd" = { };
```

Because of this, I need to make sure the password file is copied over to the newly declared VM during its deployment.

`vm-deployment-extra-files`:
``` {.sh #vm-deployment-extra-files}
if [ "$1" = "fileshare" ]; then
  sudo cp --verbose --archive /run/secrets/copyparty_admin_passwd ${extra_files}/var/lib/secrets/copyparty_admin_passwd
  sudo chown $USER ${extra_files}/var/lib/secrets/copyparty_admin_passwd
  chmod 600 ${extra_files}/run/secrets/copyparty_admin_passwd
fi
```

Finally, I need to setup the Syncthing service.

`fileshare-vm-config`:
``` {.nix #fileshare-vm-config}
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
```

## Temporary Developer Tools (Temporary)
These are programs I need to develop this, but I plan on creating a flake in the future for my dotfiles.

`flake-declarations`:
``` {.nix #flake-declarations}
tempDevTools = let pkgs = import nixpkgs { system = "x86_64-linux"; }; in { environment.systemPackages = with pkgs; [ tmux neovim git gh ]; };
```

`nixos-host-modules`:
``` {.nix #nixos-host-modules}
tempDevTools
```
