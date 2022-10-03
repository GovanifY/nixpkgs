{ config, pkgs, lib, ... }:

with lib;

{
  options = {
    include = mkOption {
      type = types.listOf types.str;
      default = [ "core.p4" ];
      description = ''
        The list of files included in the program.
      '';
    };

    define = mkOption {
      default = [ ];
      description = ''
        The list of #define and their value to be interpreted by the
        preprocessor.
      '';
      type = types.listOf types.attrsOf (types.submodule {
        options = {
          name = mkOption { type = types.str; };
          value = mkOption { type = types.str; };
        };
      });
    };


    target = mkOption {
      type = types.enum [ "v1switch" "tbd" ];
      default = "v1switch";
      description = ''
        P4's deployment target. Defaults to the standard software swicth implementation.
      '';
    };

    # TODO: redefine using target.name and content for each stage
    call_stack = mkOption {
      type = types.listOf types.str;
      default = [ "" ];
      description = ''
        The functions that get executed by P4 in order.
      '';
    };

    headers = mkOption {
      description = ''
        Structures that should be put in as headers of the P4 program.
        Those are typically constants or immutable types.
      '';
      type = types.attrsOf (types.submodule {
        options = {
          typedef = mkOption {
            description = ''
              The list of typedefs of the program.
            '';
            type = types.listOf types.attrsOf (types.submodule {
              options = {
                type = mkOption { type = types.str; };
                name = mkOption { type = types.str; };
              };
            });
          };

          const = mkOption {
            description = ''
              The list of constants of the program.
            '';
            default = [];
            type = types.listOf types.attrsOf (types.submodule {
              options = {
                type = mkOption { type = types.str; };
                name = mkOption { type = types.str; };
                value = mkOption { type = types.str; };
              };
            });
          };

          struct = mkOption {
            description = ''
              The list of structures of the program.
            '';
            default = {};
            name = mkOption { type = types.str; };
            content.type = types.listOf types.attrsOf (types.submodule {
              options = {
                type = mkOption { type = types.str; };
                name = mkOption { type = types.str; };
              };
            });
          };

          header = mkOption {
            description = ''
              The list of headers of the program.
            '';
            default = { };
            name = mkOption { type = types.str; };
            union = mkOption { type = types.bool; default = false; };
            content = mkOption {
              type = types.listOf types.attrsOf (types.submodule {
                options = {
                  type = mkOption { type = types.str; };
                  name = mkOption { type = types.str; };
                };
              });
            };
          };

          enum = mkOption {
            description = ''
              The list of enums of the program.
            '';
            default = [];
            type = types.listOf types.attrsOf (types.submodule {
              options = {
                name = mkOption { type = types.str; };
                content = mkOption { type = types.listOf types.str; };
              };
            });
          };

          error = mkOption {
            type = types.listOf types.str;
            default = [ ];
            description = ''
              The list of error states of the program.
            '';
          };

          additional_headers = mkOption {
            type = types.str;
            default = "";
            description = ''
              P4 source code of additional headers required.
            '';
          };
        };
      });
    };

  };
}
