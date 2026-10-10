# xtool

[xtool](https://github.com/xtool-org/xtool) is a cross-platform Xcode replacement: build, sign, and deploy iOS apps with SwiftPM from Linux (also macOS/WSL). This packages the `xtool` CLI only — the macOS app bundle (a thin GUI wrapper for Keychain entitlements) isn't relevant on Linux.

## Using it

```sh
xtool --help
xtool new MyApp && cd MyApp && xtool dev   # build/sign/install/launch on a connected device
```

`devices`/`install`/`launch` talk to `usbmuxd` to reach a physical iOS device over USB; nothing in this package starts that daemon, so make sure it's running on your system (`services.usbmuxd.enable = true;` on NixOS).

## How it is built

Plain SwiftPM build via `fetchSwiftPMDeps`, with two patches over upstream (both commented in `package.nix`):

1. **Stale lockfile.** Upstream's `Package.resolved` still pins `pointfreeco/swift-issue-reporting`, which was renamed upstream to `pointfreeco/xctest-dynamic-overlay`. `./Package.resolved` here is upstream's file re-run through `swift package resolve` (with network) to pick up the rename, then spliced over the fetched source before `fetchSwiftPMDeps` reads it. Without this, the sandboxed (network-less) build fails trying to resolve the graph from scratch.
2. **Binary-target artifact.** The `xadi` dependency vendors a prebuilt static lib as a SwiftPM `binaryTarget` fetched from a GitHub release URL. `fetchSwiftPMDeps` only vendors git-based sources, not binary artifacts, so it's fetched separately (`xadiArtifactBundle`) and spliced into the vendored `xadi` checkout as a local-path `binaryTarget` in `postPatch`.

The install phase also copies `libXADI.so` next to the `xtool` binary — `xadi`'s `XADI` product is a dynamic library (required by its LGPL license), and the binary's `$ORIGIN` RUNPATH expects it alongside.

## Updating

There's no automated bump path (nix-update doesn't know about the two patches above). To pick up a newer upstream commit:

```sh
nix-prefetch-github xtool-org xtool --rev <new-rev>   # -> hash for upstreamSrc
```

Then, in a checkout of that revision, run `swift package resolve` with network access and copy the resulting `Package.resolved` over `pkgs/xtool/Package.resolved` here (re-diff against upstream's to confirm it's still just the rename, not a real dependency change worth reviewing). Finally rebuild `swiftpmDeps` with a placeholder hash and take the real one from the mismatch error — it usually stays reusable across revisions where the resolved pins didn't change, but don't assume that.
