# The server shells out to a handful of desktop helpers. They are appended to
# PATH so tools already on the user's PATH win: compositor tools such as
# hyprctl or kscreen-doctor, and a system ydotool that matches the running
# ydotoold.
{
  lib,
  rustPlatform,
  fetchFromGitHub,
  makeWrapper,
  glib,
  wmctrl,
  wtype,
  xdotool,
  xprop,
  xrandr,
  ydotool,
}:
let
  runtimeTools = [
    glib # gdbus, gsettings
    wmctrl
    wtype
    xdotool
    xprop
    xrandr
    ydotool
  ];
in
rustPlatform.buildRustPackage (finalAttrs: {
  pname = "computer-use-linux";
  version = "0.7.7";

  src = fetchFromGitHub {
    owner = "agent-sh";
    repo = "computer-use-linux";
    tag = "v${finalAttrs.version}";
    hash = "sha256-RpcPxcvLuw2E5P6OxlAwHFjXYx7CHd5GmlXWkdIH8Pw=";
  };

  cargoHash = "sha256-p3mpeQWLbkJGAIOqexSOqR6aPRJcPftyXX3IluUhkUU=";

  nativeBuildInputs = [ makeWrapper ];

  # The tests probe the live desktop session (DBus, AT-SPI, compositor).
  doCheck = false;

  postInstall = ''
    for bin in computer-use-linux computer-use-linux-cosmic; do
      wrapProgram $out/bin/$bin --suffix PATH : ${lib.makeBinPath runtimeTools}
    done
  '';

  meta = {
    description = "Linux desktop-control MCP server: AT-SPI trees, Wayland/X11 input, screenshots, window targeting";
    homepage = "https://github.com/agent-sh/computer-use-linux";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
    mainProgram = "computer-use-linux";
  };
})
