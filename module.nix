# Applied by the flake (lib.modules.importApply) with the function that builds
# the package for a given pkgs.
{ packageFor }:
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.hypr-kdeconnect-fix;
  portalCfg = config.xdg.portal.config;
in
{
  options.services.hypr-kdeconnect-fix = {
    enable = lib.mkEnableOption "the hypr-kdeconnect-fix RemoteDesktop portal backend for KDE Connect";

    package = lib.mkOption {
      type = lib.types.package;
      default = packageFor pkgs;
      defaultText = lib.literalMD "built from the flake's locked upstream source with the system's `pkgs`";
      description = "The hypr-kdeconnect-fix package, built against the system's nixpkgs by default.";
    };

    desktops = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "hyprland" ];
      example = [
        "hyprland"
        "niri"
      ];
      description = ''
        Desktops (lowercased `XDG_CURRENT_DESKTOP`) whose RemoteDesktop portal
        interface is routed to this backend, via
        `xdg.portal.config.<desktop>`. Set to `[ ]` to manage the routing yourself.

        This generates {file}`/etc/xdg/xdg-desktop-portal/<desktop>-portals.conf`,
        which takes precedence over the compositor's packaged one (Hyprland's
        sets `default=hyprland;gtk`), so also set
        `xdg.portal.config.<desktop>.default`.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    xdg.portal = {
      enable = true;
      extraPortals = [ cfg.package ];
      config = lib.genAttrs cfg.desktops (_: {
        "org.freedesktop.impl.portal.RemoteDesktop" = [ "hypr-kdeconnect" ];
      });
    };

    warnings = map (desktop: ''
      services.hypr-kdeconnect-fix routes RemoteDesktop through
      xdg.portal.config.${desktop}, which replaces the compositor's packaged
      ${desktop}-portals.conf, but xdg.portal.config.${desktop}.default is unset,
      so every other portal interface is left without a backend. Set it, e.g.
      xdg.portal.config.${desktop}.default = [ "${desktop}" "gtk" ];
    '') (lib.filter (desktop: !(portalCfg.${desktop} ? default)) cfg.desktops);
  };
}
