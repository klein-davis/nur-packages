# nur-packages

My custom Nix packages. The repo works two ways from the same files:

- **As a flake:** one overlay puts every package on top of nixpkgs in a system config.
- **As a [NUR](https://github.com/nix-community/NUR) repository:** `default.nix` at the root is the plain Nix entry point NUR reads. See [Submitting to NUR](#submitting-to-nur).

| Package | Description |
|---|---|
| `computer-use-linux` | [computer-use-linux](https://github.com/agent-sh/computer-use-linux), an MCP server for desktop control (accessibility trees, screenshots, input) for AI clients such as LM Studio. See [its notes](pkgs/computer-use-linux/README.md). |
| `voicestudio` | [VoiceStudio](https://github.com/debpalash/VoiceStudio), a fully-local voice cloning, dubbing and dictation app (Electron, x86_64-linux). See [its notes](pkgs/voicestudio/README.md). |

## Try a package

```sh
nix run github:klein-davis/nur-packages#voicestudio
nix build github:klein-davis/nur-packages#voicestudio   # result/bin/voicestudio
```

## Use in a NixOS system config

### Non-flake `configuration.nix`

```nix
{ pkgs, ... }:
let
  myPkgs = builtins.getFlake "github:klein-davis/nur-packages/<commit-sha>";
in
{
  nixpkgs.overlays = [ myPkgs.overlays.default ];
  environment.systemPackages = [ pkgs.voicestudio ];
}
```

This needs flakes enabled (`nix.settings.experimental-features = [ "nix-command" "flakes" ];`). Pin a commit SHA. A branch name also works, but then every rebuild follows whatever was pushed last.

### Flake-based config

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    my-pkgs = {
      url = "github:klein-davis/nur-packages";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, my-pkgs, ... }: {
    nixosConfigurations.<hostname> = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ./configuration.nix
        {
          nixpkgs.overlays = [ my-pkgs.overlays.default ];
          # pkgs.voicestudio is now available everywhere, e.g.:
          # environment.systemPackages = [ pkgs.voicestudio ];
        }
      ];
    };
  };
}
```

Run `nix flake update my-pkgs` in the system config to pick up new commits from this repo.

## What the flake provides

| Output | Purpose |
|---|---|
| `overlays.default` | Adds every package in `default.nix` to the nixpkgs it is applied to. |
| `packages.x86_64-linux.<name>` | Builds a package against this flake's pinned nixpkgs, for `nix build` / `nix run`. |
| `formatter` | `nix fmt` formats the Nix files with nixfmt. |

The overlay builds packages from your system's nixpkgs. The `packages` output uses the nixpkgs pinned in `flake.lock`. For both to produce the same result, keep the two on the same channel; the `follows` line above does that for flake configs.

## Layout

```
default.nix          the package list and the single place to register a package; NUR reads this file
flake.nix            wraps default.nix as overlays.default and packages.<system>
flake.lock           pins nixpkgs for the flake outputs
pkgs/<name>/         one directory per package
```

Each package pins its own upstream source with `fetchFromGitHub` (a rev plus a hash). No package uses a flake input, because NUR evaluates `default.nix` without flakes.

## Add a package

1. Create `pkgs/<name>/package.nix`. It is an ordinary `callPackage` function:

   ```nix
   { lib, stdenv, fetchFromGitHub }:
   stdenv.mkDerivation {
     pname = "<name>";
     version = "1.0.0";
     src = fetchFromGitHub {
       owner = "...";
       repo = "...";
       rev = "v1.0.0";
       hash = lib.fakeHash; # build once, then paste the hash from the error
     };
     meta.platforms = [ "x86_64-linux" ];
   }
   ```

   Keep everything evaluation-time static, which is what NUR requires:
   - hard-code `version`;
   - use `cargoHash`/`npmDepsHash`-style hashes rather than reading `Cargo.lock` or `package.json` out of `src`;
   - never use `builtins.fetch*` or `import <nixpkgs>` inside a package.

   For an untagged commit, use a version like `1.2.3-unstable-YYYY-MM-DD` and `rev = "<full sha>"`.

2. Register it in `default.nix`:

   ```nix
   <name> = pkgs.callPackage ./pkgs/<name>/package.nix { };
   ```

3. Stage the new files before building. A flake only sees files git knows about, so an unstaged file is invisible to it:

   ```sh
   git add -A && nix build .#<name>
   ```

## Update packages

A tagged release where every hash is a standard attribute, such as `computer-use-linux`, updates with [nix-update](https://github.com/Mic92/nix-update):

```sh
nix run nixpkgs#nix-update -- --flake computer-use-linux
```

It bumps `version`, `hash` and `cargoHash`. Other packages are updated by hand:
1. Change `version` and `rev`.
2. Set each hash that has to change to `lib.fakeHash`.
3. Run `nix build .#<name>` and paste each `got:` hash from the error in place of the placeholder.

`nix flake update` only moves the nixpkgs pin used by the flake's `packages` output. Package-specific steps are in each package's README.

## Submitting to NUR

1. Push this repo to a **public** GitHub repository. The `Check` workflow in `.github/workflows/check.yml` runs on every push. It checks formatting, runs `nix flake check`, and evaluates `default.nix` the way NUR does. A green run means NUR can read the repo.
2. To run the NUR evaluation locally (no flakes, restricted eval, no import-from-derivation):

   ```sh
   nix-env -f . -qa '*' --attr-path \
     --option restrict-eval true --option allow-import-from-derivation false \
     -I nixpkgs=$(nix eval --raw --impure --expr '(builtins.getFlake (toString ./.)).inputs.nixpkgs.outPath') \
     -I $PWD
   ```

   It should list every package in `default.nix`.
3. Fork [nix-community/NUR](https://github.com/nix-community/NUR) and add an entry to `repos.json`:

   ```json
   "klein-davis": { "url": "https://github.com/klein-davis/nur-packages" }
   ```

4. Run `./bin/nur format-manifest` and commit `repos.json` only (not `repos.json.lock`). Then open the pull request.
5. After the merge, the packages are available as `nur.repos.klein-davis.<name>`. NUR checks for new commits about once a day, and the workflow's **Notify NUR** step asks it to check right after each push to `main`. Until the repo is listed, that step fails harmlessly.

NUR evaluates packages but builds nothing and serves no binary cache, so users compile packages locally. For `voicestudio` that takes 10–20 minutes.

## Switching a system config to NUR

Once the repo is in NUR, a flake config can get the packages from the NUR input instead of this repo:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nur = {
      url = "github:nix-community/NUR";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, nur, ... }: {
    nixosConfigurations.<hostname> = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ./configuration.nix
        nur.modules.nixos.default
        ({ pkgs, ... }: {
          environment.systemPackages = [ pkgs.nur.repos.klein-davis.voicestudio ];
        })
      ];
    };
  };
}
```

Both routes build the same package definitions against your nixpkgs, so the choice only decides where updates come from:

- **This repo as an input:** you get a commit as soon as you run `nix flake update my-pkgs`.
- **NUR:** you get it after NUR's next update.

Package names differ between the two (`pkgs.voicestudio` vs `pkgs.nur.repos.klein-davis.voicestudio`), so change the references when you switch.
