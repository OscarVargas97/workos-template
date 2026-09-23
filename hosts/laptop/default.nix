# Molde de host: scripts/setup.sh copia esta carpeta a hosts/<hostname>/.
{ lib, ... }:
{
  imports = [ ./hardware-configuration.nix ];

  networking.hostName = lib.mkForce "laptop";
  disko.devices.disk.main.device = lib.mkForce "/dev/nvme0n1"; # ver lsblk
}
