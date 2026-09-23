# workos-template

Molde de tu repo **privado** de [workos](https://github.com/OscarVargas97/workos).
`workos` es el sistema completo (NixOS, escritorio, herramientas, scripts de
instalación) y no tiene datos de nadie. Este repo es donde van **tus**
datos: quién sos, qué máquinas tenés y para qué empresas trabajás.

> **Guía completa de instalación:** [README de workos](https://github.com/OscarVargas97/workos#3-paso-a-paso).
> Este README cubre lo específico de tu repo privado.
>
> **Para agentes de IA:** [`AGENTS.md`](./AGENTS.md).

---

## 1. Crear tu copia privada

> No uses **Fork**: un fork de un repo público no puede ser privado.

Desde GitHub: **Use this template** → **Create a new repository** →
nombre `workos-private` → **Private**.

O desde la terminal (requiere [`gh`](https://cli.github.com/) con `gh auth login`):

```bash
mkdir -p ~/Repos/Externos/workos && cd ~/Repos/Externos/workos
gh repo create workos-private --private --template OscarVargas97/workos-template --clone
gh repo clone OscarVargas97/workos      # el sistema, al lado
```

Tienen que quedar como carpetas hermanas:

```
~/Repos/Externos/workos/
├── workos/            sistema (público)
├── workos-private/    esta copia (privada)
├── iso/               ISO de NixOS, para el pendrive
└── vault/             opcional, local, nunca en git: .env y dumps de proyectos
```

## 2. Configurar

```bash
cd ~/Repos/Externos/workos/workos-private
scripts/setup.sh
```

Te va a preguntar (con explicación en cada paso):

1. **Identidad:** usuario, nombre, email, claves SSH públicas que pueden
   entrar a la máquina, zona horaria, formato regional.
2. **Máquina:** hostname y disco donde se instala (se borra entero al instalar).
3. **Empresa** (opcional): crea `companies/<empresa>/`.
4. **Perfil de instalación:** qué clave SSH usás y tu email de Bitwarden.

Se puede volver a correr cuando quieras: muestra lo actual como valor
por defecto y nunca borra una máquina o empresa existente. Para sumar
otra máquina, corrélo de nuevo con otro hostname.

> Normalmente no lo corrés directo: `workos/init.sh` (del repo público)
> lo corre por vos, junto con la validación y la publicación. Sin
> preguntas: pasá las respuestas como variables `WORKOS_*` (lista en el
> encabezado de `scripts/setup.sh`).

## 3. Validar y publicar

```bash
scripts/check.sh            # evalúa cada máquina, sin instalar nada: todo "OK"
scripts/check.sh --lock     # fija las versiones exactas en flake.lock
git add -A && git commit -m "Configuración inicial" && git push
```

`check.sh` usa `nix` si lo tenés; si no, Docker o Podman (la primera vez
tarda unos minutos). La instalación descarga tu repo desde GitHub, así que
tiene que estar pusheado.

## 4. Instalar

Seguí el [paso 3.4 en adelante del README de workos](https://github.com/OscarVargas97/workos#34-preparar-el-pendrive):
pendrive → `nixos-anywhere-deploy.sh` → `post-install-setup.sh` → (opcional)
`migrate-pc.sh`. Todos esos scripts leen tu perfil de `work-os/scripts.env`
de este repo.

## 5. Qué va en cada archivo

| Archivo | Qué va | Lo crea |
|---|---|---|
| `flake.nix` | Tus máquinas: una línea `nixosConfigurations.<hostname>` por cada una | `setup.sh` (agrega líneas) |
| `identity.nix` | Usuario, nombre, email, claves SSH, zona horaria, locales | `setup.sh` |
| `home.nix` | Extras solo tuyos: paquetes, aliases, VPN de tu empresa, secrets-policy, **segundo factor** (`workos.security`, ejemplo comentado adentro) | a mano |
| `hosts/<hostname>/default.nix` | Nombre y disco de esa máquina, ajustes de su hardware (TPM2, energía) | `setup.sh` |
| `hosts/<hostname>/hardware-configuration.nix` | Hardware detectado | el instalador |
| `companies/<empresa>/` | Contexto de la empresa: proyectos, mappings a Notion/Slack | `setup.sh` + a mano |
| `work-os/scripts.env` | Perfil de la máquina para los scripts de instalación | `setup.sh` |
| `work-os/repo-companies.conf` | Qué repo va a qué empresa al migrar | `migrate-pc.sh` |
| `work-os/secrets-policy.yaml` | Qué secretos de Bitwarden puede pedir cada agente | a mano |

`hosts/laptop/` y `companies/example/` son los moldes que `setup.sh` copia
para crear máquinas y empresas nuevas: no los borres.

### Ejemplos para `home.nix`

```nix
{ config, pkgs, ... }:
{
  workos.secretsPolicy = ./work-os/secrets-policy.yaml;
  environment.systemPackages = [ pkgs.twingate ];          # VPN de tu empresa

  home-manager.users.${config.workos.user.name} = {
    home.packages = [ pkgs.obsidian ];
    programs.zsh.shellAliases.cdacme = "cd $HOME/Repos/Acme";
  };
}
```

Paquetes disponibles: <https://search.nixos.org/packages>. Opciones de
Home Manager: <https://home-manager-options.extranix.com>.

### Una empresa en `companies/<empresa>/`

Un archivo Markdown por proyecto/sistema/decisión, con frontmatter YAML.
El esquema completo está en
[`company-context/SCHEMA.md`](https://github.com/OscarVargas97/workos/blob/main/company-context/SCHEMA.md).

```bash
cd companies/acme
uv run ../../../workos/company-context/tooling/new-entity.py --type project --concept-id project-api --name "API"
uv run ../../../workos/company-context/tooling/validate.py
```

## 6. Reglas

- **Nunca** pongas contraseñas, passphrases ni tokens en este repo, aunque
  sea privado. Los scripts las piden por consola; los tokens de los
  agentes van en Bitwarden.
- El vault (fuera de este repo) guarda `.env` y dumps de tus proyectos
  **cifrado** (`vault.enc`, con `work vault`): local, sin git.
- Ya instalado, `rebuild` aplica este repo a la máquina.
