# voicestudio

[VoiceStudio](https://github.com/debpalash/VoiceStudio) is built from the upstream commit pinned in `unwrapped.nix` (`rev` and `hash`). Upstream releases lag behind `main`, so the package tracks `main` with an `X.Y.Z-unstable-YYYY-MM-DD` version. It builds and runs on x86_64-linux only.

## Using the app

- Start it from the application menu (**VoiceStudio**) or run `voicestudio`.
- **First launch:** the setup screen installs the Python runtime (Python 3.11, PyTorch and CUDA libraries). It downloads about 9 GB once, into `~/.config/VoiceStudio/runtime`, and needs at least 9 GiB free.
- **Data:** settings, voices, projects and models live under `~/.config/VoiceStudio`. Uninstalling the package leaves them in place; to reset the app completely, delete that directory.
- **NVIDIA GPU:** needs the NVIDIA driver enabled in the system config (`hardware.graphics.enable = true;` and `services.xserver.videoDrivers = [ "nvidia" ];`). The app reaches `libcuda` through `/run/opengl-driver/lib`. Without a GPU it runs on the CPU.
- **Updates:** the app's own update check doesn't install anything. Update through this flake instead (see below).

## How it is built

| File | Role |
|---|---|
| `package.nix` | The package users install. It wraps the app in an FHS environment (`buildFHSEnv`). |
| `unwrapped.nix` | Builds the Electron app with `electron-builder --dir` on nixpkgs' `electron_44`, with nixpkgs `uv` bundled. |
| `node-modules.nix` | Fixed-output `bun install --frozen-lockfile` of the upstream `bun.lock`. |
| `desktop-bridge.nix` | The Rust native helper (global shortcuts, dictation output). |
| `electron-builder.config.mjs` | Overrides the upstream builder config for the sandboxed Nix build (no Rust build hook, no publishing, `dir` target). |
| `writable-runtime-staging.patch` | Fix for an upstream bug; see below. |

Why it is built this way:

- **The FHS environment:** the app installs its own Python runtime on first launch. That runtime is a prebuilt interpreter and prebuilt PyTorch/CUDA libraries, which expect the file layout of a standard Linux distribution. NixOS doesn't have that layout, so without the FHS environment they cannot start.
- **`electron-builder --dir` rather than `electron app.asar`:** the app only uses its packaged layout (bundled backend, `resources/tools/uv`, `resources/native`) when it is launched as a packaged app.
- **The wrapper script** (`bin/voicestudio` in `unwrapped.nix`) sets three things:
  - the GTK/GSettings environment, without which Chromium aborts at startup with SIGILL;
  - `CHROME_DEVEL_SANDBOX`, which is needed because the store can't hold a setuid sandbox;
  - an unset of `ELECTRON_RUN_AS_NODE`, which otherwise leaks in from VS Code terminals and makes the app exit silently.
- **The patch:** first-run setup copies the backend out of the install location, and the copy inherits the store's read-only permissions. The backend then can't write to it, and the next app update fails to replace it with EACCES. The patch makes the copy writable. It can be removed once upstream carries an equivalent fix.

## Updating

1. In `unwrapped.nix`, set `rev` to the new upstream commit (`git ls-remote https://github.com/debpalash/VoiceStudio main`).
2. Set `version` to upstream's `package.json` version plus the commit date, e.g. `0.5.7-unstable-2026-10-05`.
3. Set `hash` to `lib.fakeHash`.
4. Run `nix build .#voicestudio -L` and paste the `got:` hash into `hash`.

   Repeat for any other hash mismatch the build reports. Each one names the derivation it belongs to:

   | Mismatch in | Field to update | Cause |
   |---|---|---|
   | `voicestudio-node-modules` | `outputHash` in `node-modules.nix` | upstream changed `bun.lock` |
   | `voicestudio-desktop-bridge-…-vendor` | `cargoHash` in `desktop-bridge.nix` | upstream changed the helper's `Cargo.lock` |

Other ways an update can fail:

1. **Hash mismatch:** see the table above.
2. **The patch does not apply:** upstream changed `electron/src/main/runtime-project.ts`.
   - If upstream fixed the bug, delete the patch and its `patches` line.
   - Otherwise, apply the change again in an upstream checkout and regenerate the patch with `git diff -- electron/src/main/runtime-project.ts > writable-runtime-staging.patch`.
3. **An `electron_44` or bun version error:** upstream moved to a newer Electron or bun. Change `electron_44` in `unwrapped.nix` to the version in upstream's `bun.lock` (`"electron@X.Y.Z"`), then update nixpkgs (`nix flake update` here, and your system's channel or flake input) if nixpkgs does not have that version yet.

After a successful build, launch it once (`./result/bin/voicestudio`) and check that it reaches the setup screen or the main window. Then commit the files you changed.

## Troubleshooting

- **Exits immediately with no output:** run `env | grep ELECTRON_RUN_AS_NODE` in the shell you launched from. The wrapper unsets that variable, but a custom launcher that bypasses the wrapper will not.
- **A backend or setup error:** the logs are under `~/.config/VoiceStudio` (the in-app **Logs** view shows them too). Setup's **Clean & Retry** rebuilds the runtime without downloading everything again.
