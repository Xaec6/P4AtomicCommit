#!/usr/bin/env python
import argparse
import sys
import socket
import random
import struct

from scapy.all import sendp, send, get_if_list, get_if_hwaddr, bind_layers
from scapy.all import Packet, Raw
from scapy.all import Ether, IP, UDP
from scapy.fields import *
import readline

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

class AtomicCommit(Packet):
   fields_desc = [ BitField("request_number", 0, 16),
                   BitField("request_type", 0, 1),
                   BitField("vote",  0, 1),
                   BitField("state", 0, 2),
                   BitField("padding", 0, 4)]

bind_layers(Ether, AtomicCommit, type=0x1313)

def main():
        
    iface = get_if()
    addr = socket.gethostbyname("10.0.0.4")
    typ = -1;
    if sys.argv[1] == "get":
        typ = 0
    elif sys.argv[1] == "set":
        typ = 1
    else:
        print "Invalid request: should start with 'get' or 'set'"
        exit(1)
    data = ' '.join(sys.argv[2:])
    print "sending on interface %s to %s" % (iface, str(addr))

    port = addr.split(".")[3]
    pkt =  Ether(src=get_if_hwaddr(iface), dst='ff:ff:ff:ff:ff:ff');
    pkt = pkt / AtomicCommit(request_type=typ)
    pkt = pkt / Raw(data)
    pkt.show2()
    sendp(pkt, iface=iface, verbose=False)

if __name__ == '__main__':
    main()
