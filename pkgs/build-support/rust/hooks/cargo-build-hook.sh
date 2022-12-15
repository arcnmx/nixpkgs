declare -a cargoBuildFlags

cargoPreBuildHook() {
    echo "Executing cargoPreBuildHook"

    if [ ! -z "${buildAndTestSubdir-}" ]; then
        # ensure the output doesn't end up in the subdirectory
        export CARGO_TARGET_DIR="$(pwd)/target"
    fi

    if [ "${cargoBuildType}" != "debug" ]; then
        cargoBuildProfileFlag="--${cargoBuildType}"
    fi

    if [ -n "${cargoBuildNoDefaultFeatures-}" ]; then
        cargoBuildNoDefaultFeaturesFlag=--no-default-features
    fi

    if [ -n "${cargoBuildFeatures-}" ]; then
        cargoBuildFeaturesFlag="--features=${cargoBuildFeatures// /,}"
    fi
}

cargoBuildHook() {
    echo "Executing cargoBuildHook"

    runHook preBuild

    if [ ! -z "${buildAndTestSubdir-}" ]; then
        pushd "${buildAndTestSubdir}"
    fi

    (
    set -x
    cargo build -j $NIX_BUILD_CORES \
        --target "${cargoBuildTarget-@rustTargetPlatformSpec@}" \
        --frozen \
        ${cargoBuildProfileFlag} \
        ${cargoBuildNoDefaultFeaturesFlag} \
        ${cargoBuildFeaturesFlag} \
        ${cargoBuildFlags}
    )

    if [ ! -z "${buildAndTestSubdir-}" ]; then
        popd
    fi

    runHook postBuild

    echo "Finished cargoBuildHook"
}

if [ -z "${dontCargoPreBuild-}" ]; then
    preBuildHooks+=(cargoPreBuildHook)
fi

if [ -z "${dontCargoBuild-}" ] && [ -z "${buildPhase-}" ]; then
    buildPhase=cargoBuildHook
fi
