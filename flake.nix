{
  description = "A very basic flake";

  inputs = {
    compat = {
      url = "github:edolstra/flake-compat";
      flake = false;
    };
    utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, utils, ... }:
    with utils.lib;
    let eachPkgs = fn: eachDefaultSystemMap (system: fn nixpkgs.legacyPackages.${system}); in
    {
      packages = eachPkgs (pkgs: rec{
        default = composer-nix;
        composer-nix = pkgs.callPackage ./lib/composer-nix.nix {};
      });
      apps = eachDefaultSystemMap (system: {
        default.type = "app";
        default.program = "${self.packages.${system}.composer-nix}/bin/composer-nix";
      });
      overlays.default = final: prev: {
        inherit (self.packages.${final.system}) composer-nix;
        mkComposerRepo = final.callPackage ./lib/mk-composer-repo.nix {};
      };
      checks = eachDefaultSystemMap (system: with import nixpkgs { inherit system; overlays = [ self.overlays.default ]; }; {
        example = callPackage ./example {};
      });
      lib = {
        mkComposerRepo = { system, ... }@args:
          let pkgs = import nixpkgs { inherit system; overlays = [ self.overlays.default ]; }; in
          pkgs.mkComposerRepo (builtins.removeAttrs args ["system"]);
      };
    };
}
