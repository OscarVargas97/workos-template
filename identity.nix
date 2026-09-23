# Quién sos. Los valores de las opciones que declara workos
# (modules/workos.nix) - lo único de identidad que necesita el sistema.
{
  workos.user = {
    name = "user"; # usuario de login
    fullName = "Tu Nombre"; # commits de git
    email = "tu@email.com"; # commits de git
    # Claves públicas autorizadas por SSH - SOLO estas entran.
    sshKeys = [
      # "ssh-ed25519 AAAA... user@otra-maquina"
    ];
  };

  time.timeZone = "UTC";

  # Formatos regionales (fecha/número/moneda) sin cambiar el idioma:
  # i18n.supportedLocales = [ "en_US.UTF-8/UTF-8" "es_ES.UTF-8/UTF-8" ];
  # i18n.extraLocaleSettings.LC_TIME = "es_ES.UTF-8";
}
