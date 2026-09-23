# Extras personales y de tus empresas sobre la base de workos: paquetes,
# aliases, VPNs, lo que no tendría sentido para otra persona.
{ config, pkgs, ... }:
{
  # Allowlist real de secretos por skill (default-deny).
  workos.secretsPolicy = ./work-os/secrets-policy.yaml;

  # Segundo factor con la app de códigos del teléfono (workos
  # docs/DECISIONS.md #15). Después de instalar, post-install-setup.sh corre
  # `workos-totp-setup` para crear los códigos; hasta entonces todo entra
  # solo con contraseña.
  # workos.security = {
  #   totp.enable = true;              # bloqueo de pantalla, login, sudo/su/pkexec
  #   totp.enforce = true;             # recién DESPUÉS de workos-totp-setup
  #   sshTotp = {
  #     enable = true;                 # SSH desde fuera de tu red pide código
  #     trustedNetworks = [ "192.168.1.0/24" ];
  #   };
  #   lockTimeout = 900;               # segundos hasta bloquear (default 300)
  # };

  # Paquetes de sistema (ej. la VPN de una empresa):
  # environment.systemPackages = [ pkgs.twingate ];

  home-manager.users.${config.workos.user.name} = {
    # home.packages = [ ];
    # programs.zsh.shellAliases.cdacme = "cd $HOME/Repos/Acme";
  };
}
