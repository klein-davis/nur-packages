# The app runs inside an FHS environment: on first run it installs its Python
# runtime with uv (python-build-standalone 3.11 + manylinux torch/CUDA wheels)
# into ~/.config/VoiceStudio/runtime, and those binaries expect an FHS system.
# /run/opengl-driver/lib supplies libcuda from the host driver.
{
  callPackage,
  buildFHSEnv,
  makeDesktopItem,
}:
let
  unwrapped = callPackage ./unwrapped.nix { };
  desktopItem = makeDesktopItem {
    name = "voicestudio";
    desktopName = "VoiceStudio";
    comment = unwrapped.meta.description;
    exec = "voicestudio %U";
    icon = "voicestudio";
    categories = [
      "Audio"
      "AudioVideo"
    ];
    startupWMClass = "VoiceStudio";
  };
in
buildFHSEnv {
  pname = "voicestudio";
  inherit (unwrapped) version;
  runScript = "${unwrapped}/bin/voicestudio";
  targetPkgs =
    pkgs: with pkgs; [
      stdenv.cc.cc.lib
      glibc
      zlib
      zstd
      bzip2
      xz
      openssl
      libffi
      expat
      util-linux
      libGL
      libglvnd
      mesa
      libdrm
      vulkan-loader
      glib
      nss
      nspr
      dbus
      at-spi2-atk
      cups
      gtk3
      pango
      cairo
      libxkbcommon
      alsa-lib
      libpulseaudio
      pipewire
      portaudio
      libsndfile
      ffmpeg
      espeak-ng
      sox
      numactl
      libx11
      libxext
      libxrender
      libxcomposite
      libxdamage
      libxfixes
      libxrandr
      libxi
      libxtst
      libxcb
      libxshmfence
      xdotool
      wl-clipboard
      git
      cacert
    ];
  extraInstallCommands = ''
    install -Dm644 ${desktopItem}/share/applications/voicestudio.desktop \
      $out/share/applications/voicestudio.desktop
    cp -r ${unwrapped}/share/icons $out/share/
  '';
  passthru = { inherit unwrapped; };
  meta = unwrapped.meta;
}
