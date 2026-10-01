{
  description = "Nix package and NixOS module for hypr-kdeconnect-fix, a RemoteDesktop portal backend for KDE Connect on Hyprland/wlroots";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    # Upstream source, pinned by flake.lock; `nix flake update` follows master.
    hypr-kdeconnect-fix-src = {
      url = "github:gfhdhytghd/hypr-kdeconnect-fix";
      flake = false;
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      hypr-kdeconnect-fix-src,
    }:
    let
      inherit (nixpkgs) lib;
      forAllSystems = lib.genAttrs [
        "x86_64-linux"
        "aarch64-linux"
      ];

      # Upstream has no release tags: nixpkgs' "0-unstable-YYYY-MM-DD".
      date = hypr-kdeconnect-fix-src.lastModifiedDate;
      version = "0-unstable-${lib.substring 0 4 date}-${lib.substring 4 2 date}-${lib.substring 6 2 date}";

      # Built with whichever pkgs is given, so consumers get their own nixpkgs.
      packageFor =
        pkgs:
        pkgs.callPackage ./package.nix {
          src = hypr-kdeconnect-fix-src;
          inherit version;
        };
    in
    {
      overlays.default = final: _prev: {
        hypr-kdeconnect-fix = packageFor final;
      };

      nixosModules.default = lib.modules.importApply ./module.nix { inherit packageFor; };

      packages = forAllSystems (system: rec {
        hypr-kdeconnect-fix = packageFor nixpkgs.legacyPackages.${system};
        default = hypr-kdeconnect-fix;
      });

      checks = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          # A minimal system using the module, as a consumer would.
          eval = lib.nixosSystem {
            inherit system;
            modules = [
              self.nixosModules.default
              {
                services.hypr-kdeconnect-fix.enable = true;
                xdg.portal.config.hyprland.default = [
                  "hyprland"
                  "gtk"
                ];
                boot.loader.grub.enable = false;
                fileSystems."/" = {
                  device = "none";
                  fsType = "tmpfs";
                };
                system.stateVersion = "26.05";
              }
            ];
          };
          etc = eval.config.environment.etc;
        in
        {
          package = self.packages.${system}.default;

          # The module registers the D-Bus service, the systemd user unit it
          # activates, the .portal file and the RemoteDesktop routing.
          module =
            # The module only warns when routing would hide the compositor's defaults.
            assert !lib.any (lib.hasInfix "hypr-kdeconnect-fix") eval.config.warnings;
            pkgs.runCommand "hypr-kdeconnect-fix-module-check" { } ''
              test -e ${etc."systemd/user".source}/hypr-kdeconnect-portal.service
              grep -q '^SystemdService=hypr-kdeconnect-portal.service$' \
                ${eval.config.system.path}/share/dbus-1/services/org.freedesktop.impl.portal.desktop.hypr_kdeconnect.service
              test -e ${eval.config.system.path}/share/xdg-desktop-portal/portals/hypr-kdeconnect.portal
              grep -q '^org.freedesktop.impl.portal.RemoteDesktop=hypr-kdeconnect$' \
                ${etc."xdg/xdg-desktop-portal/hyprland-portals.conf".source}
              touch $out
            '';
        }
      );

      formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.nixfmt-tree);
    };
}
