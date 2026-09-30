# Fixed-output bun install of the upstream lockfile. When `nix flake update`
# brings a changed bun.lock, replace the hash with the one the build error prints.
{
  lib,
  stdenvNoCC,
  bun,
  src,
  version,
}:
stdenvNoCC.mkDerivation {
  pname = "voicestudio-node-modules";
  inherit version src;

  nativeBuildInputs = [ bun ];

  dontConfigure = true;
  buildPhase = ''
    runHook preBuild
    export HOME=$TMPDIR
    export ELECTRON_SKIP_BINARY_DOWNLOAD=1
    bun install --frozen-lockfile --ignore-scripts --no-progress --backend=copyfile
    runHook postBuild
  '';
  installPhase = ''
    runHook preInstall
    mkdir -p $out/electron
    cp -r node_modules $out/
    if [ -d electron/node_modules ]; then cp -r electron/node_modules $out/electron/; fi
    runHook postInstall
  '';
  dontFixup = true;

  outputHashMode = "recursive";
  outputHashAlgo = "sha256";
  outputHash =
    {
      x86_64-linux = "sha256-YVoOZjIqYp6P+zPrTRpV/qNAYfpTjaqBVIvhfqsjieY=";
    }
    .${stdenvNoCC.hostPlatform.system};
}
