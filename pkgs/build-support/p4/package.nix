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
     const = [
       { type = "bit<16>"; name = "TYPE_IPV4"; value = "0x800";}
     ];

     struct = [
       { name = "headers" ;
         content = [ 
           {
             type = "ethernet_t"; 
             name = "ethernet";
           }
         ];
       }
     ];

    header = [
       { name = "headers" ;
         content = [ 
           {
             type = "ethernet_t"; 
             name = "ethernet";
           }
         ];
       }
     ];


    };
  }






  # include = list of includes
  mkInclude = pkgs.lib.concatStringsSep "\n" (map (x: "#include <" + x + ">") include);

  # headers.typedef = attrset of type and name
  mkTypedef = pkgs.lib.concatStringsSep "\n"  (pkgs.lib.imap1 (i: v: "typedef "
  + v.type + " " + v.name + ";") headers.typedef);

  # headers.const = attrset of type, name and value
  mkConst = pkgs.lib.concatStringsSep "\n"  (pkgs.lib.imap1 (i: v: "const "
  + v.type + " " + v.name + " = " + v.value + ";") headers.const);

  # headers.struct = attrset of name and content 
  mkStruct = pkgs.lib.concatStringsSep "\n" (pkgs.lib.imap1 (i: v: "struct " +
  v.name + " {\n" + (pkgs.lib.concatStringsSep "\n" (pkgs.lib.imap1 (i: v: "
  " + v.type + "    " + v.name + ";") v.content) ) + "\n}") headers.struct);

  # headers.header = attrset of name and content 
  # same as struct but limited to bitfield and int
  # TODO: maybe ensure in nix that this constraint is satisfied?
  mkHeader = pkgs.lib.concatStringsSep "\n" (pkgs.lib.imap1 (i: v: "header " +
  v.name + " {\n" + (pkgs.lib.concatStringsSep "\n" (pkgs.lib.imap1 (i: v: "
  " + v.type + "    " + v.name + ";") v.content) ) + "\n}") headers.header);



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
