let
  pkgs = import ./pkgs/top-level rec {
    #system = "x86_64-linux";
    #system = "x86_64-darwin";
    system = "aarch64-darwin";
    localSystem = system;
    config.checkMetaRecursively = true;
  };
  testdrv = pkgs.stdenv.mkDerivation {
    name = "hi";
    buildCommand = ''
      touch $out
    '';
    nativeBuildInputs = [ ];
    buildInputs = [ ];
    #propagatedNativeBuildInputs = [ ];
    propagatedBuildInputs = [ ];
  };
in testdrv
