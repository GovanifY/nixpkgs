{ lib, stdenv }:

{ buildInputs ? []
, nativeBuildInputs ? []
, passthru ? {}
, preFixup ? ""
, shellHook ? ""

# needed for buildFlags{,Array} warning
, buildFlags ? ""
, buildFlagsArray ? ""

, meta ? {}, ... } @ args:


with builtins;

let
  package = stdenv.mkDerivation (


    nativeBuildInputs = [ p4c ] ++ nativeBuildInputs;
    buildInputs = buildInputs;

    configurePhase = args.configurePhase or ''
      runHook preConfigure

      runHook postConfigure
    '';

    buildPhase = args.buildPhase or ''
      runHook preBuild

      runHook renameImports

      runHook postBuild
    '';

    doCheck = args.doCheck or false;
    checkPhase = args.checkPhase or ''
      runHook preCheck
      
      TODO

      runHook postCheck
    '';

    installPhase = args.installPhase or ''
      runHook preInstall

      TODO

      runHook postInstall
    '';

    strictDeps = true;

    enableParallelBuilding = enableParallelBuilding;

    meta = {
      # TODO: add FPGA support here!
      platforms = lib.platforms.linux;
    } // meta;
  });
in
lib.warnIf (buildFlags != "" || buildFlagsArray != "")
  "Use the `ldflags` and/or `tags` attributes instead of `buildFlags`/`buildFlagsArray`"
  package
