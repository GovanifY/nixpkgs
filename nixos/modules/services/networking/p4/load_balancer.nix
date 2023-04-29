# bla

{ config, lib, pkgs, ... }:

with lib;
let
  # TODO: we cannot use helpers in modules because we create an infinite
  # recursion in options, maybe set them up in modules? Otherwise users still
  # have access to them so is it really an issue... 
  cfg = config.services.networking.p4.load-balancer;

  balancer_source = {

    # core is included by default anv v1model will be if the target is correctly
    # set but as the target logic isn't stabilized yet i'm including it manually
    include = [ "core.p4" "v1model.p4" ];

    headers = {
      header = {
        "ethernet_h".content = [
          { "dstAddr" = "macAddr"; }
          { "srcAddr" = "macAddr"; }
          { "etherType" = "bit<16>"; }
        ];

        "ipv4_no_options_h".content = [
          { "version" = "bit<4>"; }
          { "ihl" = "bit<4>"; }
          { "diffserv" = "bit<8>"; }
          { "totalLen" = "bit<16>"; }
          { "identification" = "bit<16>"; }
          { "flags" = "bit<3>"; }
          { "fragOffset" = "bit<13>"; }
          { "ttl" = "bit<8>"; }
          { "protocol" = "bit<8>"; }
          { "hdrChecksum" = "bit<16>"; }
          { "srcAddr" = "ip4Addr"; }
          { "dstAddr" = "ip4Addr"; }
        ];

        "tcp_no_options_h".content = [
          { "srcPort" = "bit<16>"; }
          { "dstPort" = "bit<16>"; }
          { "seqNo" = "bit<32>"; }
          { "ackNo" = "bit<32>"; }
          { "dataOffset" = "bit<4>"; }
          { "res" = "bit<4>"; }
          { "cwr" = "bit<1>"; }
          { "ece" = "bit<1>"; }
          { "urg" = "bit<1>"; }
          { "ack" = "bit<1>"; }
          { "psh" = "bit<1>"; }
          { "rst" = "bit<1>"; }
          { "syn" = "bit<1>"; }
          { "fin" = "bit<1>"; }
          { "window" = "bit<16>"; }
          { "checksum" = "bit<16>"; }
          { "urgentPtr" = "bit<16>"; }
        ];

        "type_t".content = [{ "tag" = "bit<8>"; }];
        "hop_t".content = [ { "port" = "bit<8>"; } { "bos" = "bit<8>"; } ];
        "standard_t".content = [ { "src" = "bit<8>"; } { "dst" = "bit<8>"; } ];

      };

      const = {
        "MAX_HOPS" = {
          type = "int";
          value = "10";
        };
        "STANDARD" = {
          type = "int";
          value = "0";
        };
        "HOPS" = {
          type = "int";
          value = "1";
        };
      };

      struct = {
        "metadata".content = [{ "ecmp_select" = "bit<14>"; }];
        "headers".content = [
          { "ethernet" = "ethernet_h"; }
          { "ipv4" = "ipv4_no_options_h"; }
          { "tcp" = "tcp_no_options_h"; }
        ];
      };
      typedef = {
        "macAddr" = "bit<48>";
        "ip4Addr" = "bit<32>";
        "std_meta_t" = "standard_metadata_t";
      };
    };
    target = "v1switch";
    logic.main = [
      {
        "MyParser" = ''
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
                    0x800: parse_ipv4;
                    default: accept;
                }
            }
            state parse_ipv4 {
                packet.extract(hdr.ipv4);
                transition select(hdr.ipv4.protocol) {
                    6: parse_tcp;
                    default: accept;
                }
            }
            state parse_tcp {
                packet.extract(hdr.tcp);
                transition accept;
            }
          }
        '';
      }
      {
        "MyVerifyChecksum" = ''
          control MyVerifyChecksum(inout headers hdr, inout metadata meta) {
              apply { }
          }
        '';
      }

      {
        "MyIngress" = ''
          control MyIngress(inout headers hdr,
                            inout metadata meta,
                            inout standard_metadata_t standard_metadata) {
              action drop() {
                  mark_to_drop(standard_metadata);
              }
              action set_ecmp_select(bit<16> ecmp_base, bit<32> ecmp_count) {
                  hash(meta.ecmp_select,
                      HashAlgorithm.crc16,
                      ecmp_base,
                      { hdr.ipv4.srcAddr,
                        hdr.ipv4.dstAddr,
                        hdr.ipv4.protocol,
                        hdr.tcp.srcPort,
                        hdr.tcp.dstPort },
                      ecmp_count);
              }
              action set_nhop(bit<48> nhop_dmac, bit<32> nhop_ipv4, bit<9> port) {
                  hdr.ethernet.dstAddr = nhop_dmac;
                  hdr.ipv4.dstAddr = nhop_ipv4;
                  standard_metadata.egress_spec = port;
                  hdr.ipv4.ttl = hdr.ipv4.ttl - 1;
              }
              table ecmp_group {
                  key = {
                      hdr.ipv4.dstAddr: lpm;
                  }
                  actions = {
                      drop;
                      set_ecmp_select;
                  }
                  size = 1024;
              }
              table ecmp_nhop {
                  key = {
                      meta.ecmp_select: exact;
                  }
                  actions = {
                      drop;
                      set_nhop;
                  }
                  size = 2;
              }
              apply {
                  if (hdr.ipv4.isValid() && hdr.ipv4.ttl > 0) {
                      ecmp_group.apply();
                      ecmp_nhop.apply();
                  }
              }
          }
        '';
      }
      {
        "MyEgress" = ''
          control MyEgress(inout headers hdr,
                           inout metadata meta,
                           inout standard_metadata_t standard_metadata) {

              action rewrite_mac(bit<48> smac) {
                  hdr.ethernet.srcAddr = smac;
              }
              action drop() {
                  mark_to_drop(standard_metadata);
              }
              table send_frame {
                  key = {
                      standard_metadata.egress_port: exact;
                  }
                  actions = {
                      rewrite_mac;
                      drop;
                  }
                  size = 256;
              }
              apply {
                  send_frame.apply();
              }
          }
        '';
      }
      {
        "MyComputeChecksum" = ''
          control MyComputeChecksum(inout headers hdr, inout metadata meta) {
               apply {
                  update_checksum(
                      hdr.ipv4.isValid(),
                      { hdr.ipv4.version,
                        hdr.ipv4.ihl,
                        hdr.ipv4.diffserv,
                        hdr.ipv4.totalLen,
                        hdr.ipv4.identification,
                        hdr.ipv4.flags,
                        hdr.ipv4.fragOffset,
                        hdr.ipv4.ttl,
                        hdr.ipv4.protocol,
                        hdr.ipv4.srcAddr,
                        hdr.ipv4.dstAddr },
                      hdr.ipv4.hdrChecksum,
                      HashAlgorithm.csum16);
              }
          }
        '';
      }
      {
        "MyDeparser" = ''
          control MyDeparser(packet_out packet, in headers hdr) {
              apply {
                  packet.emit(hdr.ethernet);
                  packet.emit(hdr.ipv4);
                  packet.emit(hdr.tcp);
              }
          }
        '';
      }

    ];

  };

