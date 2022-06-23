{ stdenvNoCC
, mkComposerRepo
, php
}:

let repo = mkComposerRepo {
  composerJson = ./composer.json;
}; in

stdenvNoCC.mkDerivation {
  name = "example";
  src = ./.;
  buildInputs = [ php php.packages.composer ];

  # https://getcomposer.org/doc/03-cli.md#composer
  COMPOSER = "${repo}/composer.json";

  configurePhase = ''
    composer install
  '';

  installPhase = ''
    mkdir $out
    cp -r . $out
  '';
}
