# Native helper (global shortcuts, dictation output, capture).
{
  lib,
  rustPlatform,
  pkg-config,
  xdotool,
  src,
  version,
}:
rustPlatform.buildRustPackage {
  pname = "voicestudio-desktop-bridge";
  inherit version;
  inherit src;
  sourceRoot = "${src.name}/native/desktop-bridge";
  cargoHash = "sha256-C5Pu20V5hp2Yt4/Ijz6ceeFbqJOG8lLacXTDEvHTVy8=";
  nativeBuildInputs = [ pkg-config ];
  buildInputs = [ xdotool ];
  doCheck = false;
  meta.mainProgram = "voicestudio-desktop-bridge";
}
