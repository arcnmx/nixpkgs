{ lib
, importCargoLock
, fetchCargoTarball
, buildSysroot
, rust
, stdenv
, callPackage
, cacert
, git
, cargoBuildHook
, cargoCheckHook
, cargoInstallHook
, cargoNextestHook
, cargoSetupHook
, rustc
, libiconv
, windows
}:

{ name ? "${args.pname}-${args.version}"

  # Name for the vendored dependencies tarball
, cargoDepsName ? name

, src ? null
, srcs ? null
, unpackPhase ? null
, cargoPatches ? []
, patches ? []
, sourceRoot ? null
, logLevel ? ""
, buildInputs ? []
, nativeBuildInputs ? []
, cargoUpdateHook ? ""
, cargoDepsHook ? ""
, buildType ? "release"
, meta ? {}
, cargoLock ? null
, cargoVendorDir ? null
, checkType ? buildType
, buildNoDefaultFeatures ? false
, checkNoDefaultFeatures ? buildNoDefaultFeatures
, buildFeatures ? [ ]
, checkFeatures ? buildFeatures
, useNextest ? false
, depsExtraArgs ? {}

# Needed to `pushd`/`popd` into a subdir of a tarball if this subdir
# contains a Cargo.toml, but isn't part of a workspace (which is e.g. the
# case for `rustfmt`/etc from the `rust-sources).
# Otherwise, everything from the tarball would've been built/tested.
, buildAndTestSubdir ? null
, ... } @ args:

assert cargoVendorDir == null && cargoLock == null
    -> !(args ? cargoSha256 && args.cargoSha256 != null) && !(args ? cargoHash && args.cargoHash != null)
    -> throw "cargoSha256, cargoHash, cargoVendorDir, or cargoLock must be set";
assert buildType == "release" || buildType == "debug";

let

  cargoDeps =
    if cargoVendorDir != null then null
    else if cargoLock != null then importCargoLock cargoLock
    else fetchCargoTarball ({
      inherit src srcs sourceRoot unpackPhase cargoUpdateHook;
      name = cargoDepsName;
      patches = cargoPatches;
    } // lib.optionalAttrs (args ? cargoHash) {
      hash = args.cargoHash;
    } // lib.optionalAttrs (args ? cargoSha256) {
      sha256 = args.cargoSha256;
    } // depsExtraArgs);

  hostTarget = rust.toRustTargetSpec stdenv.hostPlatform;
  target = args.target or hostTarget;
  targetIsJSON = lib.hasSuffix ".json" target;
  useSysroot = args ? sysroot || (target != hostTarget && targetIsJSON);

  customSysroot = buildSysroot {
    inherit target;
    RUSTFLAGS = args.RUSTFLAGS or "";
    originalCargoToml = src + /Cargo.toml; # profile info is later extracted
  };

in

stdenv.mkDerivation (removeAttrs args [ "depsExtraArgs" "cargoUpdateHook" "cargoLock" ] // lib.optionalAttrs useSysroot rec {
  rustSysroot = args.sysroot or customSysroot;
  #cargoBuildTargetName = rustSysroot.target;
} // {
  inherit buildAndTestSubdir cargoDeps;

  cargoBuildTarget = target;

  cargoBuildType = buildType;

  cargoCheckType = checkType;

  cargoBuildNoDefaultFeatures = buildNoDefaultFeatures;

  cargoCheckNoDefaultFeatures = checkNoDefaultFeatures;

  cargoBuildFeatures = buildFeatures;

  cargoCheckFeatures = checkFeatures;

  patchRegistryDeps = ./patch-registry-deps;

  nativeBuildInputs = nativeBuildInputs ++ [
    cacert
    git
    cargoBuildHook
    (if useNextest then cargoNextestHook else cargoCheckHook)
    cargoInstallHook
    cargoSetupHook
    rustc
  ];

  buildInputs = buildInputs
    ++ lib.optionals stdenv.hostPlatform.isMinGW [ windows.pthreads ];

  patches = cargoPatches ++ patches;

  PKG_CONFIG_ALLOW_CROSS =
    if stdenv.buildPlatform != stdenv.hostPlatform then 1 else 0;

  postUnpack = ''
    eval "$cargoDepsHook"

    export RUST_LOG=${logLevel}
  '' + (args.postUnpack or "");

  configurePhase = args.configurePhase or ''
    runHook preConfigure
    runHook postConfigure
  '';

  doCheck = args.doCheck or true;
  dontCargoCheck = args.dontCargoCheck or (!useSysroot);

  strictDeps = true;

  passthru = { inherit cargoDeps; } // (args.passthru or {});

  meta = {
    # default to Rust's platforms
    platforms = rustc.meta.platforms;
  } // meta;
})
