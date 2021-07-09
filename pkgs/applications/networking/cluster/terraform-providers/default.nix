{ lib
, buildGoModule
, buildGoPackage
, fetchFromGitHub
, fetchpatch
, callPackage
}:
let
  list = lib.importJSON ./providers.json;

  buildWithGoModule = data:
    buildGoModule {
      pname = data.repo;
      version = data.version;
      subPackages = [ "." ];
      src = fetchFromGitHub {
        inherit (data) owner repo rev sha256;
      };
      vendorSha256 = data.vendorSha256 or null;

      # Terraform allow checking the provider versions, but this breaks
      # if the versions are not provided via file paths.
      postBuild = "mv $NIX_BUILD_TOP/go/bin/${data.repo}{,_v${data.version}}";
      passthru = data;
    };

  buildWithGoPackage = data:
    buildGoPackage {
      pname = data.repo;
      version = data.version;
      goPackagePath = "github.com/${data.owner}/${data.repo}";
      subPackages = [ "." ];
      src = fetchFromGitHub {
        inherit (data) owner repo rev sha256;
      };
      # Terraform allow checking the provider versions, but this breaks
      # if the versions are not provided via file paths.
      postBuild = "mv $NIX_BUILD_TOP/go/bin/${data.repo}{,_v${data.version}}";
      passthru = data;
    };

  # These providers are managed with the ./update-all script
  automated-providers = lib.mapAttrs (_: attrs:
    (if (lib.hasAttr "vendorSha256" attrs) then buildWithGoModule else buildWithGoPackage)
      attrs) list;

  # These are the providers that don't fall in line with the default model
  special-providers = {
    acme = automated-providers.acme.overrideAttrs (attrs: {
      patches = attrs.patches or [ ] ++ [
        (fetchpatch {
          url = "https://github.com/vancluever/terraform-provider-acme/commit/a5834747aebc3677225c68a08ef784cfd7b35e6c.patch";
          sha256 = "091484whrpq6ykpgpndc8kc9cbvd9wwr0b51m1yxp31750lydp8m";
        })
      ];
    });

    # Packages that don't fit the default model
    ansible = callPackage ./ansible {};
    cloudfoundry = callPackage ./cloudfoundry {};
    gandi = callPackage ./gandi {};
    hcloud = callPackage ./hcloud {};
    libvirt = callPackage ./libvirt {};
    linuxbox = callPackage ./linuxbox {};
    lxd = callPackage ./lxd {};
    vpsadmin = callPackage ./vpsadmin {};
    vercel = callPackage ./vercel {};
  };
in
  automated-providers // special-providers
