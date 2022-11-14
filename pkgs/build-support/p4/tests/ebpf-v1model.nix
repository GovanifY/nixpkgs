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
with pkgs.p4Platform.helpers.const;
with pkgs;
let 
  source = {

    # core is included by default anv v1model will be if the target is correctly
    # set but as the target logic isn't stabilized yet i'm including it manually
    include = [ "core.p4" "ebpf_model.p4" ];

    headers = {
      header = {
        inherit ethernet_h ipv4_no_options_h icmp_h;
      };

      typedef = { 
        inherit macAddr ip4Addr;
      };

      const = {
        inherit ETH_TYPE_IPV4 IPV4_PROTOCOL_ICMP;
      };

      struct = {
        "headers_t".content = [
          { "ethernet" = "ethernet_h"; }
          { "ip" = "ipv4_no_options_h"; }
          { "icmp" = "icmp_h"; }
        ];
      };

    };
    target = "ebpf";
    logic.main = [{
      "MyParser" = ''
        parser MyParser(packet_in p, out headers_t headers) {
            state start {
                transition parse_ethernet;
            }

            state parse_ethernet {
                p.extract(headers.ethernet);
                transition select (headers.ethernet.etherType) {
                    ETH_TYPE_IPV4 : parse_ip;
                    default   : accept;
                }
            }

            state parse_ip {
                p.extract(headers.ip);
                transition select (headers.ip.protocol) {
                    IPV4_PROTOCOL_ICMP : parse_icmp;
                    default   : accept;
                }
            }

            state parse_icmp {
                p.extract(headers.icmp);
                transition accept;
            }
        }
        '';
      }
      {
        "MyPipe" = ''
          control MyPipe(inout headers_t headers, out bool pass) {
              apply {
                  pass = true;
                  if(headers.icmp.isValid()) {
                      pass  = false;
                  }
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
    p4Target = "ebpf-v1model";
  }







