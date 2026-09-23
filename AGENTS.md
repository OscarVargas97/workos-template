# AGENTS.md — workos-template (repo privado de workos)

Contexto para agentes de IA. Este repo es (o fue creado desde) el molde
del **repo privado** de una persona que usa
[workos](https://github.com/OscarVargas97/workos). La arquitectura
completa, invariantes y el runbook de instalación están en el
[`AGENTS.md` de workos](https://github.com/OscarVargas97/workos/blob/main/AGENTS.md)
(localmente: `../workos/AGENTS.md`) — leelo primero.

## 1. Rol de este repo

- Es el **flake de entrada** del sistema: `nixos-rebuild --flake .#<hostname>`.
- Importa `workos` como input y le pasa módulos con los datos de la persona
  vía `workos.lib.mkHost [ ./identity.nix ./home.nix <host> ]`.
- Contiene solo **datos y extensiones**. La lógica del sistema se cambia en
  `workos`, no acá. Si algo que querés hacer acá requiere copiar código de
  `workos`, probablemente falta una opción en `workos/modules/workos.nix`.

## 2. Archivos

| Ruta | Contenido | Cómo se modifica |
|---|---|---|
| `flake.nix` | `nixosConfigurations.<host>`; marcador `# workos:hosts` | `scripts/setup.sh` inserta hosts antes del marcador; no borrarlo |
| `identity.nix` | valores de `workos.user.*`, `time.timeZone`, `i18n.*` | `scripts/setup.sh` lo regenera completo |
| `home.nix` | `workos.secretsPolicy`, `environment.systemPackages`, `home-manager.users.${config.workos.user.name}.*` | a mano |
| `hosts/<host>/default.nix` | `networking.hostName`, `disko.devices.disk.main.device` (ambos `mkForce`), ajustes de hardware | `setup.sh` lo crea copiando `hosts/laptop/` |
| `hosts/<host>/hardware-configuration.nix` | hardware detectado | lo escribe y commitea `workos/work-os/scripts/nixos-anywhere-deploy.sh` |
| `companies/<empresa>/` | instancia de company-context (esquema en `workos/company-context/SCHEMA.md`) | `setup.sh` copia `companies/example/`; entidades con `new-entity.py` |
| `work-os/scripts.env` | `LOGIN_USER`, `SSH_KEY`, `COMPANY_NAME`, `RBW_EMAIL` | `setup.sh`; los scripts de `workos` lo leen de `../workos-private/work-os/scripts.env` |
| `work-os/repo-companies.conf` | `ruta-relativa-a-$HOME=empresa=destino` | `migrate-pc.sh` agrega líneas |
| `work-os/secrets-policy.yaml` | allowlist `skill: [secretos]` | a mano; se publica en `~/.config/work-os/` vía Nix |
| `scripts/setup.sh` | configurador interactivo | — |
| `scripts/check.sh` | evalúa todos los hosts (`nix` o contenedor); `--lock` actualiza `flake.lock` | — |

## 3. Reglas específicas

1. **Nunca secretos**, ni siquiera acá: nada de `LOGIN_PASSWORD`,
   `DISK_PASSPHRASE`, tokens ni claves privadas en ningún archivo.
2. `scripts/setup.sh` pregunta por consola o toma `WORKOS_*` del entorno: un agente
   pide los datos a la persona y nunca inventa respuestas (usuario,
   email, claves SSH, disco a borrar).
3. El disco de `hosts/<host>` se borra entero al instalar: confirmar con la
   persona el valor (`lsblk` en la máquina destino) antes de commitearlo.
4. Después de cualquier cambio: `scripts/check.sh` tiene que dar `OK` en
   todos los hosts antes de commitear.
5. Si existe `../workos`, `check.sh` y `rebuild` lo usan en vez del commit
   pineado: para usar lo publicado, `scripts/check.sh --lock` y commitear.

## 4. Pasos para dejar este repo listo para instalar

1. Preferí `../workos/init.sh`, que corre todo lo de abajo. Como agente,
   pedile los datos a la persona y pasalos como variables `WORKOS_*`
   (tabla en `../workos/AGENTS.md` §6.1; lista en el encabezado de
   `scripts/setup.sh`) con `< /dev/null`, o `[HUMANO]` `scripts/setup.sh`
   interactivo.
2. `scripts/check.sh` → todo `OK` (si falla: el error apunta a archivo y línea).
3. `scripts/check.sh --lock`
4. Con OK de la persona: `git add -A && git commit -m "Configuración inicial" && git push`
5. Continuar con el runbook de `workos/AGENTS.md`, paso 5 (ISO) en adelante.
