{
  lib,
  stdenv,
  # Upstream source and version; the flake passes its locked
  # hypr-kdeconnect-fix-src input.
  src,
  version,
  cmake,
  pkg-config,
  wayland-scanner,
  qt6,
  wayland,
  libxkbcommon,
  libei,
  # XDG_CURRENT_DESKTOP values the .portal file advertises itself for (its
  # UseIn= key); null keeps upstream's list (wlroots, Hyprland, sway, Wayfire,
  # river, phosh, niri, labwc).
  portalUseIn ? null,
}:

stdenv.mkDerivation {
  pname = "hypr-kdeconnect-fix";
  inherit src version;

  nativeBuildInputs = [
    cmake
    pkg-config
    wayland-scanner
    qt6.wrapQtAppsHook
  ];

  buildInputs = [
    qt6.qtbase
    wayland
    libxkbcommon
    libei
  ];

  cmakeFlags = lib.optional (portalUseIn != null) (
    lib.cmakeFeature "HKCF_PORTAL_USE_IN" (lib.concatStringsSep ";" portalUseIn)
  );

  doCheck = true;

  # Upstream installs the user unit to share/systemd/user, which systemd finds
  # through XDG_DATA_DIRS (e.g. `nix profile install`). NixOS's systemd.packages
  # only reads lib/systemd/user; without this the D-Bus service's
  # SystemdService= points at a unit the user manager doesn't know. Already the
  # layout stdenv's moveSystemdUserUnits hook produces, which would trip on it.
  postInstall = ''
    mkdir -p $out/lib/systemd
    ln -s ../../share/systemd/user $out/lib/systemd/user
  '';
  dontMoveSystemdUserUnits = true;

  meta = {
    description = "xdg-desktop-portal RemoteDesktop backend for KDE Connect remote input on Hyprland and other wlroots compositors";
    homepage = "https://github.com/gfhdhytghd/hypr-kdeconnect-fix";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
    mainProgram = "hypr-kdeconnect-portal";
  };
}
