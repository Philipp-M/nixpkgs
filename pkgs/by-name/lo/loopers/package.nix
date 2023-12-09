{ lib
, rustPlatform
, clangStdenv
, fetchFromGitHub
, removeReferencesTo
, makeWrapper
, llvmPackages
, libjack2
, fontconfig
, xorg
, libglvnd
, libxkbcommon
, gn
, ninja
, fetchgit
, linkFarm
, runCommand
, python3
, pkg-config
, stdenv
, SDL2
, enableWayland ? stdenv.isLinux
, wayland
}:

rustPlatform.buildRustPackage.override { stdenv = clangStdenv; } rec {
  pname = "loopers";
  version = "unstable-2023-12-09";

  src = fetchFromGitHub {
    owner = "Philipp-M";
    repo = "loopers";
    rev = "78a63d4eeb5a9bcc815036480a19a76d030e1298";
    hash = "sha256-6ato8uBW8SnxhdPZItN2AOO2nLekhhKT/KNv1vpMAdE=";
  };

  cargoHash = "sha256-t6eY1wcEL4SulLkB7SN2L502yQg/mMJUNvFV6vNyygM=";

  nativeBuildInputs = [
    makeWrapper
    pkg-config
    python3 # skia
    removeReferencesTo
  ];
  buildInputs = [ libjack2 SDL2 python3 fontconfig ];

  SKIA_SOURCE_DIR =
    let
      repo = fetchFromGitHub {
        owner = "rust-skia";
        repo = "skia";
        # see rust-skia:skia-bindings/Cargo.toml#package.metadata skia
        rev = "m120-0.68.1";
        sha256 = "sha256-UtCHqKKuXGP699nm4kZN46Nhw+u3Wj1rQ9VUHiyUTlI=";
      };
      # The externals for skia are taken from skia/DEPS
      externals = linkFarm "skia-externals" (lib.mapAttrsToList
        (name: value: { inherit name; path = fetchgit value; })
        (lib.importJSON ./skia-externals.json));
    in
    runCommand "source" { } ''
      cp -R ${repo} $out
      chmod -R +w $out
      ln -s ${externals} $out/third_party/externals
    ''
  ;

  postFixup =
    let
      libPath = lib.makeLibraryPath ([
        libglvnd
        libxkbcommon
        xorg.libXcursor
        xorg.libXext
        xorg.libXrandr
        xorg.libXi
      ] ++ lib.optionals enableWayland [ wayland ]);
    in
    ''
      # library skia embeds the path to its sources
      remove-references-to -t "$SKIA_SOURCE_DIR" \
        $out/bin/loopers

      wrapProgram $out/bin/loopers \
        --prefix LD_LIBRARY_PATH : ${libPath}
    '';

  SKIA_GN_COMMAND = "${gn}/bin/gn";
  SKIA_NINJA_COMMAND = "${ninja}/bin/ninja";
  LIBCLANG_PATH = "${llvmPackages.libclang.lib}/lib";

  disallowedReferences = [ SKIA_SOURCE_DIR ];

  meta = with lib; {
    description = "Loopers is graphical live looper, written in Rust, designed for ease of use and rock-solid stability";
    homepage = "https://github.com/mwylde/loopers";
    license = [ licenses.mit licenses.asl20 ];
    maintainers = with maintainers; [ Philipp-M ];
    mainProgram = "loopers";
  };
}

