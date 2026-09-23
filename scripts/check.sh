#!/usr/bin/env bash
# Valida este repo privado sin instalar nada: evalúa cada host del flake
# (nixosConfigurations.*) hasta su derivation del sistema - si hay un error
# de sintaxis, una opción mal escrita o un archivo que falta, aparece acá y
# no en medio de la instalación.
#
# Usa `nix` si está instalado; si no, un contenedor Docker/Podman efímero
# con Nix (no instala nada en este equipo). Si `../workos` existe (clon del
# repo público al lado de este), evalúa contra ese clon en vez del commit
# pineado en flake.lock - para probar cambios de workos sin pushearlos.
#
# Uso:
#   scripts/check.sh [host ...]   valida (sin argumentos: todos los hosts)
#   scripts/check.sh --lock       crea/actualiza flake.lock (pinea workos y
#                                 nixpkgs a su último commit) - commitealo
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
HERE=$(pwd)
PARENT=$(cd .. && pwd)
NAME=$(basename "$HERE")

# Corre igual con nix local o dentro del contenedor. $SRC = este repo,
# $CORE = clon local de workos (si existe), $OUT = dónde dejar flake.lock.
INNER='
set -e
export NIX_CONFIG="experimental-features = nix-command flakes"
cd "$SRC"
if [ "$1" = "--lock" ]; then
  nix flake update --flake "path:$SRC"
  [ "$OUT" = "$SRC" ] || cp "$SRC/flake.lock" "$OUT/flake.lock"
  echo "flake.lock actualizado - commitealo."
  exit 0
fi
OVR=""
[ -f "$CORE/flake.nix" ] && OVR="--override-input workos path:$CORE" && echo "(usando workos local: $CORE)"
HOSTS="$*"
[ -n "$HOSTS" ] || HOSTS=$(grep -oE "nixosConfigurations\.[A-Za-z0-9_-]+" flake.nix | cut -d. -f2 | sort -u)
fail=0
for h in $HOSTS; do
  printf "%-20s " "$h"
  if out=$(nix eval --raw "path:$SRC#nixosConfigurations.$h.config.system.build.toplevel.drvPath" $OVR --no-write-lock-file 2>&1); then
    echo "OK"
  else
    echo "ERROR"; echo "$out" | tail -25 | sed "s/^/    /"; fail=1
  fi
done
[ $fail = 0 ] && echo "Todo OK."
exit $fail
'

if command -v nix >/dev/null 2>&1; then
  SRC="$HERE" CORE="$PARENT/workos" OUT="$HERE" bash -c "$INNER" check "$@"
else
  DOCKER=$(command -v docker || command -v podman || true)
  [ -n "$DOCKER" ] || { echo "Necesito nix, docker o podman. Ver README.md, 'Requisitos'." >&2; exit 1; }
  echo "Sin nix local: usando un contenedor nixos/nix (la primera vez baja nixpkgs, tarda unos minutos)."
  # Se trabaja sobre una copia sin .git (flake path:) y solo flake.lock
  # vuelve al repo real. pwd -W / MSYS_NO_PATHCONV: rutas en Windows (Git Bash).
  HOST_PARENT=$(cd "$PARENT" && { pwd -W 2>/dev/null || pwd; })
  MSYS_NO_PATHCONV=1 "$DOCKER" run --rm \
    -v "$HOST_PARENT:/src" -v workos-nix-store:/nix \
    -e SRC="/w/$NAME" -e CORE="/w/workos" -e OUT="/src/$NAME" \
    nixos/nix sh -c "mkdir -p /w && cp -r /src/$NAME /w/ && { [ -d /src/workos ] && cp -r /src/workos /w/ || true; } && rm -rf /w/*/.git && \
      nix --extra-experimental-features 'nix-command flakes' shell nixpkgs#gnused nixpkgs#gnugrep nixpkgs#coreutils -c sh -c '$INNER' check $*"
fi
