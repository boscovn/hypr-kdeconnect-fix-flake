# hypr-kdeconnect-fix-flake

Nix package and NixOS module for
[hypr-kdeconnect-fix](https://github.com/gfhdhytghd/hypr-kdeconnect-fix), an
`xdg-desktop-portal` RemoteDesktop backend that makes KDE Connect's remote
mouse and keyboard input work on Hyprland and other compositors exposing the
wlroots virtual input protocols (sway, river, Wayfire, labwc, niri, ...).

This repository only packages it; see the upstream README for how it works and
its security notes.

## NixOS

```nix
# flake.nix
inputs.hypr-kdeconnect-fix = {
  url = "github:boscovn/hypr-kdeconnect-fix-flake";
  inputs.nixpkgs.follows = "nixpkgs";
};
```

```nix
# configuration.nix
{ inputs, ... }:
{
  imports = [ inputs.hypr-kdeconnect-fix.nixosModules.default ];

  programs.kdeconnect.enable = true;
  services.hypr-kdeconnect-fix.enable = true;

  # Required, see below.
  xdg.portal.config.hyprland.default = [ "hyprland" "gtk" ];
}
```

The module adds the backend to `xdg.portal.extraPortals` (which registers its
D-Bus service and systemd user unit) and routes RemoteDesktop to it through
`xdg.portal.config.<desktop>`. The package is built against your nixpkgs, not
this flake's lock.

### Why `default` has to be set

`xdg.portal.config.hyprland` becomes
`/etc/xdg/xdg-desktop-portal/hyprland-portals.conf`, which **replaces**
Hyprland's own packaged `hyprland-portals.conf` (`default=hyprland;gtk`); the
files are not merged. If only RemoteDesktop were set, screen sharing,
screenshots, file pickers and every other interface would lose their backend.
The module warns at evaluation when `default` is missing.

### Options

| Option | Default | |
| --- | --- | --- |
| `services.hypr-kdeconnect-fix.enable` | `false` | |
| `services.hypr-kdeconnect-fix.package` | built from this flake's `package.nix` with your `pkgs` | |
| `services.hypr-kdeconnect-fix.desktops` | `[ "hyprland" ]` | Lowercased `XDG_CURRENT_DESKTOP` values to route RemoteDesktop for. `[ ]` leaves routing to you. |

After the first switch, restart the portal frontend (or log out and back in):

```sh
systemctl --user restart xdg-desktop-portal
```

## Other setups

- **Overlay:** `overlays.default` adds `pkgs.hypr-kdeconnect-fix`.
- **Package only:** `nix build github:boscovn/hypr-kdeconnect-fix-flake`.
  On a non-NixOS system, `nix profile install` it and write
  `~/.config/xdg-desktop-portal/<desktop>-portals.conf` yourself as shown in
  the upstream README; the profile's `share/` is on `XDG_DATA_DIRS`, which is
  where the portal, D-Bus service and user unit are found.
- **Different desktop ids for the `.portal` file:**
  `pkgs.hypr-kdeconnect-fix.override { portalUseIn = [ "Hyprland" "my-desktop" ]; }`.
  Only matters when no `portals.conf` routes RemoteDesktop explicitly.
- **A different upstream revision or fork:** the source is the
  `hypr-kdeconnect-fix-src` input (`flake = false`), so point it elsewhere
  without patching this repo:
  ```nix
  inputs.hypr-kdeconnect-fix.inputs.hypr-kdeconnect-fix-src.url = "github:someone/hypr-kdeconnect-fix/some-branch";
  ```
  or once, on the command line:
  `--override-input hypr-kdeconnect-fix/hypr-kdeconnect-fix-src github:someone/hypr-kdeconnect-fix/some-branch`.

## Self-test

These move the pointer in the current Wayland session:

```sh
hypr-kdeconnect-portal --self-test-motion 120 0
hypr-kdeconnect-portal --self-test-scroll 0 120
```

## Updating

The upstream commit is pinned in `flake.lock`, so `nix flake update` bumps it
along with nixpkgs; the version (`0-unstable-<commit date>`) follows from it.
A weekly workflow does that and opens a pull request when `nix flake check`
passes; it builds the package (including upstream's tests) and evaluates a
NixOS system using the module.

## License

The Nix files here are MIT licensed (see `LICENSE`); hypr-kdeconnect-fix
itself is MIT licensed by its author.
