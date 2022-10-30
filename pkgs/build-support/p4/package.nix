{ lib
, stdenv
, p4c
, writeTextFile }:

{ buildInputs ? []
, nativeBuildInputs ? []
, p4Target ? ""
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
    '' + (if p4Target == "bmv2-psa" then
        "${p4c}/bin/p4c --target bmv2 --arch psa default.p4"
      else if p4Target == "bmv2-v1model" then
        "${p4c}/bin/p4c --target bmv2 --arch v1model default.p4"
      else if p4Target == "ebpf-v1model" then
        "${p4c}/bin/p4c --target ebpf --arch v1model default.p4"
      else if p4Target == "dpdk-psa" then
        "${p4c}/bin/p4c --target dpdk --arch psa default.p4"
      else abort "Unrecognized P4 Target tuple: ${p4Target}");

    installPhase = ''
      mkdir -p $out/
      cp -a * $out/
      rm -rf $out/*.p4 $out/*.p4i $out/env-vars
    '';

    meta = {
      # TODO: change depending on targets here! 
      platforms = lib.platforms.linux;
    } // meta;
  });
in
  package
