{
  description = "Mi instancia privada de workos: identidad, hosts y empresas";

  inputs.workos.url = "github:OscarVargas97/workos";

  outputs = { workos, ... }:
    let
      # Todo host lleva la identidad + los extras personales; el resto
      # (base del sistema, home-manager, CLI) viene de workos.
      host = modules: workos.lib.mkHost ([ ./identity.nix ./home.nix ] ++ modules);
    in
    {
      # VM de prueba (QEMU/Boxes).
      nixosConfigurations.vm = host [ workos.nixosModules.vm ];

      # Máquinas reales: una línea por host, con su carpeta hosts/<hostname>/.
      # scripts/setup.sh las agrega solo, justo antes del marcador de abajo.
      # workos:hosts (no borrar: marcador de scripts/setup.sh)
    };
}
