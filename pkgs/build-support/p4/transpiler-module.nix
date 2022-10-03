{ config, pkgs, lib, ... }:
#TODO: add documentation here on listof attrs, and why done this way!
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
      type = types.attrsOf types.str;
    };

    target = mkOption {
      type = types.enum [ "v1switch" "tbd" ];
      default = "v1switch";
      description = ''
        P4's deployment target. Defaults to the standard software swicth implementation.
      '';
    };

    logic = mkOption {
      type = types.listOf (types.attrsOf types.str);
      default = [ ];
      description = ''
        The functions that get executed by P4 in order.
      '';
    };

    headers = {
      typedef = mkOption {
        description = ''
          The list of typedefs of the program.
        '';
        type = types.attrsOf types.str;
        default = {};
      };

      const = mkOption {
        description = ''
          The list of constants of the program.
        '';
        default = { };
        type = types.attrsOf (types.attrsOf types.str);
      };

      struct = mkOption {
        description = ''
          The list of structures of the program.
        '';
        default = { };
        type = types.attrsOf (types.submodule {
          options = {
            content = mkOption {
              type = types.listOf (types.attrsOf types.str);
              default = [ ];
            };
          };
        });
      };

      header = mkOption {
        description = ''
          The list of headers of the program.
        '';
        default = { };
        type = types.attrsOf (types.submodule {
          options = {
            union = mkOption {
              type = types.bool;
              default = false;
            };
            content = mkOption {
              type = types.listOf (types.attrsOf types.str);
              default = [ ];
            };
          };
        });
      };

      enum = mkOption {
        description = ''
          The list of enums of the program.
        '';
        default = { };
        type = types.attrsOf (types.listOf types.str);
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
  };

}
