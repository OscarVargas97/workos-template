#!/usr/bin/env bash
# Configura este repo privado de punta a punta, preguntando por consola:
#   1. identity.nix          usuario, nombre, email, claves SSH, zona horaria
#   2. hosts/<hostname>/     la máquina a instalar (+ su línea en flake.nix)
#   3. companies/<empresa>/  instancia de company-context (opcional)
#   4. work-os/scripts.env   perfil de la máquina para los scripts de workos
#
# Se puede correr de nuevo: para cada paso muestra el valor actual como
# default (Enter = dejarlo), y nunca borra un host o empresa existente.
# No pide ni guarda contraseñas: esas las piden los scripts de instalación.
#
# Uso: scripts/setup.sh
#
# Sin preguntas (para agentes de IA o automatización): cada respuesta puede
# venir en una variable de entorno; las que estén definidas no se preguntan
# y se validan igual (si una es inválida, el script falla sin escribir nada
# de ese paso). Definir todas = corrida 100% no interactiva.
#   WORKOS_USER         usuario de login (minúsculas)
#   WORKOS_FULLNAME     nombre completo (commits de git)
#   WORKOS_EMAIL        email (commits de git)
#   WORKOS_SSH_KEYS     claves SSH públicas autorizadas, una por línea
#   WORKOS_TIMEZONE     ej. Europe/Madrid
#   WORKOS_LOCALE       formatos regionales, ej. es_ES ("" = solo en_US)
#   WORKOS_HOST         hostname de la máquina a instalar
#   WORKOS_DISK         disco que se BORRA al instalar, ej. /dev/nvme0n1
#   WORKOS_COMPANY      clave de empresa en minúscula ("" = ninguna)
#   WORKOS_SSH_KEY      ruta de la clave SSH privada con la que se instala
#   WORKOS_RBW_EMAIL    email de Bitwarden ("" = ninguno)
# Ej: WORKOS_USER=ana WORKOS_FULLNAME="Ana Pérez" ... scripts/setup.sh
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

# Todo lo que se escribe termina dentro de strings de Nix/shell: se
# rechazan comillas, backslash, '$' y saltos de línea en vez de escaparlos.
ask() { # ask VAR "pregunta" [default] [regex-valida]
  local __var=$1 __q=$2 __def=${3:-} __re=${4:-'^[^"\\$`]*$'} __v
  if [ -n "${!__var+x}" ]; then # ya viene por entorno: no se pregunta
    [[ "${!__var}" =~ $__re ]] || { echo "Valor inválido en $__var: '${!__var}' ($__q)." >&2; exit 1; }
    echo "$__q: ${!__var}"
    return
  fi
  while true; do
    read -rp "$__q${__def:+ [$__def]}: " __v
    __v=${__v:-$__def}
    if [[ "$__v" =~ $__re ]]; then printf -v "$__var" '%s' "$__v"; return; fi
    echo "  Valor inválido, probá de nuevo." >&2
  done
}
current() { # current archivo 'regex con un grupo'  -> valor actual o vacío
  [ -f "$1" ] && sed -nE "s/$2/\1/p" "$1" | head -1 || true
}

echo "== workos: configuración del repo privado"
echo "Enter acepta el valor entre corchetes. Ctrl+C sale sin cambiar nada más."
echo

# --- 1. Identidad ------------------------------------------------------------
echo "--- 1/4 Identidad (identity.nix)"
def_user=$(current identity.nix '^ *name = "([^"]*)";.*')
[ "$def_user" = "user" ] && def_user=""
ask WORKOS_USER "Usuario de login en la máquina (minúsculas, sin espacios)" "${def_user:-$(whoami | tr '[:upper:]' '[:lower:]')}" '^[a-z_][a-z0-9_-]*$'
def_full=$(current identity.nix '^ *fullName = "([^"]*)";.*'); [ "$def_full" = "Tu Nombre" ] && def_full=""
ask WORKOS_FULLNAME "Nombre completo (para los commits de git)" "${def_full:-$(git config user.name 2>/dev/null || true)}" '^[^"\\$`]+$'
def_mail=$(current identity.nix '^ *email = "([^"]*)";.*'); [ "$def_mail" = "tu@email.com" ] && def_mail=""
ask WORKOS_EMAIL "Email (para los commits de git)" "${def_mail:-$(git config user.email 2>/dev/null || true)}" '^[^"\\$` @]+@[^"\\$` @]+$'

