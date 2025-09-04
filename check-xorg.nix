{ pkgs ? import ./. { overlays = [ ]; config.checkMetaRecursively = true; } }: with pkgs.lib; let
  blacklist = [ "xf86inputvmmouse" "xf86videointel" ];
  xorg = filterAttrs (name: p:
    isDerivation p
    && warnIf (!p.meta.available) "skipping xorg.${name}" p.meta.available
    && ! elem name blacklist
  ) pkgs.xorg;
  checkPkg = name: pkg: ''
    bincount=$((ls ${getBin pkg}/bin 2>/dev/null || true) | wc -l)
    expected=${getBin pkg}/bin/${pkg.meta.mainProgram or pkg.pname or name}
    echo -n '${name}: '
    if [[ $bincount -eq 0 ]]; then
      ${optionalString (pkg ? meta.mainProgram) "echo ERR: empty but expected ${pkg.meta.mainProgram}; exit 1"}
      echo OK: empty package
    elif [[ $bincount -eq 1 ]]; then
      if [[ ! -x $expected ]]; then
        echo ERR: missing $expected
        exit 1
      else
        ${optionalString (! pkg ? meta.mainProgram) "echo ERR: missing mainProgram=${pkg.pname or name}; exit 1"}
        echo OK: $expected
      fi
    elif [[ -x $expected ]]; then
      ${optionalString (! pkg ? meta.mainProgram) "echo WARN: probably missing mainProgram=${pkg.pname or name}"}
      echo OK: but not the only binary in ${getBin pkg}/bin
    else
      ${optionalString (pkg ? meta.mainProgram) "echo ERR: missing $expected"}
      echo WARN: were we expecting something here? ${getBin pkg}/bin
    fi
  '';
in pkgs.runCommand "check-xorg" {
} ''
  ${concatStringsSep "\n" (mapAttrsToList checkPkg xorg)}
  touch $out
''
