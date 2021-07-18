{ lib, buildPackages, fetchurl, perl, buildLinux, nixosTests, modDirVersionArg ? null, ... } @ args:

with lib;

buildLinux (args // rec {
  version = "5.14-rc5";
  extraMeta.branch = "5.14";

  # modDirVersion needs to be x.y.z, will always add .0
  modDirVersion = if (modDirVersionArg == null) then builtins.replaceStrings ["-"] [".0-"] version else modDirVersionArg;

  src = fetchurl {
    url = "https://git.kernel.org/torvalds/t/linux-${version}.tar.gz";
    sha256 = "009n562jrs8b8jrc11qiz1gpqzbrv47rc6ccc6svyhd9wdl14jbc";
  };

  kernelTests = args.kernelTests or [ nixosTests.kernel-generic.linux_testing ];

  # Should the testing kernels ever be built on Hydra?
  extraMeta.hydraPlatforms = [];

} // (args.argsOverride or {}))
