# xtool (https://github.com/xtool-org/xtool) is a cross-platform Xcode replacement:
# build/sign/deploy iOS apps with SwiftPM, including from Linux.
#
# Two upstream issues block a stock build and are worked around here:
#
# 1. The committed Package.resolved is stale: pointfreeco renamed
#    swift-issue-reporting -> xctest-dynamic-overlay, and the lockfile still pins the
#    old identity. A fresh `swift build` needs network to discover that, which the Nix
#    sandbox doesn't have. ./Package.resolved in this directory is upstream's file run
#    through `swift package resolve` to pick up the rename; it's spliced over the
#    fetched source before `fetchSwiftPMDeps` ever sees it.
# 2. xadi (an xtool dependency) vendors a prebuilt static lib as a SwiftPM binaryTarget
#    fetched from a GitHub release URL. fetchSwiftPMDeps only vendors git-based source
#    dependencies, so this artifact is fetched separately below and spliced into the
#    vendored xadi checkout as a local-path binaryTarget instead of a URL one.
{
  lib,
  stdenv,
  runCommand,
  fetchFromGitHub,
  fetchurl,
  swift,
  swiftpm,
  fetchSwiftPMDeps,
  unzip,
  pkg-config,
  openssl,
  libplist,
  libusbmuxd,
  libimobiledevice-glue,
  libimobiledevice,
  curl,
  libxml2,
  zlib,
  xz,
}:

let
  version = "1.21.0-unstable-2026-10-06";

  upstreamSrc = fetchFromGitHub {
    owner = "xtool-org";
    repo = "xtool";
    rev = "d802c719e43fb2d66a7c7879f7dff75bfdd96a27";
    hash = "sha256-LsII6vY0KIpKnYUAf1N+A0v/DOWEPKayg5c3FS+uxZ0=";
  };

  # Splice in the corrected lockfile (see note 1 above) before anything reads it.
  src = runCommand "xtool-source-${version}" { } ''
    cp -r ${upstreamSrc} $out
    chmod -R u+w $out
    cp ${./Package.resolved} $out/Package.resolved
  '';

  xadiArtifactBundle = fetchurl {
    url = "https://github.com/xtool-org/xadi/releases/download/source-0.4.2/XADIBinary.artifactbundle.zip";
    sha256 = "ca6bb14b2768998ff726d0bb564d8cda8f946b154604753c296978541d95fe0f";
  };
in
stdenv.mkDerivation {
  pname = "xtool";
  inherit version src;

  nativeBuildInputs = [
    swift
    swiftpm
    pkg-config
    unzip
  ];

  buildInputs = [
    openssl
    libplist
    libusbmuxd
    libimobiledevice-glue
    libimobiledevice
    curl
    libxml2
    zlib
    xz
  ];

  swiftpmDeps = fetchSwiftPMDeps {
    pname = "xtool";
    inherit version src;
    hash = "sha256-aFzcJ4i5sPh4ssOptdRpHtKQ7Z6ZE01vlfNTo023/d8=";
  };

  # swiftpmUnpackHook symlinks the whole (read-only, nix-store) `Packages` dir as one
  # unit, which doesn't let us drop the fetched artifact bundle into Packages/xadi. Undo
  # that and re-link each package individually so xadi's checkout can be made writable.
  postPatch = ''
    rm -f Packages
    mkdir -p Packages
    for name in $(ls "$swiftpmDeps/Packages"); do
      if [ "$name" = xadi ]; then
        cp -r "$swiftpmDeps/Packages/xadi" Packages/xadi
        chmod -R u+w Packages/xadi
        unzip -q ${xadiArtifactBundle} -d Packages/xadi
        substituteInPlace Packages/xadi/Package.swift \
          --replace-fail 'url: "https://github.com/xtool-org/xadi/releases/download/source-0.4.2/XADIBinary.artifactbundle.zip",' \
            "" \
          --replace-fail 'checksum: "ca6bb14b2768998ff726d0bb564d8cda8f946b154604753c296978541d95fe0f"' \
            'path: "XADIBinary.artifactbundle"'
      else
        ln -s "$swiftpmDeps/Packages/$name" "Packages/$name"
      fi
    done
  '';

  env.XTOOL_VERSION = "nix-${version}";

  installPhase = ''
    runHook preInstall
    mkdir -p $out/bin
    products=$(swiftpmBinPath)
    install -m755 "$products/xtool" $out/bin/xtool
    # xadi's XADI product is a dynamic library (required by its LGPL license) that
    # xtool links against; the binary's RUNPATH includes $ORIGIN for it.
    install -m755 "$products"/libXADI.so $out/bin/
    runHook postInstall
  '';

  doCheck = false;

  meta = {
    description = "Cross-platform replacement for Xcode (build system, provisioning, deployment)";
    homepage = "https://github.com/xtool-org/xtool";
    license = lib.licenses.mit;
    mainProgram = "xtool";
    platforms = lib.platforms.linux;
  };
}
