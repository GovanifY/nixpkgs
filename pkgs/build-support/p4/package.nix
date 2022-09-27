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

 { 
   include = [ "a.p4" ];
   headers = {
     typedef = [
#          v TODO: maybe make types either pure nix or strings? 
       { type = "bit<9>"; name = "egressSpec_t"; }
     ];
    };
  }






  # include = list of includes
  mkInclude = pkgs.lib.concatStringsSep "\n" (map (x: "#include <" + x + ">") include);

  # headers.typedef = attrset of type and name
  mkTypedef = pkgs.lib.concatStringsSep "\n"  (pkgs.lib.imap1 (i: v: "typedef "
  + v.type + " " + v.name + ";") headers.typedef);



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
