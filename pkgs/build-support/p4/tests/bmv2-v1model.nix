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
    include = [ "core.p4" "v1model.p4" ];

    define = { "test" = "test2"; };
    headers = {
      const = {
        "MAX_HOPS" = { type = "int"; value = "10"; };
        "STANDARD" = { type = "int"; value = "0"; };
        "HOPS" = { type = "int"; value = "1"; };
      };

      header = { "type_t".content = [ { "tag" = "bit<8>"; } ]; 
        "hop_t".content = [ 
          { "port" = "bit<8>"; } 
          { "bos" = "bit<8>"; } 
        ]; 
        "standard_t".content = [ 
          { "src" = "bit<8>"; } 
          { "dst" = "bit<8>"; } 
        ]; 
      };

      struct = {
        "headers_t".content = [
          { "type" = "type_t"; }
          { "hops" = "hop_t[MAX_HOPS]"; }
          { "standard" = "standard_t"; }
        ];
        "meta_t".content = [];
      };
      typedef = { "std_meta_t" = "standard_metadata_t"; };
    };
    target = "v1switch";
    logic = [{
      "MyParser" = ''
          parser MyParser(packet_in pkt, out headers_t hdr, inout meta_t meta, inout std_meta_t std_meta) {
              state start {
                  pkt.extract(hdr.type);
                  transition select(hdr.type.tag) {
                      HOPS: parse_hops;
                      STANDARD: parse_standard;
                      default: accept;
                  }
              }
              state parse_hops {
                  pkt.extract(hdr.hops.next);
                  transition select(hdr.hops.last.bos) {
                      1: parse_standard;
                      default: parse_hops;
                  }
              }
              
              state parse_standard {
                  pkt.extract(hdr.standard);
                  transition accept;
              }
          }
        '';
      }
      {
        "MyVerifyChecksum" = ''
          control MyVerifyChecksum(inout headers_t hdr, inout meta_t meta) {
              apply { }
          }
        ''; 
      }
      {
        "MyIngress" = ''
          control MyIngress(inout headers_t hdr, inout meta_t meta, inout std_meta_t std_meta) {
            action allow() { }
            action deny() { std_meta.egress_spec = 9w511; }
            table acl {
              key = { hdr.standard.src : exact; hdr.standard.dst : exact; }
              actions = { allow; deny; }
              const entries = { (0xCC, 0xDD) : deny(); }
              default_action = allow();
            }
            apply {
              std_meta.egress_spec = (bit<9>) hdr.hops[0].port;
              hdr.hops.pop_front(1);
              if (!hdr.hops[0].isValid()) {
                  hdr.type.tag = 0x00;
              }
              acl.apply();
            }
          }
        ''; 
      }

      {
        "MyEgress" = ''
          control MyEgress(inout headers_t hdr, inout meta_t meta, inout std_meta_t std_meta) {
              apply { }
          }
        ''; 
      }

      {
        "MyComputeChecksum" = ''
          control MyComputeChecksum(inout headers_t hdr, inout meta_t meta) {
              apply { }
          }
        ''; 
      }
      {
        "MyDeparser" = ''
          control MyDeparser(packet_out pkt, in headers_t hdr) {
              apply {
                  pkt.emit(hdr.type);
                  pkt.emit(hdr.hops);
                  pkt.emit(hdr.standard);
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
    p4Target = "bmv2-v1model";
  }







