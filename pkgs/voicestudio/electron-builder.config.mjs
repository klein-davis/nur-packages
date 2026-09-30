// Nix build overlay on the release electron-builder config (see flake.nix).
// The sandboxed Nix build cannot run cargo or download tools, so the flake
// builds the native helper separately and copies it into resources/native/.
import base from '../electron/electron-builder.config.mjs';

export default {
  ...base,
  afterPack: undefined,
  publish: null,
  linux: { ...base.linux, target: ['dir'] },
};
