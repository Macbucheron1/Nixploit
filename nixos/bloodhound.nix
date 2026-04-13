# bloodhound-redflake-minimal.nix
#
# Module NixOS minimal extrait et consolidé à partir de:
# - Red-Flake/red-flake-nix
# - Red-Flake/packages (module services.bloodhound-ce)
#
# Objectif:
# - lancer BloodHound CE sans Plasma / desktop integration
# - exposer l'UI sur http://127.0.0.1:9090 pour y accéder depuis Firefox
# - forcer Neo4j 4.4.11, comme dans le repo source
#
# ---------------------------------------------------------------------------
# PRÉREQUIS CÔTÉ FLAKE
# ---------------------------------------------------------------------------
#
# Ajoute ces inputs dans ton flake.nix:
#
#   inputs = {
#     nixpkgs.url = "github:nixos/nixpkgs/nixos-25.11";
#
#     # Neo4j 4.4.11 pinné pour compat BloodHound CE
#     neo4j44pkgs.url =
#       "github:NixOS/nixpkgs/7a339d87931bba829f68e94621536cad9132971a";
#
#     # Module + package BloodHound CE utilisés par Red-Flake
#     redflake-packages = {
#       url = "github:Red-Flake/packages";
#       inputs.nixpkgs.follows = "nixpkgs";
#     };
#   };
#
# Puis importe le module BloodHound CE externe quelque part dans tes modules:
#
#   redflake-packages.nixosModules.bloodhound-ce
#
# et ce fichier:
#
#   ./bloodhound-redflake-minimal.nix
#
# Exemple très simple:
#
#   nixosConfigurations.monhost = nixpkgs.lib.nixosSystem {
#     system = "x86_64-linux";
#     specialArgs = {
#       inherit inputs;
#       inherit (inputs) neo4j44pkgs;
#     };
#     modules = [
#       inputs.redflake-packages.nixosModules.bloodhound-ce
#       ./bloodhound-redflake-minimal.nix
#     ];
#   };
#
# ---------------------------------------------------------------------------
# UTILISATION
# ---------------------------------------------------------------------------
#
# Après rebuild:
#
#   sudo nixos-rebuild switch --flake .#monhost
#
# Puis ouvre:
#
#   http://127.0.0.1:9090
#
# Identifiants par défaut repris du repo source:
#   admin / Password1337
#
# Neo4j côté BloodHound:
#   neo4j / Password1337
#
# PostgreSQL côté API:
#   bloodhound / bloodhound
#
# NOTE:
# - ces secrets sont en dur ici pour coller au comportement du repo source
# - pour une config durable, remplace-les par des passwordFile / secrets runtime
#
{ config, lib, pkgs, neo4j44pkgs, ... }:

let
  # Pin Neo4j 4.4.11 exactement comme dans Red-Flake
  neo4j_4_4_11 =
    neo4j44pkgs.legacyPackages.${pkgs.stdenv.hostPlatform.system}.neo4j;

  # Config Neo4j 4.4 adaptée à BloodHound CE
  neo4j44Conf = pkgs.writeText "neo4j-4.4.conf" ''
    dbms.default_listen_address=127.0.0.1

    dbms.connector.bolt.enabled=true
    dbms.connector.bolt.listen_address=:7687
    dbms.connector.bolt.tls_level=DISABLED

    dbms.connector.http.enabled=true
    dbms.connector.http.listen_address=:7474

    # BloodHound CE / SpecterOps compatibility
    dbms.security.auth_enabled=false
    dbms.security.procedures.unrestricted=apoc.periodic.*,*.specterops.*
    dbms.security.procedures.allowlist=apoc.periodic.*,*.specterops.*
  '';

  # GDS plugin compatible Neo4j 4.4.11, repris du repo
  gdsVersion = "2.6.8";
  gdsJarName = "neo4j-graph-data-science-${gdsVersion}.jar";
  gdsJar = pkgs.fetchurl {
    url = "https://github.com/neo4j/graph-data-science/releases/download/${gdsVersion}/${gdsJarName}";
    sha256 = "sha256-hzEakrAEUHsEOm0u9i6pbzemwKrbWJGqcY6ZGLip5Uk=";
  };
