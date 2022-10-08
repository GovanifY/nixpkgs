{ lib, stdenv }:

{ buildInputs ? []
, nativeBuildInputs ? []
, src ? {},

, meta ? {}, ... } @ args:


with builtins;

let
  package = stdenv.mkDerivation (

    src = src;

    nativeBuildInputs = [ p4c ] ++ nativeBuildInputs;
    buildInputs = buildInputs;
    phases = [ "buildPhase" "installPhase" ];

    buildPhase = ''
      ${pkgs.p4c}/bin/p4c --target bmv2 --arch v1model *.p4
    '';

    installPhase = ''

      mkdir -p $out/
      # TODO: json is the output given for bmv2, this should be changed
      # for other targets!
      cp -a *.json $out/
    '';

    meta = {
      # TODO: change depending on targets here! 
      platforms = lib.platforms.linux;
    } // meta;
  });
in
  package
