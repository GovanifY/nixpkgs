# /!\ This is not standard Nix tests!!!
# This is NOT meant to be upstreamed!!!

# For now this is a simple test suite that builds an ebpf derivation that you
# can then load by hand in your kernel to see that everything builds fine. This
# is kept separate from the standard NixOS tests as more advanced tests will be
# done later in the project once everything is a little bit more stabilized and
# we can reuse modules that we will have created.

# Run me with: sudo nixos-rebuild build-vm --fast -I nixos-config=./tests.nix -I nixpkgs=$NIXPKGS
{ config, pkgs, lib, ... }:
with pkgs.p4Platform.helpers.header;
with pkgs.p4Platform.helpers.typedef;
let 
  source = {
    define = { "test" = "test2"; };
    headers = {
      header = { inherit ethernet_h ipv4_no_options_h; };
      typedef = { inherit macAddr ip4Addr; };
    };
    target = "v1switch";
    logic = [{
      "MyParser" = ''
        parser MyParser(packet_in packet,
                out headers hdr,
                inout metadata meta,
                inout standard_metadata_t standard_metadata) {
                apply { }
        }
        '';
      }
    ];
  };
in
{
  users = {
    mutableUsers = false;
    extraUsers = {
      root = {
        password = "toor";
      };
    };
  };
  services.openssh.enable = (lib.traceSeq source true);

  networking.hostName = (lib.traceSeq (pkgs.p4Platform.runTranspiler {p4Source = source;} ) "");
}
