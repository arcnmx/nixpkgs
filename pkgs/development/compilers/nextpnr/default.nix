{ stdenv, fetchFromGitHub, cmake
, boost, python3, eigen
, icestorm, trellis
, llvmPackages

, enableGui ? true
, wrapQtAppsHook
, qtbase
, OpenGL ? null
}:

let
  boostPython = boost.override { python = python3; enablePython = true; };
in
with stdenv; mkDerivation rec {
  pname = "nextpnr";
  version = "2019.09.03";

  src = fetchFromGitHub {
    owner  = "yosyshq";
    repo   = "nextpnr";
    rev    = "c0f02563e8908f28aa8eaa5eef2b886c0a27a2ab";
    sha256 = "15rlqng4v3wki1hryz7r102fpzk9jhjxcc153l0rr9pn3cy6l4vm";
    fetchSubmodules = true;
  };

  nativeBuildInputs
     = [ cmake ]
    ++ (lib.optional enableGui wrapQtAppsHook);
  buildInputs
     = [ boostPython python3 eigen ]
    ++ (lib.optional enableGui qtbase)
    ++ (lib.optional stdenv.cc.isClang llvmPackages.openmp);

  enableParallelBuilding = true;
  cmakeFlags =
    [ "-DARCH=generic;ice40;ecp5"
      "-DICEBOX_ROOT=${icestorm}/share/icebox"
      "-DTRELLIS_ROOT=${trellis}/share/trellis"
      "-DPYTRELLIS_LIBDIR=${trellis}/lib/trellis"
      "-DUSE_OPENMP=ON"
      # warning: high RAM usage
      "-DSERIALIZE_CHIPDB=OFF"
      # use PyPy for icestorm if enabled
      "-DPYTHON_EXECUTABLE=${icestorm.pythonInterp}"
    ]
    ++ (lib.optional (!enableGui) "-DBUILD_GUI=OFF")
    ++ (lib.optional (enableGui && stdenv.isDarwin)
        "-DOPENGL_INCLUDE_DIR=${OpenGL}/Library/Frameworks");

  # Fix the version number. This is a bit stupid (and fragile) in practice
  # but works ok. We should probably make this overrideable upstream.
  patchPhase = with builtins; ''
    substituteInPlace ./CMakeLists.txt \
      --replace 'git log -1 --format=%h' 'echo ${substring 0 11 src.rev}'
  '';


  postFixup = lib.optionalString enableGui ''
    wrapQtApp $out/bin/nextpnr-generic
    wrapQtApp $out/bin/nextpnr-ice40
    wrapQtApp $out/bin/nextpnr-ecp5
  '';

  meta = with lib; {
    description = "Place and route tool for FPGAs";
    homepage    = https://github.com/yosyshq/nextpnr;
    license     = licenses.isc;
    platforms   = platforms.all;
    maintainers = with maintainers; [ thoughtpolice emily ];
  };
}
