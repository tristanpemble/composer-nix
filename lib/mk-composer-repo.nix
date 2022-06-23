{ runCommand
, writeText
, lib
, php
, callPackage
}:

let
  dir = composerJson: builtins.dirOf (builtins.toString composerJson);
  baseName = composerJson: builtins.baseNameOf (builtins.toString composerJson);
  lockName = composerJson: builtins.replaceStrings [".json"] [".lock"] (baseName composerJson);
  nixName = composerJson: builtins.replaceStrings [".json"] [".nix"] (baseName composerJson);
in

{ composerJson
, composerLock ? /. + "${dir composerJson}/${lockName composerJson}"
, composerNix ? /. + "${dir composerJson}/${nixName composerJson}"
}:

let
  composerJsonData = lib.importJSON composerJson // { repositories = []; };
  composerLockData = lib.importJSON composerLock;
  composerNixData = callPackage (builtins.toString composerNix) {};

  packageManifestData = {
    packages = builtins.listToAttrs (builtins.map (pkg: lib.nameValuePair pkg.name {
      "${pkg.version}" = pkg // {
        dist = {
          type = "path";
          url = composerNixData.${pkg.name}.${pkg.version};
          reference = if pkg ? dist then pkg.dist.reference else pkg.source.reference;
        };
        source = {
          type = "path";
          url = composerNixData.${pkg.name}.${pkg.version};
          reference = if pkg ? source then pkg.source.reference else pkg.dist.reference;
        };
      };
    }) (composerLockData.packages ++ composerLockData.packages-dev));
  };
in runCommand "${composerJsonData.name}-dependencies" {
  composerJson = builtins.toJSON composerJsonData;
  composerLock = builtins.toJSON composerLockData;
  packageManifest = builtins.toJSON packageManifestData;
  passAsFile = [ "composerJson" "composerLock" "packageManifest" ];
  buildInputs = [ php.packages.composer ];
} ''
  mkdir -p $out/repo

  cp $packageManifestPath $out/packages.json
  cp $composerJsonPath $out/composer.json
  cp $composerLockPath $out/composer.lock

  pushd $out
  composer config repo.packagist false
  composer config repo.nix '{"type": "composer", "url": "file://'"$out"'"}'
  composer update --ignore-platform-reqs --no-autoloader --no-install --no-cache --no-scripts --no-plugins \
    --no-interaction --no-ansi --no-progress --lock
  popd
''
