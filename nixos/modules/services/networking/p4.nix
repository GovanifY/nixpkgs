# bla

{ config, lib, pkgs, ... }:

with lib;
let
  balancer_source = {

    # core is included by default anv v1model will be if the target is correctly
    # set but as the target logic isn't stabilized yet i'm including it manually
    include = [ "core.p4" "v1model.p4" ];

    headers = {
      header = { inherit ethernet_h ipv4_no_options_h tcp_no_options_h; };

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

      header = {
        "type_t".content = [{ "tag" = "bit<8>"; }];
        "hop_t".content = [ { "port" = "bit<8>"; } { "bos" = "bit<8>"; } ];
        "standard_t".content = [ { "src" = "bit<8>"; } { "dst" = "bit<8>"; } ];
      };

      struct = {
        "metadata".content = [{ "ecmp_select" = "bit<14>"; }];
        "headers".content = [
          { "ethernet" = "ethernet_h"; }
          { "ipv4" = "ipv4_no_options_h"; }
          { "tcp" = "tcp_no_options_h"; }
        ];
      };
      typedef = { "std_meta_t" = "standard_metadata_t"; };
    };
    target = "v1model";
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

  firewall_source = {
    include = [ "core.p4" "v1model.p4" ];
    headers = {
      const = {
        inherit ETH_TYPE_IPV4;
        "TYPE_TCP" = {
          type = "bit<8>";
          value = "6";
        };
      };
      define = {
        "BLOOM_FILTER_ENTRIES" = "4096";
        "BLOOM_FILTER_BIT_WIDTH" = "1";
      };
      typedef = {
        "egressSpec_t" = "bit<9>";
        "macAddr_t" = "bit<48>";
        "ip4Addr_t" = "bit<32>";
      };

      header = { inherit ethernet_h ipv4_no_options_h tcp_no_options_h; };
      struct = {
        "metadata".content = [ ];
        "headers".content = [
          { "ethernet" = "ethernet_h"; }
          { "ipv4" = "ipv4_no_options_h"; }
          { "tcp" = "tcp_no_options_h"; }
        ];
      };

    };
    target = "v1model";
    logic.main = {
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
      '';
      "MyVerifyChecksum" = ''
        control MyVerifyChecksum(inout headers hdr, inout metadata meta) {
            apply {  }
        }
      '';
      "MyIngress" = ''
        control MyIngress(inout headers hdr,
                          inout metadata meta,
                          inout standard_metadata_t standard_metadata) {

            register<bit<BLOOM_FILTER_BIT_WIDTH>>(BLOOM_FILTER_ENTRIES) bloom_filter_1;
            register<bit<BLOOM_FILTER_BIT_WIDTH>>(BLOOM_FILTER_ENTRIES) bloom_filter_2;
            bit<32> reg_pos_one; bit<32> reg_pos_two;
            bit<1> reg_val_one; bit<1> reg_val_two;
            bit<1> direction;

            action drop() {
                mark_to_drop(standard_metadata);
            }

            action compute_hashes(ip4Addr_t ipAddr1, ip4Addr_t ipAddr2, bit<16> port1, bit<16> port2){
               //Get register position
               hash(reg_pos_one, HashAlgorithm.crc16, (bit<32>)0, {ipAddr1,
                                                                   ipAddr2,
                                                                   port1,
                                                                   port2,
                                                                   hdr.ipv4.protocol},
                                                                   (bit<32>)BLOOM_FILTER_ENTRIES);

               hash(reg_pos_two, HashAlgorithm.crc32, (bit<32>)0, {ipAddr1,
                                                                   ipAddr2,
                                                                   port1,
                                                                   port2,
                                                                   hdr.ipv4.protocol},
                                                                   (bit<32>)BLOOM_FILTER_ENTRIES);
            }

            action ipv4_forward(macAddr_t dstAddr, egressSpec_t port) {
                standard_metadata.egress_spec = port;
                hdr.ethernet.srcAddr = hdr.ethernet.dstAddr;
                hdr.ethernet.dstAddr = dstAddr;
                hdr.ipv4.ttl = hdr.ipv4.ttl - 1;
            }

            table ipv4_lpm {
                key = {
                    hdr.ipv4.dstAddr: lpm;
                }
                actions = {
                    ipv4_forward;
                    drop;
                    NoAction;
                }
                size = 1024;
                default_action = drop();
            }

            action set_direction(bit<1> dir) {
                direction = dir;
            }

            table check_ports {
                key = {
                    standard_metadata.ingress_port: exact;
                    standard_metadata.egress_spec: exact;
                }
                actions = {
                    set_direction;
                    NoAction;
                }
                size = 1024;
                default_action = NoAction();
            }

            apply {
                if (hdr.ipv4.isValid()){
                    ipv4_lpm.apply();
                    if (hdr.tcp.isValid()){
                        direction = 0; // default
                        if (check_ports.apply().hit) {
                            // test and set the bloom filter
                            if (direction == 0) {
                                compute_hashes(hdr.ipv4.srcAddr, hdr.ipv4.dstAddr, hdr.tcp.srcPort, hdr.tcp.dstPort);
                            }
                            else {
                                compute_hashes(hdr.ipv4.dstAddr, hdr.ipv4.srcAddr, hdr.tcp.dstPort, hdr.tcp.srcPort);
                            }
                            // Packet comes from internal network
                            if (direction == 0){
                                // If there is a syn we update the bloom filter and add the entry
                                if (hdr.tcp.syn == 1){
                                    bloom_filter_1.write(reg_pos_one, 1);
                                    bloom_filter_2.write(reg_pos_two, 1);
                                }
                            }
                            // Packet comes from outside
                            else if (direction == 1){
                                // Read bloom filter cells to check if there are 1's
                                bloom_filter_1.read(reg_val_one, reg_pos_one);
                                bloom_filter_2.read(reg_val_two, reg_pos_two);
                                // only allow flow to pass if both entries are set
                                if (reg_val_one != 1 || reg_val_two != 1){
                                    drop();
                                }
                            }
                        }
                    }
                }
            }
        }
      '';
      "MyEgress" = ''
        control MyEgress(inout headers hdr,
                         inout metadata meta,
                         inout standard_metadata_t standard_metadata) {
            apply {  }
        }
      '';
      "MyComputeChecksum" = ''
        control MyComputeChecksum(inout headers  hdr, inout metadata meta) {
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
      "MyDeparser" = ''
        control MyDeparser(packet_out packet, in headers hdr) {
            apply {
                packet.emit(hdr.ethernet);
                packet.emit(hdr.ipv4);
                packet.emit(hdr.tcp);
            }
        }
      '';
    };
  };

in {

  options = {

    networking.p4 = {
      load_balancer = {
        enable = mkOption {
          type = types.bool;
          default = false;
          description = lib.mdDoc ''
            Whether to enable a P4 load_balancer
            blabla see https://github.com/p4lang/tutorials
          '';
          # TODO: add source item
        };

        firewall = {
          enable = mkOption {
            type = types.bool;
            default = false;
            description = lib.mdDoc ''
              Whether to enable a P4 firewall
              blabla see https://github.com/p4lang/tutorials
            '';
            # TODO: add source item
          };

          #        p4Platform.mkProgram {
          #          name = "test";
          #          src = (p4Platform.runTranspiler { p4Source = source; });
          #          p4Target = "bmv2-v1model";

          # ip [ ]
        };

      };
    };
  };

}
