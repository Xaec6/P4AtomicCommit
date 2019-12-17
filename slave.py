#!/usr/bin/env python
import sys
import struct
from pprint import pprint

from scapy.all import sniff, sendp, hexdump, get_if_list, get_if_hwaddr, bind_layers
from scapy.all import Packet, IPOption
from scapy.all import IP, UDP, Raw, Ether
from scapy.fields import *

vals = {}

def get_if():
    ifs=get_if_list()
    iface=None
    for i in get_if_list():
        if "eth0" in i:
            iface=i
            break;
    if not iface:
        print "Cannot find eth0 interface"
        exit(1)
    return iface

def handle_pkt(pkt, iface):
    print "got a packet"
    pkt.show2()
    sys.stdout.flush()
    if hasattr(pkt, "type") and pkt.type == 0x1313:
      if pkt.request_type == 0 and pkt.vote == 0:
          if pkt.key in vals:
              pkt = pkt / Raw(vals[pkt.key])
          else:
              pkt = pkt / Raw("Error: Could not find key %s" % pkt.key)
          pkt.vote = 1
          sendp(pkt, iface=iface, verbose=False)
      elif pkt.request_type == 1:
          vals[pkt.key] = pkt[Raw].load
          pprint(vals)
    else:
        print "packet was not an AtomicCommit packet. Ignoring..."


class AtomicCommit(Packet):
   fields_desc = [ BitField("dest_port", 0, 9),
                   BitField("request_number", 0, 16),
                   BitField("request_type", 0, 1),
                   BitField("vote",  0, 1),
                   BitField("resp",  0, 2),
                   BitField("state", 0, 3),
                   BitField("key", 1, 8),]


bind_layers(Ether, AtomicCommit, type=0x1313)

def main():
    iface = get_if()
    print "sniffing on %s" % iface
    sys.stdout.flush()
    sniff(iface = iface,
          prn = lambda x: handle_pkt(x, iface))

if __name__ == '__main__':
    main()
