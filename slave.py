#!/usr/bin/env python
import sys
import struct

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

def handle_pkt(pkt):
    print "got a packet"
    pkt.show2()
    sys.stdout.flush()
    if (pkt[ATOMICCOMMIT].request_type == 0):
      pkt[ATOMICCOMMIT].resp = 1
      pkt = pkt / vals[pkt[ATOMICCOMMIT].key]
      sendp(pkt, iface=iface, verbose=False)
    else:
      vals[pkt[ATOMICCOMMIT].key] = pkt[Raw]


class AtomicCommit(Packet):
   fields_desc = [ BitField("request_number", 0, 16),
                   BitField("request_type", 0, 1),
                   BitField("vote",  0, 1),
                   BitField("resp",  0, 1),
                   BitField("state", 0, 2),
                   BitField("key", 0, 11),]


bind_layers(Ether, AtomicCommit, type=0x1313)

def main():
    iface = get_if()
    print "sniffing on %s" % iface
    sys.stdout.flush()
    sniff(iface = iface,
          prn = lambda x: handle_pkt(x))

if __name__ == '_main_':
    main()
