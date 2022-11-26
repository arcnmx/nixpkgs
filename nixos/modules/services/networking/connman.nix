{ config, lib, pkgs, utils, ... }:

with pkgs;
with lib;

let
  cfg = config.services.connman;
  configFile = pkgs.writeText "connman.conf" ''
    [General]
    NetworkInterfaceBlacklist=${concatStringsSep "," cfg.networkInterfaceBlacklist}

    ${cfg.extraConfig}
  '';
  enableIwd = cfg.wifi.backend == "iwd";
in {

  imports = [
    (mkRenamedOptionModule [ "networking" "connman" ] [ "services" "connman" ])
  ];

  ###### interface

  options = {

    services.connman = {

      enable = mkOption {
        type = types.bool;
        default = false;
        description = lib.mdDoc ''
          Whether to use ConnMan for managing your network connections.
        '';
      };

      enableVPN = mkOption {
        type = types.bool;
        default = true;
        description = lib.mdDoc ''
          Whether to enable ConnMan VPN service.
        '';
      };

      extraConfig = mkOption {
        type = types.lines;
        default = "";
        description = lib.mdDoc ''
          Configuration lines appended to the generated connman configuration file.
        '';
      };

      networkInterfaceBlacklist = mkOption {
        type = with types; listOf str;
        default = [ "vmnet" "vboxnet" "virbr" "ifb" "ve" ];
        description = lib.mdDoc ''
          Default blacklisted interfaces, this includes NixOS containers interfaces (ve).
        '';
      };

      wifi = {
        backend = mkOption {
          type = types.enum [ "wpa_supplicant" "iwd" ];
          default = "wpa_supplicant";
          description = lib.mdDoc ''
            Specify the Wi-Fi backend used.
            Currently supported are {option}`wpa_supplicant` or {option}`iwd`.
          '';
        };
      };

      waitOnline = {
        enable = mkOption {
          type = types.bool;
          default = true;
          description = lib.mdDoc ''
            Whether to include ConnMan in network-online.target
          '';
        };

        ignoredInterfaces = mkOption {
          description = lib.mdDoc ''
            Network interfaces to be ignored when deciding if the system is online.
          '';
          type = with types; listOf str;
          default = [];
          example = [ "wg0" ];
        };

        timeout = mkOption {
          description = lib.mdDoc ''
            Time to wait for the network to come online, in seconds. Set to 0 to disable.
          '';
          type = types.ints.unsigned;
          default = 120;
          example = 0;
        };

        extraArgs = mkOption {
          description = lib.mdDoc ''
            Extra command-line arguments to pass to connmand-wait-online.
            These also affect per-interface `connmand-wait-online@` services.
          '';
          type = with types; listOf str;
          default = [];
        };
      };

      extraFlags = mkOption {
        type = with types; listOf str;
        default = [ ];
        example = [ "--nodnsproxy" ];
        description = lib.mdDoc ''
          Extra flags to pass to connmand
        '';
      };

      package = mkOption {
        type = types.package;
        description = lib.mdDoc "The connman package / build flavor";
        default = connman;
        defaultText = literalExpression "pkgs.connman";
        example = literalExpression "pkgs.connmanFull";
      };

    };

  };

  ###### implementation

  config = mkMerge [ {

    services.connman.waitOnline.extraArgs =
      [ "--timeout=${toString cfg.waitOnline.timeout}" ]
      ++ map (i: "--ignore=${i}") cfg.waitOnline.ignoredInterfaces;

  } (mkIf cfg.enable {
    assertions = [{
      assertion = !config.networking.useDHCP;
      message = "You can not use services.connman with networking.useDHCP";
    }{
      # TODO: connman seemingly can be used along network manager and
      # connmanFull supports this - so this should be worked out somehow
      assertion = !config.networking.networkmanager.enable;
      message = "You can not use services.connman with networking.networkmanager";
    }];

    environment.systemPackages = [ cfg.package ];
    systemd.packages = [ cfg.package ];

    systemd.services.connman = {
      wantedBy = [ "multi-user.target" ];
      after = [ "syslog.target" ] ++ optional enableIwd "iwd.service";
      requires = optional enableIwd "iwd.service";
      serviceConfig = {
        ExecStart = [
          ""
          ([
            "${cfg.package}/sbin/connmand"
            "--config=${configFile}"
            "--nodaemon"
          ] ++ optional enableIwd "--wifi=iwd_agent"
          ++ map toString cfg.extraFlags)
        ];
      };
    };

    systemd.services.connman-wait-online = {
      inherit (cfg.waitOnline) enable;
      wantedBy = [ "network-online.target" ];
      stopIfChanged = false;
      restartIfChanged = false;
      serviceConfig.ExecStart = [
        ""
        "${cfg.package}/sbin/connmand-wait-online ${utils.escapeSystemdExecArgs cfg.waitOnline.extraArgs}"
      ];
    };

    systemd.services."connman-wait-online@" = {
      description = "Wait for network interface %I to be configured by ConnMan";
      conflicts = [ "shutdown.target" ];
      requisite = [ "connman.service" ];
      after = [ "connman.service" ];
      stopIfChanged = false;
      restartIfChanged = false;
      unitConfig.DefaultDependencies = false;
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = "${cfg.package}/sbin/connmand-wait-online -i %I ${utils.escapeSystemdExecArgs cfg.waitOnline.extraArgs}";
      };
    };

    systemd.services.connman-vpn = {
      enable = cfg.enableVPN;
      wantedBy = [ "multi-user.target" ];
      after = [ "syslog.target" ];
      before = [ "connman.service" ];
    };

    systemd.services.net-connman-vpn = mkIf cfg.enableVPN {
      description = "D-BUS Service";
      serviceConfig = {
        Name = "net.connman.vpn";
        before = [ "connman.service" ];
        ExecStart = "${cfg.package}/sbin/connman-vpnd -n";
        User = "root";
        SystemdService = "connman-vpn.service";
      };
    };

    networking = {
      useDHCP = false;
      wireless = {
        enable = mkIf (!enableIwd) true;
        dbusControlled = true;
        iwd = mkIf enableIwd {
          enable = true;
        };
      };
      networkmanager.enable = false;
    };
  }) ];
}
