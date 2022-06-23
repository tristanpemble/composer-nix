# composer-nix

A simple Nix library for packaging PHP/Composer packages with Nix.

Heavy inspiration drawn from [composer2nix](https://github.com/svanderburg/composer2nix),
[composer-plugin-nixify](https://github.com/stephank/composer-plugin-nixify), and [composition-c4](https://github.com/fossar/composition-c4).

This package:

  - allows you to write your derivations with whatever derivation builder you want (e.g. `stdenv.mkDerivation`), instead 
    of being stuck with the limitations of one we provide.
  - support [local path repositories](https://getcomposer.org/doc/05-repositories.md#path); so you can use this in a
    PHP monorepo.

It is not quite yet, but will hopefully soon be:

  - cache friendly. there is work in progress to reuse local Composer caches when possible.
  - fast when updating. there is work in progress to fetch packages in parallel to reduce `composer update` run time.

We are using this in production at [Quartzy](https://www.quartzy.com/careers) to package dozens of our internal
libraries and applications inside a monorepo, continuously on every commit, many times daily.

## How it works

First, there is the `composer-nix` utility. This is a script that generates a file named `composer.nix` that sits
along-side your `composer.json` and `composer.lock` files. This file simply contains a Nix expression that contains
fetchers for all of your package dependencies.

While optional, I highly recommend placing `composer-nix` as a [post-update-cmd script](https://getcomposer.org/doc/articles/scripts.md#command-events)
in your `composer.json`. This will regenerate the file every time Composer modifies its lock file. This keeps the
`composer.nix` file up to date even if developers don't know or care about Nix.

Then, there is the `mkComposerRepo` library function. This function creates a derivation that builds a [Composer
repository](https://getcomposer.org/doc/05-repositories.md#repositories). The output path also contains modified version
of  your `composer.json` and `composer.lock` files that point to that repository.

Now, when installing composer dependencies, you can point to `"${myRepo}/composer.json"`. For a complete example:

```nix
let
  myRepo = mkComposerRepo { composerJson = ./composer.json; }; 
in mkDerivation {
  # ...

  COMPOSER = "${myRepo}/composer.json";
  buildInputs = [ php.packages.composer ];
  configurePhase = ''
    composer install
  '';

  # ...
}
```

The end result is a derivation that is deterministic, and will not refetch its Composer dependencies unless they are
changed.

## Installation

### With Flakes

```nix
{
  inputs.composer-nix.url = "github:tristanpemble/composer-nix";
}
```

### With Niv

```nix
niv add tristanpemble/composer-nix
```

then use the overlay:

```nix
let 
  sources = import ./nix/sources.nix;
  pkgs = import sources.nixpkgs {
    overlays = [
      (import sources.composer-nix).overlays.default
    ];
  };
in <some expression>
```

### With Plain Nix

```nix
let
  composer-nix = pkgs.fetchFromGitHub { 
    owner = "tristanpemble";
    repo = "composer-nix";
    # put the latest commit sha of gitignore Nix library here:
    rev = "";
    # use what nix suggests in the mismatch message here:
    sha256 = "sha256:0000000000000000000000000000000000000000000000000000";
  };
  pkgs = import <nixpkgs> {
    overlays = [
      (import composer-nix).overlays.default
    ];
  };
in <some expression>
```

## Usage

### From the overlay

The nixpkgs overlay exposes `composer-nix` and `mkComposerRepo`.

When using `mkComposerRepo` from the overlay, `system` is not an accepted attribute, since it is inherited from your
package set.

### Inside a flake

- `lib.mkComposerRepo` is a derivation builder. It accepts an attrset with the following attr names:

  | attr name      | optionality  | description                                                                                                                               |
  |----------------|--------------|-------------------------------------------------------------------------------------------------------------------------------------------|
  | `system`       | **required** | the system that is being built for.                                                                                                       |
  | `composerJson` | **required** | the path to your `composer.json`.                                                                                                         |
  | `composerLock` | **optional** | the path to your `composer.lock`. when not provided, defaults to the `composerJson` path, with `.json` replaced with `.lock`.             |
  | `composerNix`  | **optional** | the path to the generated `composer.nix` file. when not provided, defaults to the `composerJson` path, with `.json` replaced with `.nix`. |

- `packages.<system>.composer-nix` is the command line utility to generate `composer.nix` |
- `overlays.default` is an overlay that exposes `composer-nix` and `mkComposerRepo` |

