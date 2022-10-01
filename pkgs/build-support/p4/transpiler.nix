{ lib, stdenv }:

{ p4Source, ... } @ args:


with builtins;

let

  # This is the set representing the possible targets (eg top-level packages)
  # that can be automatically deployed using nix. This is a purely nix->P4
  # syntax mapper.
  targets_mapping = { v1switch="V1Switch"; };

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
              };


              error = {
                type = types.listOf types.str;
                default = [ "" ];
                description = ''
                  The list of error states of the program.
                '';
              };

             additional_headers = {
                type = types.str;
                default = "";
                description = ''
                  P4 source code of additional headers required.
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

      call_stack = {
        type = types.listOf types.str;
        default = [ "" ];
        description = ''
          The functions that get executed by P4 in order.
        '';
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
  mkHeader = header: pkgs.lib.concatStringsSep "\n" (pkgs.lib.imap1 (i: v: (if
  (header.union) then "header_union " else "header ") +
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
    mkStruct headers.struct + "\n\n" + mkEnum headers.enum + "\n\n" + mkError
    headers.error + "\n\n" + headers.additional_headers;

  # TODO: add v1switch and other targets there!
  #mkTarget =  then

  mkCallStack = call_stack: pkgs.lib.removeSuffix ",\n" (pkgs.lib.concatStringsSep "(),\n" call_stack);

  # XXX: I am assuming that if you want to setup a target you want it to be the
  # main logic, does this assumption always holds true?
  mkTarget = p4Source: targets_mapping.${p4Source.target} + "(\n" + (mkCallStack
  p4Source.call_stack) + "\n) main;";
in
  # something like this
  includes = headers.include ++ optionals (target.name == "v1switch") [ "v1model.p4" ];
  toFile mkSource 
