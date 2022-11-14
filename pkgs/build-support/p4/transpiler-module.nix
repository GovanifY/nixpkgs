{ config, pkgs, lib, ... }:
# The format of the P4 transpiler is as follows:
# * define
#     A list of define to be used by the preprocessor. As this can modify the
#     parsing logic of the rest of the file, this is in global scope and not
#     defined in, eg, headers.
#
# * include
#     A list of includes to be used by the program. As this can modify parsing
#     logic of the rest of the file, this is in global scope, same reasoning as
#     define.
#
# * headers
#     A list of headers set in global scope for this file. This contains either
#     constant values or set types that cannot be changed at runtime
#     specifically but cannot change the logic of the file, and as such are all
#     stored in their own small namespace.
#     You'll find in this attrset: const, header, typedef, enum, error, struct
#                                  additional_headers.
#     additional_headers is a string that can be used to add anything that isn't
#     currently supported. This is especially useful if you want to, eg, declare
#     variables or includes using preprocessing logic, of which this transpiler
#     is (mostly) not concerned by.
#     Please refer to the example belows for the format of the other attributes.
#
# * target
#     The target for which this P4 program should be built. This is an optional
#     field in case you want to create a derivation to be included in another
#     derivation without the need to build it to a specific target.
#
# * logic
#     This is a list of attrsets of strings. While P4_16 is a (very) simple
#     language, trying to format sequential logic in Nix is akin to painting
#     with a needle. It is possible, although very slow, tedious and needlessly
#     complicated. As such it was decided that the best course of action is to
#     have a list of attrsets in order to both keep a sequential logic order and
#     to allow for flexibility in the model.
#
#
#  Some attributes use a format such as a list of attributes. This is done in
#  order to keep the order of statements, which is incredibly important in
#  sequential structures like structs or headers. Attributes or list are
#  otherwise used depending on the most readable results for both. 
#  Helpers are defined in helpers.nix and may provide some help in writing P4
#  programs. Those can be inherited in your source attribute in order to create
#  a derivation, as seen in tests.nix.
with lib;

{
  options = {
    include = mkOption {
      type = types.listOf types.str;
      default = [ "core.p4" ];
      description = ''
        The list of files included in the program.
      '';
      example = [ "core.p4" "v1model.p4" ];
    };

    define = mkOption {
      default = { };
      description = ''
        The list of #define and their value to be interpreted by the
        preprocessor.
      '';
      type = types.attrsOf types.str;
      example = {
        "BLOOM_FILTER_ENTRIES" = "4096";
        "BLOOM_FILTER_BIT_WIDTH" = "1";
      };
    };

    target = mkOption {
      type = types.enum [ "v1switch" "ebpf" "psa" "null" ];
      default = "null";
      description = ''
        P4's deployment target. Defaults to the standard software swicth implementation.
      '';
      example = "v1switch";
    };

    logic = {
      main = mkOption {
        type = types.listOf (types.nullOr (types.attrsOf types.str));
        default = [ ];
        description = ''
          The functions that get executed by P4 in order.
        '';
        example = ''
          [ 
            { "MyParser" = '''
              parser MyParser(packet_in packet,
                              out headers hdr,
                              inout metadata meta,
                              inout standard_metadata_t standard_metadata) {

                  state start {
                      transition parse_ethernet;
                  }

                  state parse_ethernet {
                      packet.extract(hdr.ethernet);
                      transition select(hdr.ethernet.etherType) {
                          TYPE_IPV4: parse_ipv4;
                          default: accept;
                      }
                  }

                  state parse_ipv4 {
                      packet.extract(hdr.ipv4);
                      transition select(hdr.ipv4.protocol){
                          TYPE_TCP: tcp;
                          default: accept;
                      }
                  }

                  state tcp {
                     packet.extract(hdr.tcp);
                     transition accept;
                  }
              }
            ''';
            }
          ];
        '';
      };
      sub = mkOption {
        type = types.attrsOf (types.submodule {
          options = {
            name = mkOption {
              type = types.str;
              description = ''
                The name that will be used in your P4 program to refer to this
                logic pipeline.
              '';
            };
            content = mkOption {
              type = types.listOf (types.attrsOf types.str);
              description = ''
                The content of the functions used by your logic pipeline. See
                logic.main for examples.
              '';
            };
          };
        });
      };
    };

    headers = {
      typedef = mkOption {
        description = ''
          The list of typedefs of the program.
        '';
        type = types.attrsOf types.str;
        default = { };
        example = {
          "macAddr" = "bit<48>";

          "ip4Addr" = "bit<32>";

          "ip6Addr" = "bit<128>";
        };
      };

      const = mkOption {
        description = ''
          The list of constants of the program.
        '';
        default = { };
        type = types.attrsOf (types.attrsOf types.str);
        example = {
          "TYPE_IPV4" = {
            type = "bit<16>";
            value = "0x800";
          };

          "TYPE_TCP" = {
            type = "bit<8>";
            value = "6";
          };
        };
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
        example = {
          "ethernet_h".content = [
            { "dstAddr" = "macAddr"; }
            { "srcAddr" = "macAddr"; }
            { "etherType" = "bit<16>"; }
          ];
        };
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
        example = {
          "IP_h" = {
            union = true;
            content = [ { "IPv4_h" = "v4"; } { "IPv6_h" = "v6"; } ];
          };
        };
      };

      enum = mkOption {
        description = ''
          The list of enums of the program.
        '';
        default = { };
        type = types.attrsOf (types.listOf types.str);
        example = { "CloneType" = [ "I2E" "E2I" ]; };
      };

      error = mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = ''
          The list of error states of the program.
        '';
        example = [ "error1" "error2" ];
      };

      additional_headers = mkOption {
        type = types.str;
        default = "";
        description = ''
          P4 source code of additional headers required.
        '';
        example = ''
          #if MY_FANCY_OPTION
            const bit<16> KEY = 0x725;
          #endif
        '';
      };
    };
  };

}
