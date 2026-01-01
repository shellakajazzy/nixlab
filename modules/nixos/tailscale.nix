{ config, pkgs, inputs, ... }:

{
  imports = [ inputs.sops-nix.nixosModules.sops ];
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
}