in {

  options = {

    services.networking.p4.load-balancer = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = ''
          Whether to enable a P4 load balancer.
          This is a load balancer example using BMV2 as a target. 
          It is based on https://github.com/p4lang/tutorials for
          simplicity's sake. 
          This load balancer uses P4Runtime in order to modify the control plane
          as to be able to modify its state during runtime. Its
          topology is available here:
          https://github.com/p4lang/tutorials/tree/master/exercises/load_balance
          .
        '';
      };
      source = mkOption {
        default = balancer_source;
        type = types.attrsOf types.anything;
        description = ''
          The p4 program sent to the transpiler.
          Please refer to build-support/p4 for its format.
        '';
      };
    };

  };

  config = mkIf cfg.enable {
    systemd.services.load-balancer = let
      p4Program = pkgs.p4Platform.mkProgram {
        name = "load-balancer-example";
        src = (pkgs.p4Platform.runTranspiler { p4Source = cfg.source; });
        p4Target = "bmv2-v1model";
      };
    in {
      wantedBy = [ "default.target" ];
      after = [ "network.target" ];
      serviceConfig = {
        Type = "simple";
        ExecStart = "${pkgs.bmv2}/bin/simple_switch ${p4Program}/out.json";
      };
    };
  };

  meta.maintainers = with lib.maintainers; [ govanify ];

}
