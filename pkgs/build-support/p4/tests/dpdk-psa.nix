# /!\ This is not standard Nix tests!!!
# This is NOT meant to be upstreamed!!!

# For now this is a simple test suite that builds an ebpf derivation that you
# can then load by hand in your kernel to see that everything builds fine. This
# is kept separate from the standard NixOS tests as more advanced tests will be
# done later in the project once everything is a little bit more stabilized and
# we can reuse modules that we will have created.

# Run me with: NIX_PATH="nixpkgs=$NIXPKGS" nix-build pkgs/build-support/p4/tests.nix
with import <nixpkgs> {};
with pkgs.p4Platform.helpers.header;
with pkgs.p4Platform.helpers.typedef;
with pkgs;
let 
  source = {

    # core is included by default anv v1model will be if the target is correctly
    # set but as the target logic isn't stabilized yet i'm including it manually
    include = [ "core.p4" "psa.p4" ];

    headers = {
      header = {
        inherit ethernet_h ipv4_no_options_h udp_h;
        "vxlan_t".content = [
          { "flags" = "bit<8>"; }
          { "reserved" = "bit<24>"; }
          { "vni" = "bit<24>"; }
          { "reserved2" = "bit<8>"; }
        ];
      };

      typedef = { 
        inherit macAddr ip4Addr;
      };

      struct = {
        empty_metadata_t.content = [];
        local_metadata_t.content = [
          { "dst_addr" = "macAddr"; }
          { "src_addr" = "macAddr"; }
        ];
        headers_t.content = [
          { "ethernet" = "ethernet_h"; }
          { "ipv4" = "ipv4_no_options_h"; }
          { "vxlan" = "vxlan_t"; }
          { "outer_ethernet" = "ethernet_h"; }
          { "outer_ipv4" = "ipv4_no_options_h"; }
          { "outer_udp" = "udp_h"; }
          { "outer_vxlan" = "vxlan_t"; }
        ];
      };
    };
    target = "psa";
    logic = [{
      "packet_parser" = ''
        parser packet_parser(packet_in packet, out headers_t headers, inout local_metadata_t local_metadata, in psa_ingress_parser_input_metadata_t standard_metadata, in empty_metadata_t resub_meta, in empty_metadata_t recirc_meta) {
            state start {
                transition parse_ethernet;
            }
            state parse_ethernet {
                packet.extract(headers.ethernet);
                transition parser_ipv4;
            }
            state parser_ipv4 {
                packet.extract(headers.ipv4);
                transition accept;
            }
        }
        '';
      }
      {
        "ingress" = ''
          control ingress(inout headers_t headers, inout local_metadata_t local_metadata1, in psa_ingress_input_metadata_t standard_metadata, inout psa_ingress_output_metadata_t ostd) {
              InternetChecksum() csum; 
              action vxlan_encap(
                  bit<48> ethernet_dst_addr,
                  bit<48> ethernet_src_addr,
                  bit<16> ethernet_ether_type,
                  bit<4> ipv4_version,
                  bit<4> ipv4_ihl,
                  bit<8> ipv4_diffserv,
                  bit<16> ipv4_total_len,
                  bit<16> ipv4_identification,
                  bit<3> ipv4_flags,
                  bit<13> ipv4_fragOffset,
                  bit<8> ipv4_ttl,
                  bit<8> ipv4_protocol,
                  bit<16> ipv4_hdr_checksum,
                  bit<32> ipv4_src_addr,
                  bit<32> ipv4_dst_addr,
                  bit<16> udp_src_port,
                  bit<16> udp_dst_port,
                  bit<16> udp_length,
                  bit<16> udp_checksum,
                  bit<8> vxlan_flags,
                  bit<24> vxlan_reserved,
                  bit<24> vxlan_vni,
                  bit<8> vxlan_reserved2,
                  bit<32> port_out
              ) {
                  headers.outer_ethernet.srcAddr = ethernet_src_addr;
                  headers.outer_ethernet.dstAddr = ethernet_dst_addr;

                  headers.outer_ethernet.etherType = ethernet_ether_type;
                  headers.outer_ipv4.version = ipv4_version; 
                  headers.outer_ipv4.ihl = ipv4_ihl; 
                  headers.outer_ipv4.diffserv = ipv4_diffserv; 
                  headers.outer_ipv4.totalLen = ipv4_total_len; 
                  headers.outer_ipv4.identification = ipv4_identification; 
                  headers.outer_ipv4.flags = ipv4_flags; 
                  headers.outer_ipv4.fragOffset = ipv4_fragOffset; 
                  headers.outer_ipv4.ttl = ipv4_ttl; 
                  headers.outer_ipv4.protocol = ipv4_protocol; 
                  headers.outer_ipv4.hdrChecksum = ipv4_hdr_checksum; 
                  headers.outer_ipv4.srcAddr = ipv4_src_addr; 
                  headers.outer_ipv4.dstAddr = ipv4_dst_addr;
                  headers.outer_udp.srcPort = udp_src_port;
                  headers.outer_udp.dstPort = udp_dst_port;
                  headers.outer_udp.length = udp_length;
                  headers.outer_udp.checksum = udp_checksum;
                  headers.vxlan.flags = vxlan_flags;
                  headers.vxlan.reserved = vxlan_reserved;
                  headers.vxlan.vni = vxlan_vni;
                  headers.vxlan.reserved2 = vxlan_reserved2;
                  ostd.egress_port = (PortId_t)port_out;
                  csum.add({headers.outer_ipv4.hdrChecksum, headers.ipv4.totalLen});
                  headers.outer_ipv4.hdrChecksum = csum.get();
                  headers.outer_ipv4.totalLen = headers.outer_ipv4.totalLen + headers.ipv4.totalLen;
                  headers.outer_udp.length = headers.outer_udp.length + headers.ipv4.totalLen;
              }
              action drop(){
                  ostd.egress_port = (PortId_t)4;
              }
              table vxlan {
                  key = {
                      headers.ethernet.dstAddr: exact;
                  }
                  actions = {
                      vxlan_encap;
                      drop;
                  }
                  const default_action = drop;
                  size =  1024 * 1024;
              }

              apply {
                  vxlan.apply();
              }
          }
          '';
        }
      {
        "packet_deparser" = ''
          control packet_deparser(packet_out packet, out empty_metadata_t clone_i2e_meta, out empty_metadata_t resubmit_meta, out empty_metadata_t normal_meta, inout headers_t headers, in local_metadata_t local_metadata, in psa_ingress_output_metadata_t istd) {
              apply {
                  packet.emit(headers.outer_ethernet);
                  packet.emit(headers.outer_ipv4);
                  packet.emit(headers.outer_udp);
                  packet.emit(headers.outer_vxlan);
                  packet.emit(headers.ethernet);
                  packet.emit(headers.ipv4);
              }
          }
        '';
      }
  { 
          "egress_parser" = ''
            parser egress_parser(packet_in buffer, out headers_t headers, inout local_metadata_t local_metadata, in psa_egress_parser_input_metadata_t istd, in empty_metadata_t normal_meta, in empty_metadata_t clone_i2e_meta, in empty_metadata_t clone_e2e_meta) {
                state start {
                    transition accept;
                }
            }
            '';
        }

              {
          "egress" = ''
            control egress(inout headers_t headers, inout local_metadata_t local_metadata, in psa_egress_input_metadata_t istd, inout psa_egress_output_metadata_t ostd) {
                apply {
                }
            }
          '';
        }
              { "egress_deparser" = ''
            control egress_deparser(packet_out packet, out empty_metadata_t clone_e2e_meta, out empty_metadata_t recirculate_meta, inout headers_t headers, in local_metadata_t local_metadata, in psa_egress_output_metadata_t istd, in psa_egress_deparser_input_metadata_t edstd) {
                apply {
                }
            }
          '';
        }

    ];
  };
in
  p4Platform.mkProgram { 
    name = "test";
    src = (p4Platform.runTranspiler 
      { p4Source = source; }); 
    p4Target = "dpdk-psa";
  }