in
{
  # -------------------------------------------------------------------------
  # PostgreSQL pour BloodHound CE
  # -------------------------------------------------------------------------
  services.postgresql = {
    enable = true;
    package = pkgs.postgresql_18;
    enableTCPIP = true;
    settings.port = 5432;

    authentication = lib.mkOverride 10 ''
      local all       all        trust
      host  all       all        ::1/128       trust
      host  all       postgres   127.0.0.1/32  trust
      host  all       bloodhound 127.0.0.1/32  trust
    '';

    initialScript = pkgs.writeText "bloodhound-backend-init.sql" ''
      CREATE ROLE bloodhound WITH LOGIN PASSWORD 'bloodhound' CREATEDB;
      CREATE DATABASE bloodhound;
      GRANT ALL PRIVILEGES ON DATABASE bloodhound TO bloodhound;
    '';
  };

  systemd.services.postgresql-ensure-users = {
    description = "Ensure BloodHound PostgreSQL user and schema permissions";
    after = [ "postgresql.service" ];
    requires = [ "postgresql.service" ];
    wantedBy = [ "multi-user.target" ];
    path = [ config.services.postgresql.package ];
    serviceConfig = {
      Type = "oneshot";
      User = "postgres";
      RemainAfterExit = true;
    };
    script = ''
      psql -d postgres <<-'EOSQL'
        DO $$
        BEGIN
          IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'bloodhound') THEN
            CREATE ROLE bloodhound WITH LOGIN PASSWORD 'bloodhound' CREATEDB;
          END IF;
        END $$;
      EOSQL

      if ! psql -lqt | cut -d \| -f 1 | grep -qw bloodhound; then
        createdb -O bloodhound bloodhound
      fi

      psql -d bloodhound -c "ALTER DATABASE bloodhound OWNER TO bloodhound;"
      psql -d bloodhound -c "GRANT ALL ON SCHEMA public TO bloodhound;"
    '';
  };

  # -------------------------------------------------------------------------
  # Neo4j 4.4.11 pour compat BloodHound CE
  # -------------------------------------------------------------------------
  services.neo4j = {
    enable = true;
    package = neo4j_4_4_11;

    directories.home = lib.mkForce "/var/lib/neo4j";
    directories.data = lib.mkForce "/var/lib/neo4j/data";
    directories.plugins = lib.mkForce "/var/lib/neo4j/plugins";
    directories.imports = lib.mkForce "/var/lib/neo4j/import";
    directories.certificates = lib.mkForce "/var/lib/neo4j/certificates";

    https.sslPolicy = "legacy";
    http.listenAddress = ":7474";
    https.listenAddress = ":7473";
    bolt.tlsLevel = "DISABLED";
    bolt.sslPolicy = "legacy";
    bolt.listenAddress = ":7687";
    bolt.enable = true;
    https.enable = false;

    extraServerConfig = "";
  };

  systemd.services.neo4j.preStart = lib.mkForce ''
    set -eu
    install -d -m 0700 -o neo4j -g neo4j /var/lib/neo4j/{conf,logs,run,plugins,import,data}
    install -m 0600 -o neo4j -g neo4j ${neo4j44Conf} /var/lib/neo4j/conf/neo4j.conf
  '';

  system.activationScripts.setup-neo4j.text = ''
    set -eu

    install -d -m 0700 -o neo4j -g neo4j /var/lib/neo4j/{data,plugins,conf}
    install -d -m 0700 -o neo4j -g neo4j /var/lib/neo4j/data/dbms

    if [ ! -e /var/lib/neo4j/plugins/${gdsJarName} ]; then
      ln -sfn ${gdsJar} /var/lib/neo4j/plugins/${gdsJarName}
      chown -h neo4j:neo4j /var/lib/neo4j/plugins/${gdsJarName}
    fi

    if [ ! -f /var/lib/neo4j/data/dbms/auth.ini ]; then
      ${pkgs.shadow.su}/bin/su -s /bin/sh -c \
        'NEO4J_HOME=/var/lib/neo4j NEO4J_CONF=/var/lib/neo4j/conf ${lib.getExe' neo4j_4_4_11 "neo4j-admin"} set-initial-password "Password1337"' \
        neo4j || true
    fi
  '';

  # -------------------------------------------------------------------------
  # BloodHound CE
  # -------------------------------------------------------------------------
  services.bloodhound-ce = {
    enable = true;
    openFirewall = true;

    settings = {
      server.host = "127.0.0.1";
      server.port = 9090;

      logLevel = "info";
      logPath = "/var/log/bloodhound-ce/bloodhound.log";

      defaultAdmin = {
        principalName = "admin";
        password = "Password1337";
        expireNow = false;
      };

      recreateDefaultAdmin = false;
      featureFlags.darkMode = true;
    };

    database = {
      host = "127.0.0.1";
      user = "bloodhound";
      name = "bloodhound";
      password = "bloodhound";
    };

    neo4j = {
      host = "127.0.0.1";
      port = 7687;
      database = "neo4j";
      user = "neo4j";
      password = "Password1337";
    };
  };

  # On écrase explicitement le JSON généré par le module externe pour
  # corriger collectors_base_path: BloodHound tente de créer ce dossier,
  # donc il ne doit surtout pas pointer dans /nix/store.
  environment.etc."bloodhound/bloodhound.config.json".source = lib.mkForce (
    pkgs.writeText "bloodhound.config.json" (builtins.toJSON {
      version = 2;
      bind_addr = "127.0.0.1:9090";
      work_dir = "/var/lib/bloodhound-ce/work";
      log_level = "INFO";
      log_path = "/var/log/bloodhound-ce/bloodhound.log";
      collectors_base_path = "/var/lib/bloodhound-ce/collectors";

      default_admin = {
        principal_name = "admin";
        password = "Password1337";
        expire_now = false;
      };

      recreate_default_admin = false;

      database = {
        addr = "127.0.0.1:5432";
        database = "bloodhound";
        username = "bloodhound";
      };

      graph_driver = "neo4j";
      neo4j = {
        addr = "127.0.0.1:7687";
        database = "neo4j";
        username = "neo4j";
      };
    })
  );

  # Prépare un collectors_base_path writable hors store Nix
  systemd.services.bloodhound-ce.preStart = lib.mkAfter ''
    install -d -m 0700 -o bloodhound -g bloodhound /var/lib/bloodhound-ce
    install -d -m 0700 -o bloodhound -g bloodhound /var/lib/bloodhound-ce/work
    install -d -m 0755 -o bloodhound -g bloodhound /var/lib/bloodhound-ce/collectors

    if [ -d ${config.services.bloodhound-ce.package}/share/bloodhound/collectors ]; then
      cp -rfn ${config.services.bloodhound-ce.package}/share/bloodhound/collectors/. /var/lib/bloodhound-ce/collectors/
      chown -R bloodhound:bloodhound /var/lib/bloodhound-ce/collectors
    fi
  '';

  # On force les variables runtime vers des chemins writable
  systemd.services.bloodhound-ce.serviceConfig.Environment = lib.mkForce [
    "bhe_work_dir=/var/lib/bloodhound-ce/work"
    "bhe_collectors_base_path=/var/lib/bloodhound-ce/collectors"
    "bhe_database_secret=bloodhound"
    "bhe_neo4j_secret=Password1337"
  ];

  # -------------------------------------------------------------------------
  # Optionnel: ouvre explicitement le port HTTP BloodHound
  # -------------------------------------------------------------------------
  networking.firewall.allowedTCPPorts = [ 9090 ];

  # -------------------------------------------------------------------------
  # Lisibilité / diagnostics
  # -------------------------------------------------------------------------
  environment.systemPackages = with pkgs; [
    firefox
    curl
    jq
  ];
}