echo
KEYS=()
KEY_RE='^(ssh-(ed25519|rsa)|ecdsa-sha2-nistp[0-9]+|sk-ssh-ed25519@openssh\.com) [A-Za-z0-9+/=]+( [^"\\$`]*)?$'
if [ -n "${WORKOS_SSH_KEYS+x}" ]; then # por entorno: exactamente estas
  while IFS= read -r k; do
    [ -z "$k" ] && continue
    [[ "$k" =~ $KEY_RE ]] || { echo "Clave SSH inválida en WORKOS_SSH_KEYS: '$k'." >&2; exit 1; }
    KEYS+=("$k")
  done <<< "$WORKOS_SSH_KEYS"
  echo "Claves SSH: ${#KEYS[@]}"
else
echo "Claves SSH públicas autorizadas a entrar a la máquina (SOLO estas)."
echo "Pegá una por línea (empiezan con ssh-ed25519/ssh-rsa/ecdsa-...). Línea vacía para terminar."
mapfile -t OLD_KEYS < <(sed -nE 's/^ *"((ssh-|ecdsa-|sk-ssh-)[^"]*)".*/\1/p' identity.nix 2>/dev/null)
if [ "${#OLD_KEYS[@]}" -gt 0 ]; then
  printf '  actual: %s\n' "${OLD_KEYS[@]}"
  read -rp "¿Mantener estas ${#OLD_KEYS[@]} clave(s)? [S/n] " yn
  [[ "${yn:-s}" =~ ^[sSyY]$ ]] && KEYS+=("${OLD_KEYS[@]}")
fi
for f in "$HOME/.ssh/id_ed25519.pub" "$HOME/.ssh/id_rsa.pub"; do
  if [ -f "$f" ]; then
    read -rp "¿Incluir $f? [S/n] " yn
    k=$(head -1 "$f")
    [[ "${yn:-s}" =~ ^[sSyY]$ && "$k" =~ $KEY_RE && " ${KEYS[*]} " != *" $k "* ]] && KEYS+=("$k")
  fi
done
while true; do
  read -rp "clave> " k
  [ -z "$k" ] && break
  if [[ "$k" =~ $KEY_RE ]]; then
    KEYS+=("$k")
  else
    echo "  No parece una clave pública SSH, ignorada." >&2
  fi
done
fi
[ "${#KEYS[@]}" -gt 0 ] || echo "  AVISO: sin claves SSH no vas a poder entrar por SSH (sshd solo acepta claves)." >&2

def_tz=$(current identity.nix '^ *time.timeZone = "([^"]*)";.*')
sys_tz=$(timedatectl show -p Timezone --value 2>/dev/null || cat /etc/timezone 2>/dev/null || true)
ask WORKOS_TIMEZONE "Zona horaria (formato Región/Ciudad, ej. Europe/Madrid, America/Mexico_City)" "${def_tz:-${sys_tz:-UTC}}" '^[A-Za-z_]+(/[A-Za-z0-9_+-]+)*$'
ask WORKOS_LOCALE "Formato regional de fecha/número/moneda (ej. es_ES, es_MX, en_US)" "$(current identity.nix '^ *LC_TIME = "([^.]*)\.UTF-8";.*' | head -1)" '^([a-z]{2}_[A-Z]{2})?$'

{
  echo "# Generado por scripts/setup.sh - se puede editar a mano."
  echo "{"
  echo "  workos.user = {"
  echo "    name = \"$WORKOS_USER\";"
  echo "    fullName = \"$WORKOS_FULLNAME\";"
  echo "    email = \"$WORKOS_EMAIL\";"
  echo "    sshKeys = ["
  for k in "${KEYS[@]}"; do echo "      \"$k\""; done
  echo "    ];"
  echo "  };"
  echo
  echo "  time.timeZone = \"$WORKOS_TIMEZONE\";"
  if [ -n "$WORKOS_LOCALE" ] && [ "$WORKOS_LOCALE" != "en_US" ]; then
    echo
    echo "  # Mensajes en inglés, fecha/número/moneda en $WORKOS_LOCALE."
    echo "  i18n.supportedLocales = [ \"en_US.UTF-8/UTF-8\" \"$WORKOS_LOCALE.UTF-8/UTF-8\" ];"
    echo "  i18n.extraLocaleSettings = {"
    for c in LC_TIME LC_NUMERIC LC_MONETARY LC_PAPER LC_MEASUREMENT; do echo "    $c = \"$WORKOS_LOCALE.UTF-8\";"; done
    echo "  };"
  fi
  echo "}"
} > identity.nix
echo "  OK: identity.nix"
echo

