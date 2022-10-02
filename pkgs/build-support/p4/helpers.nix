{ }:

{
  typedef = {
    macAddr = { type = "bit<48>"; name = "macAddr"; };

    ip4Addr = { type = "bit<32>"; name = "ip4Addr"; };

    ip6Addr = { type = "bit<128>"; name = "ip6Addr"; };
  };

  header = {
    ethernet_h = {
      name = "ethernet_h";
      content = [
        { type = "macAddr"; name = "dstAddr"; }
        { type = "macAddr"; name = "srcAddr"; }
        { type = "bit<16>"; name = "etherType"; }
      ];
    };

    ipv4_no_options_h = {
      name = "ipv4_no_options_h";
      content = [
        { type = "bit<4>"; name = "version"; }
        { type = "bit<4>"; name = "ihl"; }
        { type = "bit<8>"; name = "diffserv"; }
        { type = "bit<16>"; name = "totalLen"; }
        { type = "bit<16>"; name = "identification"; }
        { type = "bit<3>"; name = "flags"; }
        { type = "bit<13>"; name = "fragOffset"; }
        { type = "bit<8>"; name = "ttl"; }
        { type = "bit<8>"; name = "protocol"; }
        { type = "bit<16>"; name = "hdrChecksum"; }
        { type = "ip4Addr"; name = "srcAddr"; }
        { type = "ip4Addr"; name = "dstAddr"; }
      ];
    };

    ipv4_options_h = {
      name = "ipv4_options_h";
      content = [ { type = "varbit<320>"; name = "options"; } ];
    };

    ipv6_base_h = {
      name = "ipv6_base_h";
      content = [
        { type = "bit<4>"; name = "version"; }
        { type = "bit<8>"; name = "trafficClass"; }
        { type = "bit<20>"; name = "flowLabel"; }
        { type = "bit<16>"; name = "payloadLen"; }
        { type = "bit<8>"; name = "nextHeader"; }
        { type = "bit<8>"; name = "hopLimit"; }
        { type = "ip6Addr"; name = "srcAddr"; }
        { type = "ip6Addr"; name = "dstAddr"; }
      ];
    };


    tcp_no_options_h = { 
      name = "tcp_h";
      content = [
        { type = "bit<16>"; name = "srcPort"; }
        { type = "bit<16>"; name = "dstPort"; }
        { type = "bit<32>"; name = "seqNo"; }
        { type = "bit<32>"; name = "ackNo"; }
        { type = "bit<4>"; name = "dataOffset"; }
        { type = "bit<4>"; name = "res"; }
        { type = "bit<1>"; name = "cwr"; }
        { type = "bit<1>"; name = "ece"; }
        { type = "bit<1>"; name = "urg"; }
        { type = "bit<1>"; name = "ack"; }
        { type = "bit<1>"; name = "psh"; }
        { type = "bit<1>"; name = "rst"; }
        { type = "bit<1>"; name = "syn"; }
        { type = "bit<1>"; name = "fin"; }
        { type = "bit<16>"; name = "window"; }
        { type = "bit<16>"; name = "checksum"; }
        { type = "bit<16>"; name = "urgentPtr"; }
      ];
    };

    tcp_options_h = { 
      name = "tcp_options_h";
      content = [ { type = "varbit<320>"; name = "options"; } ];
    };

    udp_h = {
      name = "udp_h";
      content = [
        { type = "bit<16>"; name = "srcPort"; }
        { type = "bit<16>"; name = "dstPort"; }
        { type = "bit<16>"; name = "length"; }
        { type = "bit<16>"; name = "checksum"; }
      ];
    };


  };

}
