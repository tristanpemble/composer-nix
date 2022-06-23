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

    OUT=$(mktemp)

    echo "{ fetchzip }:" > "$OUT"
    echo "{" >> "$OUT"

    fetch_path() {
      echo -e "$2;"
    }

    fetch_zip() {
      echo -n "fetchzip "
      nix-prefetch fetchzip --quiet --output nix --name "$1" --url "$2" --extension zip \
        | sed -e 's/^/  /g' -e 's/^  {/{/' -e 's/}$/};/'
    }

    while read -r PACKAGE_NAME
    do
      read -r PACKAGE_VERSION
      read -r PACKAGE_TYPE
      read -r PACKAGE_URL
      read -r PACKAGE_REF

      echo Prefetching "$PACKAGE_NAME..."
      echo -n "  \"$PACKAGE_NAME\".\"$PACKAGE_VERSION\" = " >> "$OUT"

      case "$PACKAGE_TYPE" in
        path|zip)
          "fetch_$PACKAGE_TYPE" "$PACKAGE_NAME" "$PACKAGE_URL" "$PACKAGE_REF" >> "$OUT"
          ;;
        *)
          echo "$PACKAGE_NAME@$PACKAGE_REF uses an unsupported package type of $PACKAGE_TYPE. Open a ticket to request support:"
          echo "  https://github.com/tristanpemble/composer-nix/issues/new?title=Add%20support%20for%20package%20type:%20$PACKAGE_TYPE"
          exit 1
          ;;
      esac
    done <<< "$PACKAGE_SOURCES"
    echo "}" >> "$OUT"

    mv -f "$OUT" "$PACKAGE_NIX"
  '';
}
