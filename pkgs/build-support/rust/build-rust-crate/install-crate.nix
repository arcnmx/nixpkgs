crateName: metadata:
''
  runHook preInstall
  mkdir -p $out/bin $out/lib
  if [[ -s target/env ]]; then
    cp target/env $out/env
  fi
  if [[ -s target/link.final ]]; then
    cp target/link.final $out/lib/link
  fi
  echo ${metadata} > $out/lib/metadata
  if [[ -d target/lib ]]; then
    find target/lib \
      -maxdepth 1 \
      -regex ".*\.\(so.[0-9.]+\|so\|a\|dylib\|rlib\)" \
      -print0 | xargs -r -0 cp -t $out/lib
    for lib in $(find $out/lib -name '*-${metadata}*'); do #*/
      ln -s $lib $(sed -e "s/-${metadata}//" <<< $lib)
    done
  fi
  if [[ "$(ls -A target/build)" ]]; then # */
    cp -r target/build/* $out/lib # */
  fi
  if [[ -d target/bin ]]; then
    find target/bin \
      -maxdepth 1 \
      -type f \
      -executable ! \( -regex ".*\.\(so.[0-9.]+\|so\|a\|dylib\)" \) \
      -print0 | xargs -r -0 cp -t $out/bin
  fi
  rmdir --ignore-fail-on-non-empty $out/lib $out/bin
  runHook postInstall
''
