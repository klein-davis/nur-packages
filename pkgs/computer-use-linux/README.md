# computer-use-linux

[computer-use-linux](https://github.com/agent-sh/computer-use-linux) is an MCP server that lets an AI client (LM Studio, Claude Desktop, ...) read accessibility trees, take screenshots and click/type on the desktop. It is built from the upstream release tag pinned in `package.nix`.

## Using it

- Check what works on your desktop: `computer-use-linux doctor | jq .readiness`.
- Register it in the MCP client with the command `computer-use-linux` and the argument `mcp`. For LM Studio, in `~/.lmstudio/mcp.json`:

  ```json
  {
    "mcpServers": {
      "computer-use-linux": {
        "command": "/run/current-system/sw/bin/computer-use-linux",
        "args": ["mcp"]
      }
    }
  }
  ```

  Use the absolute path: apps started from the desktop often don't get your shell's `PATH`. The path above is for `environment.systemPackages`; for a user profile it is `~/.nix-profile/bin/computer-use-linux`.
- **Input on Wayland** falls back to `ydotool`, which needs its daemon and access to `/dev/uinput`. A package can't set that up; add to the system config:

  ```nix
  programs.ydotool.enable = true;
  users.users.<you>.extraGroups = [ "ydotool" ];
  ```

## How it is built

`package.nix` is a plain `buildRustPackage` of the tagged release (dependencies vendored via `cargoHash`); no native libraries are needed. Both binaries are installed (`computer-use-linux` and the COSMIC helper `computer-use-linux-cosmic`). The tests are skipped because they need a live desktop session.

The server runs helper programs at runtime (`gdbus`, `gsettings`, `wmctrl`, `wtype`, `xdotool`, `xprop`, `xrandr`, `ydotool`). The wrapper appends them to the end of `PATH`, so the user's own copies take precedence, including compositor tools like `hyprctl` that aren't bundled.

## Updating

```sh
nix run nixpkgs#nix-update -- --flake computer-use-linux   # latest tag: bumps version, hash, cargoHash
nix build .#computer-use-linux
```

If upstream adds a new helper program, add it to `runtimeTools` in `package.nix`.
