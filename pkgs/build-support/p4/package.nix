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

  p4Source = types.submodule {
    options = {
      include = {
        type = types.listOf types.str;
        default = [ "core.p4" ];
        description = ''
          The list of files included in the program.
        '';
      };

      headers = mkOption {
        description = ''
          Structures that should be put in as headers of the P4 program.
          Those are typically constants or immutable types.
        '';
        type = types.attrsOf (
          types.submodule {
            options = {

              typedef = {
                description = ''
                  The list of typedefs of the program.
                '';
                type = types.listOf types.attrsOf (
                  types.submodule {
                    options = {
                      type.type = types.str;
                      name.type = types.str;
                    };
              };

              const = {
                description = ''
                  The list of constants of the program.
                '';
                type = types.listOf types.attrsOf (
                  types.submodule {
                    options = {
                      type.type = types.str;
                      name.type = types.str;
                      value.type = types.str;
                    };
              };

              struct = {
                description = ''
                  The list of structures of the program.
                '';
                name.type = types.str;
                content.type = types.listOf types.attrsOf (
                   types.submodule {
                     options = {
                       type.type = types.str;
                       name.type = types.str;
                     };
              };

              header = {
                description = ''
                  The list of headers of the program.
                '';
                name.type = types.str;
                union.type = types.bool;
                content.type = types.listOf types.attrsOf (
                   types.submodule {
                     options = {
                       type.type = types.str;
                       name.type = types.str;
                     };
              };

              enum = {
                description = ''
                  The list of enums of the program.
                '';
                type = types.listOf types.attrsOf (
                  types.submodule {
                    options = {
                      name.type = types.str;
                      content.type = types.listOf types.str;
                    };
              };


              error = {
                type = types.listOf types.str;
                default = [ "" ];
                description = ''
                  The list of error states of the program.
                '';
              };
            };
          };
          );
      };

      target = {
        type = types.enum [ "v1switch" "tbd" ];
        default = "v1switch";
        description = ''
          P4's deployment target. Defaults to the standard software swicth implementation.
        '';
      };
    };
  };




  # include = list of includes
  mkInclude = include: pkgs.lib.concatStringsSep "\n" (map (x: "#include <" + x + ">") include);

  # headers.typedef = attrset of type and name
  mkTypedef = typedef: pkgs.lib.concatStringsSep "\n"  (pkgs.lib.imap1 (i: v: "typedef "
  + v.type + " " + v.name + ";") typedef);

  # headers.const = attrset of type, name and value
  mkConst = const: pkgs.lib.concatStringsSep "\n"  (pkgs.lib.imap1 (i: v: "const "
  + v.type + " " + v.name + " = " + v.value + ";") const);

  # headers.struct = attrset of name and content 
  mkStruct = struct: pkgs.lib.concatStringsSep "\n" (pkgs.lib.imap1 (i: v: "struct " +
  v.name + " {\n" + (pkgs.lib.concatStringsSep "\n" (pkgs.lib.imap1 (i: v: "
  " + v.type + "    " + v.name + ";") v.content) ) + "\n}") struct);

  # headers.header = attrset of name and content 
  # same as struct but limited to bitfield and int
  # TODO: maybe ensure in nix that this constraint is satisfied?
  # TODO: add union support to mkHeader
  mkHeader = header: pkgs.lib.concatStringsSep "\n" (pkgs.lib.imap1 (i: v: "header " +
  v.name + " {\n" + (pkgs.lib.concatStringsSep "\n" (pkgs.lib.imap1 (i: v: "
  " + v.type + "    " + v.name + ";") v.content) ) + "\n}") header);

  # headers.enum = attrset of name and content 
  mkEnum = enum: pkgs.lib.concatStringsSep "\n"  (pkgs.lib.imap1 (i: v: "enum " +
  v.name + " { " + (pkgs.lib.concatStringsSep ", " v.content) + " };") enum);

  # headers.error = list of possible errors
  mkError = error: "error { " + (pkgs.lib.concatStringsSep ", " error) + " };";



  # TODO: check for attrset sanity
  mkHeaders = headers: ''
    /* This file has been auto-generated by Nix, do not edit it manually! */
    '' + mkInclude headers.include "\n\n" + mkConst headers.const + "\n\n" + 
    mkTypedef headers.typedef + "\n\n" + mkHeader headers.header + "\n\n" +
    mkStruct headers.struct + "\n\n" + mkEnum headers.enum + "\n\n" + mkError headers.error;

  # TODO: add v1switch and other targets there!
  #mkArch =  then 

  package = stdenv.mkDerivation (

    includes = headers.include ++ optionals (target.name == "v1switch") [ "v1model.p4" ];

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
