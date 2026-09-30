# Package set entry point, read by NUR and wrapped by flake.nix.
# Add new packages here:
#   mytool = pkgs.callPackage ./pkgs/mytool/package.nix { };
{
  pkgs ? import <nixpkgs> { },
}:
{
  voicestudio = pkgs.callPackage ./pkgs/voicestudio/package.nix { };
}
