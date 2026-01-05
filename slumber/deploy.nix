{ config, pkgs, inputs, ... }:

{
  imports = [ inputs.sops-nix.homeManagerModules.sops ];

  sops.secrets = {
    "tailscale/ipv4s/slumber" = { };
    "tailscale/ipv4s/proxmox" = { };
    "bot_keys/discord/homelab_bot" = { };
    "mac_addresses/poweredge_t420_2" = { };
  };

  home.packages = [
    (pkgs.writeShellScriptBin "slumber-deploy" ''
      #!/usr/bin/env bash

      MAC_ADDRESS=$(cat ${config.sops.secrets."mac_addresses/poweredge_t420_2".path})
      BOT_KEY=$(cat ${config.sops.secrets."bot_keys/discord/homelab_bot".path})

      ssh slumber@$(cat ${config.sops.secrets."tailscale/ipv4s/slumber".path}) "rm -rf ~/poweredge-bot.py ~/.config/systemd/user/poweredge-bot.service; mkdir -pv ~/.config/systemd/user; [ -f ~/.local/bin/uv ] || (curl -LsSf https://astral.sh/uv/install.sh | sh)"
      scp ${config.home.homeDirectory}/nixlab/slumber/poweredge-bot.py slumber@$(cat ${config.sops.secrets."tailscale/ipv4s/slumber".path}):~/poweredge-bot.py
      scp ${config.home.homeDirectory}/nixlab/slumber/poweredge-bot.service slumber@$(cat ${config.sops.secrets."tailscale/ipv4s/slumber".path}):~/.config/systemd/user/poweredge-bot.service
      ssh slumber@$(cat ${config.sops.secrets."tailscale/ipv4s/slumber".path}) "sed -i 's/MAC_ADDRESS/$MAC_ADDRESS/g' ~/poweredge-bot.py; sed -i 's/BOT_KEY/$BOT_KEY/g' ~/poweredge-bot.py; systemctl --user daemon-reload; systemctl --user enable poweredge-bot.service; (systemctl --user restart poweredge-bot.service || systemctl --user start poweredge-bot.service); loginctl enable-linger slumber"
    '')
  ];
}
