let
  pkgs = import ./pkgs/top-level {
    localSystem = builtins.currentSystem;
    config = {
      checkMetaRecursively = true;
      checkMeta = true;
      allowUnfree = true;
    };
  };
  broken-example = pkgs.stdenv.mkDerivation {
    name = "broken";
    buildInputs = [ pkgs.rarcrack ];
    nativeBuildInputs = [ pkgs.hello ];
  };
in {
  metas = {
    prof = pkgs.libsysprof-capture.meta;
    binutils = pkgs.binutils.meta;
  };
  inherit pkgs broken-example;
  inherit (pkgs) libsysprof-capture unrar rarcrack;
}
