{ config, pkgs, lib, neo4j44pkgs, nixploit, ... }:

let
  cfg = nixploit.services.bloodhound;
  neo4j_4_4_11 =
    neo4j44pkgs.legacyPackages.${pkgs.stdenv.hostPlatform.system}.neo4j;

  neo4j44Conf = pkgs.writeText "neo4j-4.4.conf" ''
    dbms.default_listen_address=127.0.0.1

    dbms.connector.bolt.enabled=true
    dbms.connector.bolt.listen_address=:7687
    dbms.connector.bolt.tls_level=DISABLED

    dbms.connector.http.enabled=true
    dbms.connector.http.listen_address=:7474

    dbms.security.auth_enabled=false
    dbms.security.procedures.unrestricted=apoc.periodic.*,*.specterops.*
    dbms.security.procedures.allowlist=apoc.periodic.*,*.specterops.*
  '';

  gdsVersion = "2.6.8";
  gdsJarName = "neo4j-graph-data-science-${gdsVersion}.jar";
  gdsJar = pkgs.fetchurl {
    url = "https://github.com/neo4j/graph-data-science/releases/download/${gdsVersion}/${gdsJarName}";
    sha256 = "sha256-hzEakrAEUHsEOm0u9i6pbzemwKrbWJGqcY6ZGLip5Uk=";
  };
in
{
  services.postgresql = {
    enable = true;
    package = pkgs.postgresql_18;
    enableTCPIP = true;
    settings.port = 5432;

    authentication = lib.mkOverride 10 ''
      local all       all        trust
      host  all       all        ::1/128       trust
      host  all       postgres   127.0.0.1/32  trust
      host  all       ${cfg.database.user} 127.0.0.1/32  trust
    '';
  };

  systemd.services.postgresql-ensure-users = {
    description = "Ensure BloodHound PostgreSQL user and schema permissions";
    after = [ "postgresql.service" ];
    requires = [ "postgresql.service" ];
    path = [ config.services.postgresql.package ];
    serviceConfig = {
      Type = "oneshot";
      User = "postgres";
      RemainAfterExit = true;
    };
    script = ''
      set -eu

      psql -d postgres <<'EOSQL'
        SELECT format(
          'CREATE ROLE ${cfg.database.user} WITH LOGIN PASSWORD %L CREATEDB',
          '${cfg.database.password}'
        )
        WHERE NOT EXISTS (
          SELECT 1 FROM pg_roles WHERE rolname = '${cfg.database.user}'
        )
        \gexec
      EOSQL

      psql -d postgres <<'EOSQL'
        SELECT 'CREATE DATABASE ${cfg.database.name} OWNER ${cfg.database.user}'
        WHERE NOT EXISTS (
          SELECT 1 FROM pg_database WHERE datname = '${cfg.database.name}'
        )
        \gexec
      EOSQL

      psql -d postgres           -c "ALTER DATABASE ${cfg.database.name} OWNER TO ${cfg.database.user};"
      psql -d ${cfg.database.name} -c "ALTER SCHEMA public OWNER TO ${cfg.database.user};"
      psql -d ${cfg.database.name} -c "GRANT USAGE, CREATE ON SCHEMA public TO ${cfg.database.user};"
      psql -d ${cfg.database.name} -c "GRANT ALL ON SCHEMA public TO ${cfg.database.user};"
      psql -d ${cfg.database.name} -c "GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO ${cfg.database.user};"
      psql -d ${cfg.database.name} -c "GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO ${cfg.database.user};"
      psql -d ${cfg.database.name} -c "ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO ${cfg.database.user};"
      psql -d ${cfg.database.name} -c "ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO ${cfg.database.user};"
    '';
  };

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
        'NEO4J_HOME=/var/lib/neo4j NEO4J_CONF=/var/lib/neo4j/conf ${lib.getExe' neo4j_4_4_11 "neo4j-admin"} set-initial-password "${cfg.neo4j.initialPassword}"' \
        ${cfg.neo4j.user} || true
    fi
  '';

  services.bloodhound-ce = {
    enable = true;
    openFirewall = false;

    settings = {
      server.host = "127.0.0.1";
      server.port = 9090;

      logLevel = "info";
      logPath = "/var/log/bloodhound-ce/bloodhound.log";

      defaultAdmin = {
        principalName = cfg.admin.username;
        password = cfg.admin.password;
        expireNow = false;
      };

      recreateDefaultAdmin = false;
    };

    database = {
      createLocally = false;
      host = "127.0.0.1";
      port = "5432";
      user = cfg.database.user;
      name = cfg.database.name;
      password = cfg.database.password;
    };

    neo4j = {
      host = "127.0.0.1";
      port = 7687;
      database = cfg.neo4j.database;
      user = cfg.neo4j.user;
      password = cfg.neo4j.password;
    };
  };

  systemd.services.bloodhound-ce.serviceConfig.StateDirectory = lib.mkAfter [
    "bloodhound-ce/collectors"
  ];

  systemd.services.bloodhound-ce.preStart = lib.mkAfter ''
    install -d -m 0700 -o ${config.services.bloodhound-ce.user} -g ${config.services.bloodhound-ce.group} /var/lib/bloodhound-ce
    install -d -m 0700 -o ${config.services.bloodhound-ce.user} -g ${config.services.bloodhound-ce.group} /var/lib/bloodhound-ce/work
    install -d -m 0755 -o ${config.services.bloodhound-ce.user} -g ${config.services.bloodhound-ce.group} /var/lib/bloodhound-ce/collectors

    if [ -d ${config.services.bloodhound-ce.package}/share/bloodhound/collectors ]; then
      cp -rfn ${config.services.bloodhound-ce.package}/share/bloodhound/collectors/. /var/lib/bloodhound-ce/collectors/
      chown -R ${config.services.bloodhound-ce.user}:${config.services.bloodhound-ce.group} /var/lib/bloodhound-ce/collectors
    fi
  '';

  systemd.services.bloodhound-ce.serviceConfig.Environment = lib.mkAfter [
    "bhe_collectors_base_path=/var/lib/bloodhound-ce/collectors"
  ];

  # Stack installed/configured, but not started at boot
  systemd.services = {
    bloodhound-ce.wantedBy = lib.mkForce [ ];
    neo4j.wantedBy = lib.mkForce [ ];
    postgresql.wantedBy = lib.mkForce [ ];
    postgresql-ensure-users.wantedBy = lib.mkForce [ ];
  };

  environment.systemPackages = with pkgs; [
    (writeShellScriptBin "bloodhound-start" ''
      set -euo pipefail

      if [ "$(id -u)" -ne 0 ]; then
        echo "bloodhound-start must be run as root" >&2
        exit 1
      fi

      echo "[*] Starting BloodHound stack..."
      ${systemd}/bin/systemctl start postgresql
      ${systemd}/bin/systemctl start postgresql-ensure-users
      ${systemd}/bin/systemctl start neo4j
      ${systemd}/bin/systemctl start bloodhound-ce

      echo "[+] BloodHound stack started"
    '')

    (writeShellScriptBin "bloodhound-stop" ''
      set -euo pipefail

      if [ "$(id -u)" -ne 0 ]; then
        echo "bloodhound-stop must be run as root" >&2
        exit 1
      fi

      echo "[*] Stopping BloodHound stack..."
      ${systemd}/bin/systemctl stop bloodhound-ce || true
      ${systemd}/bin/systemctl stop neo4j || true
      ${systemd}/bin/systemctl stop postgresql || true

      echo "[+] BloodHound stack stopped"
    '')
  ];
}
