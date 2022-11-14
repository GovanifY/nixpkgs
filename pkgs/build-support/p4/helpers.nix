{ }:

{
  typedef = {
    "macAddr" = "bit<48>";

    "ip4Addr" = "bit<32>";

    "ip6Addr" = "bit<128>";
  };

  const = {
    "ETH_TYPE_IPV4" = { type = "bit<16>"; value = "0x800"; };

    "IPV4_PROTOCOL_ICMP" = { type = "bit<8>"; value = "1"; };
  };

  header = {
    "ethernet_h".content = [
      { "dstAddr" = "macAddr"; }
      { "srcAddr" = "macAddr"; }
      { "etherType" = "bit<16>"; }
    ];

    "icmp_h".content = [
      { "type" = "bit<8>"; }
      { "code" = "bit<8>"; }
      { "checksum" = "bit<16>"; }
      { "icmp_header" = "bit<32>"; }
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

    "ipv4_options_h".content = [{ "options" = "varbit<320>"; }];

    "ipv6_base_h".content = [
      { "version" = "bit<4>"; }
      { "trafficClass" = "bit<8>"; }
      { "flowLabel" = "bit<20>"; }
      { "payloadLen" = "bit<16>"; }
      { "nextHeader" = "bit<8>"; }
      { "hopLimit" = "bit<8>"; }
      { "srcAddr" = "ip6Addr"; }
      { "dstAddr" = "ip6Addr"; }
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

    "tcp_options_h".content = [{ "options" = "varbit<320>"; }];

    "udp_h".content = [
      { "srcPort" = "bit<16>"; }
      { "dstPort" = "bit<16>"; }
      { "length" = "bit<16>"; }
      { "checksum" = "bit<16>"; }
    ];

  };

}
