{
  description = "My custom Nix packages";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { nixpkgs, ... }:
    let
      systems = [ "x86_64-linux" ];
      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});
    in
    {
      # Adds every package from ./default.nix on top of the nixpkgs it is applied to.
      overlays.default = final: _prev: import ./default.nix { pkgs = final; };

      # `nix build .#<name>` / `nix run .#<name>` without touching a system config.
      packages = forAllSystems (pkgs: import ./default.nix { inherit pkgs; });

      formatter = forAllSystems (pkgs: pkgs.nixfmt);
    };
}
