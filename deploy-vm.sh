# ~/~ begin <<README.md#deploy-vm.sh>>[init]
extra_files=$(mktemp -d)
mkdir -pv ${extra_files}/var/lib/secrets
sudo cp --verbose --archive /run/secrets/tailscale_auth_key ${extra_files}/var/lib/secrets/tailscale_auth_key
sudo chown $USER ${extra_files}/var/lib/secrets/tailscale_auth_key
chmod 600 ${extra_files}/run/secrets/tailscale_auth_key

# ~/~ begin <<README.md#vm-deployment-extra-files>>[init]
if [ "$1" = "fileshare" ]; then
  sudo cp --verbose --archive /run/secrets/copyparty_admin_passwd ${extra_files}/var/lib/secrets/copyparty_admin_passwd
  sudo chown $USER ${extra_files}/var/lib/secrets/copyparty_admin_passwd
  chmod 600 ${extra_files}/run/secrets/copyparty_admin_passwd
fi
# ~/~ end

nix run github:nix-community/nixos-anywhere --                                        \
  --flake .#$1                                                                        \
  --generate-hardware-config nixos-generate-config ./hardware-configurations/$1.nix   \
  --extra-files ${extra_files}                                                        \
  --target-host $2
# ~/~ end
