{ lib, stdenv, lndir, fetchSysrootSrc, buildRustPackage }:

{ target
, originalCargoToml ? null
, rustPlatform ? { inherit fetchSysrootSrc buildRustPackage; }
, src ? rustPlatform.fetchSysrootSrc { inherit originalCargoToml; }
, RUSTFLAGS ? ""
, ...
}@args:

let
  # see https://github.com/rust-lang/cargo/blob/964a16a28e234a3d397b2a7031d4ab4a428b1391/src/cargo/core/compiler/compile_kind.rs#L151-L168
  # the "${}" is needed to transform the path into a /nix/store path before baseNameOf
  targetName = if lib.hasSuffix ".json" target
    then lib.removeSuffix ".json" (baseNameOf "${target}")
    else target;
in rustPlatform.buildRustPackage (removeAttrs args [ "originalCargoToml" ] // {
  name = "rust-sysroot-${targetName}";
  inherit src RUSTFLAGS;

  RUSTC_BOOTSTRAP = 1;
  sysroot = null;
  cargoLock.lockFile = ./Cargo.lock;
  nativeBuildInputs = [ lndir ];

  doCheck = false;

  installPhase = ''
    runHook preInstall

    export LIBS_DIR=$out/lib/rustlib/$cargoBuildTargetName/lib
    mkdir -p $LIBS_DIR
    echo $cargoReleaseDir
    for f in $cargoReleaseDir/deps/*.{rlib,rmeta}; do
      cp $f $LIBS_DIR
    done

    export RUST_SYSROOT=$(rustc --print=sysroot)
    host=$rustHostPlatformSpec
    lndir -silent $RUST_SYSROOT $out

    runHook postInstall
  '';
})