# --- 2. Host -----------------------------------------------------------------
echo "--- 2/4 Máquina a instalar (hosts/<hostname>/)"
echo "El hostname es el nombre de la máquina en la red y la clave del flake"
echo "(nixos-rebuild --flake .#<hostname>)."
ask WORKOS_HOST "Hostname" "" '^[a-z][a-z0-9-]*$'
if [ -d "hosts/$WORKOS_HOST" ]; then
  echo "  hosts/$WORKOS_HOST ya existe - no lo toco."
else
  echo "Disco donde se instala (se BORRA entero al instalar). En la máquina"
  echo "destino, 'lsblk' lo muestra: laptops modernas /dev/nvme0n1, SATA /dev/sda,"
  echo "VMs /dev/vda."
  ask WORKOS_DISK "Disco" "/dev/nvme0n1" '^/dev/[a-z0-9/]+$'
  cp -r hosts/laptop "hosts/$WORKOS_HOST"
  sed -i "s|lib.mkForce \"laptop\"|lib.mkForce \"$WORKOS_HOST\"|; s|lib.mkForce \"/dev/nvme0n1\"|lib.mkForce \"$WORKOS_DISK\"|; 1s|.*|# Host $WORKOS_HOST.|" "hosts/$WORKOS_HOST/default.nix"
  echo "  OK: hosts/$WORKOS_HOST/"
fi
if ! grep -q "nixosConfigurations\.$WORKOS_HOST " flake.nix; then
  sed -i "s|^\( *\)# workos:hosts|\1nixosConfigurations.$WORKOS_HOST = host [ workos.nixosModules.disko-default ./hosts/$WORKOS_HOST ];\n\1# workos:hosts|" flake.nix
  echo "  OK: flake.nix (nixosConfigurations.$WORKOS_HOST)"
fi
echo

# --- 3. Empresa --------------------------------------------------------------
echo "--- 3/4 Empresa (opcional)"
echo "Si usás workos para trabajar en una empresa, su contexto (proyectos,"
echo "mappings a Notion/Slack) va en companies/<empresa>/. Clave en minúscula,"
echo "ej. acme. Vacío = saltar."
ask WORKOS_COMPANY "Empresa" "$(current work-os/scripts.env '^COMPANY_NAME=(.*)$')" '^([a-z][a-z0-9-]*)?$'
if [ -n "$WORKOS_COMPANY" ] && [ ! -d "companies/$WORKOS_COMPANY" ]; then
  cp -r companies/example "companies/$WORKOS_COMPANY"
  echo "  OK: companies/$WORKOS_COMPANY/"
fi
echo

# --- 4. Perfil de scripts ----------------------------------------------------
echo "--- 4/4 Perfil de la máquina para los scripts de instalación"
ask WORKOS_SSH_KEY "Clave SSH PRIVADA con la que instalás/entrás (ruta)" "$(current work-os/scripts.env '^SSH_KEY=(.*)$' | grep . || echo "$HOME/.ssh/id_ed25519")" '^[^"\\$` ]+$'
ask WORKOS_RBW_EMAIL "Email de tu cuenta de Bitwarden (opcional)" "$(current work-os/scripts.env '^RBW_EMAIL=(.*)$')" '^[^"\\$` ]*$'
sed -i "s|^LOGIN_USER=.*|LOGIN_USER=$WORKOS_USER|; s|^SSH_KEY=.*|SSH_KEY=$WORKOS_SSH_KEY|; s|^COMPANY_NAME=.*|COMPANY_NAME=$WORKOS_COMPANY|; s|^RBW_EMAIL=.*|RBW_EMAIL=$WORKOS_RBW_EMAIL|" work-os/scripts.env
echo "  OK: work-os/scripts.env"
echo

echo "== Listo. Siguiente:"
echo "  1. Revisá los cambios:   git diff"
echo "  2. Validá el flake:      scripts/check.sh"
echo "  3. Commiteá y pusheá:    git add -A && git commit -m 'Configuración inicial' && git push"
echo "  4. Instalá: ver README.md, sección 'Instalar'."
