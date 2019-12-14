#!/usr/bin/env python2
import argparse
import grpc
import os
import sys
from time import sleep

sys.path.append(os.path.join(os.path.dirname(os.path.abspath(__file__)), 'utils/'))
import run_exercise
import p4runtime_lib.bmv2
from p4runtime_lib.switch import ShutdownAllSwitchConnections
import p4runtime_lib.helper

switches = {}
p4info_helper = None

def addMulticastGroup(switch, mc_group_id, ports):
    reps = list()
    for p in ports:
        reps.append({
            "egress_port" : p,
            "instance" : 1
        })
    mc_entry = p4info_helper.buildMulticastGroupEntry(
        multicast_group_id=mc_group_id,
        replicas=reps
        )
    bmv2_switch = switches[switch]
    bmv2_switch.WriteMulticastGroupEntry(mc_entry)
    print "Installed multicast group on %s with ports %d" % (switch, 0)

def addVoteRule(switch, commit):
    # Helper function to install voting rules on switches
    table_entry = p4info_helper.buildTableEntry(
        table_name="MyIngress.atco_vote",
        match_fields={},
        action_name="MyIngress.vote_commit" if commit else "MyIngress.vote_abort",
        action_params={}
        )
    bmv2_switch = switches[switch]
    bmv2_switch.WriteTableEntry(table_entry)
    print "Installed rule on %s to vote %s" % (switch, "commit" if commit else "abort")

def main(p4info_file_path, bmv2_file_path, topo_file_path):
    # Instantiate a P4Runtime helper from the p4info file
    global p4info_helper
    p4info_helper = p4runtime_lib.helper.P4InfoHelper(p4info_file_path)

    try:
        # Establish a P4 Runtime connection to each switch
        for switch in ["s1", "s2", "s3", "s4"]:
            switch_id = int(switch[1:])
            bmv2_switch = p4runtime_lib.bmv2.Bmv2SwitchConnection(
                name=switch,
                address="127.0.0.1:%d" % (50050 + switch_id),
                device_id=(switch_id - 1),
                proto_dump_file="logs/%s-p4runtime-requests.txt" % switch)            
            bmv2_switch.MasterArbitrationUpdate()
            print "Established as controller for %s" % bmv2_switch.name

            bmv2_switch.SetForwardingPipelineConfig(p4info=p4info_helper.p4info,
                                                    bmv2_json_file_path=bmv2_file_path)
            print "Installed P4 Program using SetForwardingPipelineConfig on %s" % bmv2_switch.name
            switches[switch] = bmv2_switch

        # NOTE: When using simple_switch_CLI to change multicast groups, use the following thrift ports:
        # s1 = 9090
        # s2 = 9091
        # s3 = 9092
        # s4 = 9093

        # TODO: Set up multicast groups for each switch
        addMulticastGroup("s4", 1, list([2, 3, 4]))

        # TODO: Add rules to determine how participants vote
        addVoteRule("s1", True)
        addVoteRule("s2", True)
        addVoteRule("s3", True)
        addVoteRule("s4", True)

        
    except KeyboardInterrupt:
        print " Shutting down."
    except grpc.RpcError as e:
        print "gRPC Error:", e.details(),
        status_code = e.code()
        print "(%s)" % status_code.name,
        traceback = sys.exc_info()[2]
        print "[%s:%d]" % (traceback.tb_frame.f_code.co_filename, traceback.tb_lineno)

    ShutdownAllSwitchConnections()

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='P4Runtime Controller')
    parser.add_argument('--p4info', help='p4info proto in text format from p4c',
                        type=str, action="store", required=False,
                        default='./build/switch.p4.p4info.txt')
    parser.add_argument('--bmv2-json', help='BMv2 JSON file from p4c',
                        type=str, action="store", required=False,
                        default='./build/switch.json')
    parser.add_argument('--topo', help='Topology file',
                        type=str, action="store", required=False,
                        default='topology.json')
    args = parser.parse_args()

    if not os.path.exists(args.p4info):
        parser.print_help()
        print "\np4info file not found: %s\nHave you run 'make'?" % args.p4info
        parser.exit(1)
    if not os.path.exists(args.bmv2_json):
        parser.print_help()
        print "\nBMv2 JSON file not found: %s\nHave you run 'make'?" % args.bmv2_json
        parser.exit(1)
    if not os.path.exists(args.topo):
        parser.print_help()
        print "\nTopology file not found: %s" % args.topo
        parser.exit(1)
    main(args.p4info, args.bmv2_json, args.topo)
