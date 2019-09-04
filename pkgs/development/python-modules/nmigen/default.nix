{ lib
, buildPythonPackage
, pythonOlder
, fetchFromGitHub
, pyvcd
, bitarray
, jinja2

# nmigen.{test,build} call out to these
, yosys
, symbiyosys
, nextpnr ? null
, icestorm ? null
, trellis ? null

# for tests
, yices
}:

buildPythonPackage rec {
  pname = "nmigen";
  version = "unstable-2019-09-03";
  realVersion = lib.substring 0 7 src.rev;

  src = fetchFromGitHub {
    owner = "m-labs";
    repo = "nmigen";
    rev = "943ce317af2f6b1afc0d6612d2eb1d1062ec2a88";
    sha256 = "0pnhy7q4yr75phhkq0q5s4jqn8y96vv6k3i21img5ipn6hk4hhpc";
  };

  disabled = pythonOlder "3.6";

  propagatedBuildInputs = [ pyvcd bitarray jinja2 ];

  checkInputs = [ yosys yices ];

  postPatch = let
    tool = pkg: name:
      if pkg == null then {} else { "${name}" = "${pkg}/bin/${name}"; };

    # Only FOSS toolchain supported out of the box, sorry!
    toolchainOverrides =
      tool yosys "yosys" //
      tool symbiyosys "sby" //
      tool nextpnr "nextpnr-ice40" //
      tool nextpnr "nextpnr-ecp5" //
      tool icestorm "icepack" //
      tool trellis "ecppack";
  in ''
    substituteInPlace setup.py \
      --replace 'versioneer.get_version()' '"${realVersion}"'

    substituteInPlace nmigen/_toolchain.py \
      --replace 'overrides = {}' \
                'overrides = ${builtins.toJSON toolchainOverrides}'
  '';

  meta = with lib; {
    description = "A refreshed Python toolbox for building complex digital hardware";
    homepage = https://github.com/m-labs/nmigen;
    license = licenses.bsd0;
    maintainers = with maintainers; [ emily ];
  };
}
