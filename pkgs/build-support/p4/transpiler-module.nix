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
      example = [ "core.p4" "v1model.p4" ];
    };

    define = mkOption {
      default = [ ];
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
      type = types.enum [ "v1switch" "tbd" ];
      default = "v1switch";
      description = ''
        P4's deployment target. Defaults to the standard software swicth implementation.
      '';
      example = "v1switch";
    };

    logic = mkOption {
      type = types.listOf (types.attrsOf types.str);
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

    headers = {
      typedef = mkOption {
        description = ''
          The list of typedefs of the program.
        '';
        type = types.attrsOf types.str;
        default = {};
        example ={
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
            content = [
              { "IPv4_h" = "v4"; }
              { "IPv6_h" = "v6"; }
            ];
          };
        };
      };

      enum = mkOption {
        description = ''
          The list of enums of the program.
        '';
        default = { };
        type = types.attrsOf (types.listOf types.str);
        example = {
          "CloneType" = [ "I2E" "E2I" ];
        };
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
