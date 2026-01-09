{ config, pkgs, lib, inputs, ... }:

{
  imports = [
    ../common.nix
    ./hardware-configuration.nix

    inputs.disko.nixosModules.disko
  ];

  boot.loader.grub.enable = true;
  boot.loader.grub.devices = lib.mkForce [ "/dev/sda" ];
  boot.loader.grub.useOSProber = true;

  networking.hostName = "squeeze";
  networking.networkmanager.enable = true;

  users.users.squeeze = {
    isNormalUser = true;
    description = "squeeze";
    initialPassword = "squeeze";
    extraGroups = [ "networkmanager" "wheel" ];
    packages = with pkgs; [ git neovim tmux ];
  };

  disko.devices = {
    disk.main = {
      device = "/dev/sda";
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
	    end = "-4G";
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
