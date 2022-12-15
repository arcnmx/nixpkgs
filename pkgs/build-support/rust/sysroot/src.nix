{ lib, stdenv, rustLibSrc, python3, remarshal }:

{ rustPlatform ? { inherit rustLibSrc; }
, profile ? if originalCargoToml != null
    then (lib.importTOML originalCargoToml).profile or {}
    else null
, originalCargoToml ? null
}: let

  mapProfile = profile: builtins.toJSON {
    inherit profile;
  };

in stdenv.mkDerivation {
  name = "cargo-src";
  preferLocalBuild = true;
  nativeBuildInputs = [ python3 remarshal ];
  cargoLock = ./Cargo.lock;
  cargoPy = ./cargo.py;
  RUSTC_SRC = rustPlatform.rustLibSrc;

  cargoProfile = lib.mapNullable mapProfile profile;
  originalCargoToml = if profile == null then originalCargoToml else null;
  passAsFile = [ "cargoProfile" ];

  unpackPhase = "true";
  dontConfigure = true;

  configurePhase = ''
    if [[ -n $originalCargoToml ]]; then
      toml2json $originalCargoToml Cargo.json
      export ORIG_CARGO=Cargo.json
    elif [[ -n $cargoProfilePath ]]; then
      export ORIG_CARGO=$cargoProfilePath
    fi
  '';

  buildPhase = ''
    python $cargoPy $rustLibSrc | json2toml > Cargo.toml
  '';

  installPhase = ''
    mkdir -p $out/src
    echo '#![no_std]' > $out/src/lib.rs
    mv Cargo.toml $out/
    cp $cargoLock $out/Cargo.lock
  '';
}
