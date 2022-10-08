{ lib
, stdenv
, p4c
, writeTextFile }:

{ buildInputs ? []
, nativeBuildInputs ? []
, src
, name 

, meta ? {}, ... } @ args:


with builtins;

let
  source = writeTextFile {
    name = "default.p4";
    text = src;
  };

  package = stdenv.mkDerivation ({

    name = name;

    nativeBuildInputs = nativeBuildInputs;
    buildInputs = [ p4c ] ++ buildInputs;
    phases = [ "buildPhase" "installPhase" ];

    buildPhase = ''
      cp -a ${source} default.p4
      ${p4c}/bin/p4c --target bmv2 --arch v1model default.p4
    '';

    installPhase = ''
      mkdir -p $out/
      # TODO: json is the output given for bmv2, this should be changed
      # for other targets!
      cp -a default.json $out/
    '';

    meta = {
      # TODO: change depending on targets here! 
      platforms = lib.platforms.linux;
    } // meta;
  });
in
  package
