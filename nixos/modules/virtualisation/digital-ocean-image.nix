{ config, lib, pkgs, ... }:

with lib;
let
  cfg = config.virtualisation.digitalOceanImage;
  defaultConfigFile = pkgs.writeText "configuration.nix" ''
    { modulesPath, ... }:
    {
      imports = [
        (modulesPath + "/virtualisation/digital-ocean-config.nix")
      ];
    }
  '';
in
{

  imports = [ ./digital-ocean-config.nix ];

  options = {
    virtualisation.digitalOceanImage.diskSize = mkOption {
      type = with types; int;
      default = 4096;
      description = ''
        Size of disk image. Unit is MB.
      '';
    };

    virtualisation.digitalOceanImage.configFile = mkOption {
      type = with types; nullOr str;
      default = null;
      description = ''
        A path to a configuration file which will be placed at `/etc/nixos/configuration.nix`
        and be used when switching to a new configuration.
        If set to `null`, a default configuration is used, where the only import is
        `(modulesPath + "/virtualisation/digital-ocean-config.nix")`.
      '';
    };

    virtualisation.digitalOceanImage.compressionMethod = mkOption {
      type = types.enum [ "gzip" "bzip2" ];
      default = "gzip";
      description = ''
        Disk image compression method.
      '';
    };
  };

  #### implementation
  config = {

    system.build.digitalOceanImage = import ../../lib/make-disk-image.nix {
      name = "digital-ocean-image";
      format = "qcow2";
      postVM = let
        compress = {
          "gzip" = "${pkgs.gzip}/bin/gzip";
          "bzip2" = "${pkgs.bzip2}/bin/bzip2";
        }.${cfg.compressionMethod};
      in ''
        ${compress} $diskImage
      '';
      configFile = if isNull cfg.configFile then defaultConfigFile else cfg.configFile;
      inherit (cfg) diskSize;
      inherit config lib pkgs;
    };

  };

  meta.maintainers = with maintainers; [ arianvp eamsden ];

}
