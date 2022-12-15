declare -a checkFlags
declare -a cargoTestFlags

cargoPreCheckHook() {
    echo "Executing cargoPreCheckHook"

    if [[ -z ${dontUseCargoParallelTests-} ]]; then
        threads=$NIX_BUILD_CORES
    else
        threads=1
    fi

    if [ "${cargoCheckType}" != "debug" ]; then
        cargoCheckProfileFlag="--${cargoCheckType}"
    fi

    if [ -n "${cargoCheckNoDefaultFeatures-}" ]; then
        cargoCheckNoDefaultFeaturesFlag=--no-default-features
    fi

    if [ -n "${cargoCheckFeatures-}" ]; then
        cargoCheckFeaturesFlag="--features=${cargoCheckFeatures// /,}"
    fi

    if [ -z "${cargoCheckTarget-}" ]; then
        cargoCheckTarget=${cargoBuildTarget-@rustTargetPlatformSpec@}
    fi
}

cargoCheckHook() {
    echo "Executing cargoCheckHook"

    runHook preCheck

    if [[ -n "${buildAndTestSubdir-}" ]]; then
        pushd "${buildAndTestSubdir}"
    fi

    (
        set -x
        cargo test \
              -j $NIX_BUILD_CORES \
              --target "$cargoCheckTarget" \
              --frozen \
              ${cargoCheckProfileFlag} \
              ${cargoCheckNoDefaultFeaturesFlag} \
              ${cargoCheckFeaturesFlag}
              ${cargoTestFlags} \
              -- \
              --test-threads=${threads} \
              ${checkFlags} \
              ${checkFlagsArray+"${checkFlagsArray[@]}"}
    )

    if [[ -n "${buildAndTestSubdir-}" ]]; then
        popd
    fi

    echo "Finished cargoCheckHook"

    runHook postCheck
}

if [ -z "${dontCargoPreCheck-}" ]; then
    preCheckHooks+=(cargoPreCheckHook)
fi

if [ -z "${dontCargoCheck-}" ] && [ -z "${checkPhase-}" ]; then
  checkPhase=cargoCheckHook
fi
