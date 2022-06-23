{ writeShellApplication
, php
, jq
, nix-prefetch
}:

writeShellApplication {
  name = "composer-nix";
  runtimeInputs = [ php.packages.composer jq nix-prefetch ];
  text = ''
    PACKAGE_JSON="''${COMPOSER:-./composer.json}"
    PACKAGE_LOCK=''${PACKAGE_JSON//.json/.lock}
    PACKAGE_NIX=''${PACKAGE_JSON//.json/.nix}
    PACKAGE_SOURCES=$(jq -rc '.packages + .["packages-dev"] | sort_by(.name) | .[] | { name: .name, version: .version } + (if .dist? then .dist else .source end) | .name, .version, .type, .url, .reference' < "$PACKAGE_LOCK")

    echo "{" > "$PACKAGE_NIX"

    fetch_path() {
      echo -e "$1;"
    }

    fetch_zip() {
      echo -n "fetchTarball "
      nix-prefetch fetchTarball --quiet --output nix --url "$1" \
        | sed -e 's/^/  /g' -e 's/^  {/{/' -e 's/}$/};/'
    }

    while read -r PACKAGE_NAME
    do
      read -r PACKAGE_VERSION
      read -r PACKAGE_TYPE
      read -r PACKAGE_URL
      read -r PACKAGE_REF

      echo Prefetching "$PACKAGE_NAME..."
      echo -n "  \"$PACKAGE_NAME\".\"$PACKAGE_VERSION\" = " >> "$PACKAGE_NIX"

      case "$PACKAGE_TYPE" in
        path|zip)
          "fetch_$PACKAGE_TYPE" "$PACKAGE_URL" "$PACKAGE_REF" >> "$PACKAGE_NIX"
          ;;
        *)
          echo "$PACKAGE_NAME@$PACKAGE_REF uses an unsupported package type of $PACKAGE_TYPE. Open a ticket to request support:"
          echo "  https://github.com/tristanpemble/nix-nomad/issues/new?title=Add%20support%20for%20package%20type:%20$PACKAGE_TYPE"
          exit 1
          ;;
      esac
    done <<< "$PACKAGE_SOURCES"
    echo "}" >> "$PACKAGE_NIX"
  '';
}
