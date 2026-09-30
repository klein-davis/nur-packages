# VoiceStudio built with electron-builder --dir on nixpkgs' Electron, so it runs
# as a packaged app (resources/ holds the backend, omnivoice, uv, native helper).
{
  lib,
  stdenv,
  callPackage,
  fetchFromGitHub,
  bun,
  nodejs,
  electron_44,
  uv,
  makeWrapper,
  wrapGAppsHook3,
  gtk3,
  gsettings-desktop-schemas,
  libGL,
}:
let
  version = "0.5.6-unstable-2026-09-29";
  src = fetchFromGitHub {
    owner = "debpalash";
    repo = "VoiceStudio";
    rev = "0834c8be28460fc4e0518bdb31eb57c494b253b2";
    hash = "sha256-QOBvZ9L9vVs16vb1tVrE2SVqIYeZFsMUp8vv8DZZy+g=";
  };
  electron = electron_44;
  nodeModules = callPackage ./node-modules.nix { inherit src version; };
  desktopBridge = callPackage ./desktop-bridge.nix { inherit src version; };
in
stdenv.mkDerivation {
  pname = "voicestudio-unwrapped";
  inherit version src;

  # First-run setup copies backend sources out of the read-only store; keep the
  # copy writable so the backend and later updates can modify it.
  patches = [ ./writable-runtime-staging.patch ];

  postPatch = ''
    install -Dm644 ${./electron-builder.config.mjs} nix/electron-builder.config.mjs
  '';

  nativeBuildInputs = [
    bun
    nodejs
    makeWrapper
    wrapGAppsHook3
  ];
  # GSettings schemas etc.; Chromium aborts at startup (SIGILL) without them.
  buildInputs = [
    gtk3
    gsettings-desktop-schemas
  ];
  dontWrapGApps = true;

  env = {
    ELECTRON_SKIP_BINARY_DOWNLOAD = "1";
    # electron-builder copies this into resources/tools/uv; the app then
    # bootstraps its Python runtime with it instead of downloading uv.
    VOICESTUDIO_BUNDLED_UV = lib.getExe uv;
  };

  configurePhase = ''
    runHook preConfigure
    export HOME=$TMPDIR
    cp -r ${nodeModules}/node_modules .
    if [ -d ${nodeModules}/electron/node_modules ]; then
      cp -r ${nodeModules}/electron/node_modules electron/
    fi
    chmod -R u+w node_modules electron
    patchShebangs node_modules electron/node_modules
    runHook postConfigure
  '';

  buildPhase = ''
    runHook preBuild
    cd electron
    bun run build:web
    bun run build
    node node_modules/.bin/electron-builder \
      --config ../nix/electron-builder.config.mjs --dir \
      -c.electronDist=${electron.dist} \
      -c.electronVersion=${electron.version}
    cd ..
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p $out/opt
    cp -r electron/release/linux-*unpacked $out/opt/VoiceStudio
    rm -f $out/opt/VoiceStudio/resources/default_app.asar
    install -Dm755 ${lib.getExe desktopBridge} \
      $out/opt/VoiceStudio/resources/native/voicestudio-desktop-bridge
    install -Dm644 electron/build/icons/icon.png \
      $out/share/icons/hicolor/512x512/apps/voicestudio.png
    runHook postInstall
  '';

  # A shell started from VS Code inherits ELECTRON_RUN_AS_NODE=1, which would
  # turn the app into a bare Node process that exits silently.
  postFixup = ''
    makeWrapper $out/opt/VoiceStudio/voicestudio-electron $out/bin/voicestudio \
      "''${gappsWrapperArgs[@]}" \
      --unset ELECTRON_RUN_AS_NODE \
      --set CHROME_DEVEL_SANDBOX $out/opt/VoiceStudio/chrome-sandbox \
      --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath [ libGL ]}
  '';

  passthru = {
    inherit nodeModules desktopBridge electron;
  };

  meta = {
    mainProgram = "voicestudio";
    description = "Fully-local voice cloning, voice design, dubbing and dictation";
    homepage = "https://github.com/debpalash/VoiceStudio";
    license = lib.licenses.agpl3Only;
    platforms = [ "x86_64-linux" ];
  };
}
