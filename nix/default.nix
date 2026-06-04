# Standalone package definition for ratty.
# Designed to be upstreamed to nixpkgs as pkgs/by-name/ra/ratty/package.nix.
# Takes only standard nixpkgs arguments — no flake-specific constructs.
{
  lib,
  stdenv,
  rustPlatform,
  pkg-config,
  fontconfig,
  udev,
  wayland,
  libxkbcommon,
  libxcb,
  libx11,
  libxcursor,
  libxi,
  libxrandr,
  libxext,
  vulkan-loader,
  mesa,
  bash,
  makeWrapper,
  copyDesktopItems,
  makeDesktopItem,
  # Darwin frameworks — passed via callPackage override from flake
  darwinFrameworks ? [ ],
}:

let
  runtimeLibraryPath = lib.makeLibraryPath (
    lib.optionals stdenv.isLinux [
      vulkan-loader
      mesa
      fontconfig
      libxkbcommon
      libx11
      libxcb
      libxcursor
      libxi
      libxrandr
      libxext
    ]
  );

in
rustPlatform.buildRustPackage rec {
  pname = "ratty";
  version = "0.3.0";

  src = ../.;

  cargoLock.lockFile = ../Cargo.lock;

  nativeBuildInputs = [
    pkg-config
    makeWrapper
    copyDesktopItems
  ];

  desktopItems = [
    (makeDesktopItem {
      name = "ratty";
      desktopName = "Ratty";
      comment = "A GPU-rendered terminal emulator with inline 3D graphics";
      exec = "ratty";
      terminal = false;
      categories = [
        "System"
        "TerminalEmulator"
        "Utility"
      ];
      icon = "ratty";
    })
  ];

  buildInputs =
    lib.optionals stdenv.isLinux [
      fontconfig
      udev
      wayland
      libxkbcommon
      libxcb
      libx11
      libxcursor
      libxi
      libxrandr
      libxext
      vulkan-loader
      mesa
    ]
    ++ darwinFrameworks;

  # Assets are embedded at compile time via rust-embed.
  # Copy them to $out/share for reference and custom model discovery fallback.
  postInstall = ''
    mkdir -p $out/share/ratty
    cp -r assets/objects $out/share/ratty/
    install -Dm644 config/ratty.toml $out/share/ratty/ratty.toml
    install -Dm644 website/assets/images/ratty-logo.png \
      $out/share/icons/hicolor/512x512/apps/ratty.png

    # Use wrapProgram for env var management (idiomatic nixpkgs).
    # Handles SHELL, LD_LIBRARY_PATH, and Darwin DYLD_* paths.
    wrapProgram $out/bin/ratty \
      --set SHELL '${bash}/bin/bash' \
      --prefix LD_LIBRARY_PATH : '${runtimeLibraryPath}' \
      ${lib.optionalString stdenv.isDarwin ''
        --prefix DYLD_LIBRARY_PATH : '${runtimeLibraryPath}' \
        --prefix DYLD_FALLBACK_LIBRARY_PATH : '${runtimeLibraryPath}' \
      ''}

    # Thin wrapper for conditional -e "$SHELL" injection.
    # ratty resolves shell as: config.shell.program → $SHELL → /bin/bash.
    # A config/ratty.toml in CWD may hardcode "/bin/bash" which does not
    # exist on NixOS.  When no -e/--command flag is given, inject
    # -e "$SHELL" to bypass any stale CWD config.
    # NOTE: cannot use --add-flags unconditionally because clap's
    # num_args=1.. would treat a second -e as a command argument.
    mv $out/bin/ratty $out/bin/.ratty-env-wrapped
    makeWrapper $out/bin/.ratty-env-wrapped $out/bin/ratty \
      --run '''
        for _arg in "$@"; do
          if [ "$_arg" = "-e" ] || [ "$_arg" = "--command" ]; then
            exec ${placeholder "out"}/bin/.ratty-env-wrapped "$@"
          fi
        done
        exec ${placeholder "out"}/bin/.ratty-env-wrapped -e "${bash}/bin/bash" "$@"
      '''
  '';

  meta = {
    description = "GPU-rendered terminal emulator with inline 3D graphics";
    homepage = "https://github.com/orhun/ratty";
    license = lib.licenses.mit;
    maintainers = [ "daniejbolt" ];
    mainProgram = "ratty";
    platforms = lib.platforms.unix;
  };
}
