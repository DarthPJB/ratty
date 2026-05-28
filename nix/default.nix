# Standalone package definition for ratty.
# Designed to be upstreamed to nixpkgs as pkgs/by-name/ra/ratty/package.nix.
# Takes only standard nixpkgs arguments — no flake-specific constructs.
{
  lib,
  stdenv,
  rustPlatform,
  pkg-config,
  alsa-lib,
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
  writeShellScript,
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

  # Wrapper that ensures a working shell on NixOS.
  # ratty resolves shell as: config.shell.program → $SHELL → /bin/bash.
  # A config/ratty.toml in CWD (e.g. the upstream repo) may hardcode
  # program = "/bin/bash" which does not exist on NixOS.  When no
  # -e/--command flag is given the wrapper injects -e "$SHELL", bypassing
  # the config entirely.
  rattyWrapper = writeShellScript "ratty" ''
    export SHELL='${bash}/bin/bash'
    export LD_LIBRARY_PATH='${runtimeLibraryPath}'"''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
    ${lib.optionalString stdenv.isDarwin ''
      export DYLD_LIBRARY_PATH='${runtimeLibraryPath}'"''${DYLD_LIBRARY_PATH:+:$DYLD_LIBRARY_PATH}"
      export DYLD_FALLBACK_LIBRARY_PATH='${runtimeLibraryPath}'"''${DYLD_FALLBACK_LIBRARY_PATH:+:$DYLD_FALLBACK_LIBRARY_PATH}"
    ''}
    for _arg in "$@"; do
      if [ "$_arg" = "-e" ] || [ "$_arg" = "--command" ]; then
        exec @out@/bin/.ratty-unwrapped "$@"
      fi
    done
    exec @out@/bin/.ratty-unwrapped -e "$SHELL" "$@"
  '';
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
      alsa-lib
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

    # Install wrapper script
    mv $out/bin/ratty $out/bin/.ratty-unwrapped
    install -Dm755 ${rattyWrapper} $out/bin/ratty
    substituteInPlace $out/bin/ratty --subst-var-by out $out
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
