{ stdenv, lib, bundlerEnv, bundlerUpdateScript, makeWrapper, groff }:

stdenv.mkDerivation rec {
  name = "ronn-${version}";
  version = env.gems.ronn.version;

  env = bundlerEnv rec {
    name = "ronn-gems";
    gemdir = ./.;
  };

  phases = ["installPhase"];

  buildInputs = [ makeWrapper ];

  installPhase = ''
    mkdir -p $out/bin
    makeWrapper ${env}/bin/ronn $out/bin/ronn \
      --set PATH ${groff}/bin
  '';

  passthru.updateScript = bundlerUpdateScript "ronn";

  meta = with lib; {
    description = "markdown-based tool for building manpages";
    homepage = https://rtomayko.github.io/ronn/;
    license = licenses.mit;
    maintainers = with maintainers; [ zimbatm nicknovitski ];
    platforms = env.ruby.meta.platforms;
  };
}
