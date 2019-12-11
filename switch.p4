/* -*- P4_16 -*- */
#include <core.p4>
#include <v1model.p4>

const bit<16> TYPE_ATCO = 0x1313;
const bit<16> MAX_CON = 0x1; //maximum concurrent transactions
const bit<16> NUM_PARTICIPANTS = 0x3;

// Atco req_types
const bit<1> REQ_GET = 0x0;
const bit<1> REQ_SET = 0x1;

// Atco votes
const bit<1> VOTE_ABORT = 0x0;
const bit<1> VOTE_COMMIT = 0x1;

// Protocol Req/resp
const bit<1> ATCO_REQ = 0x0;
const bit<1> ATCO_RESP = 0x1;

// Atco msg_types
// Client sends a message to a coordinator to either get or set something
const bit<2> MSG_REQ = 0x0;
// Coordinator sends request to participant, asking whether or not to commit or abort transaction
const bit<2> MSG_VOTE_REQ = 0x1;
// Participant response (with either commit or abort) to MSG_VOTE_REQ
const bit<2> MSG_VOTE = 0x2;
// Coordinator tells all participants the final decision (either commit or abort)
const bit<2> MSG_DO = 0x3;

/*************************************************************************
********************* H E A D E R S  *********************************
*************************************************************************/

typedef bit<9>  egressSpec_t;
typedef bit<48> macAddr_t;

header ethernet_t {
    macAddr_t dstAddr;
    macAddr_t srcAddr;
    bit<16>   etherType;
}

header myTunnel_t {
    bit<16> proto_id;
    bit<16> dst_id;
}

header atco_t {
    // Request Number
    bit<16> req_n;
    // Either a GET or SET request
    bit<1>  req_type;
    // Either COMMIT or ABORT
    bit<1>  vote;
    // Either REQ or RESP
    bit<1>  resp;
    // Various 2PC message types
    bit<2>  msg_type;
    bit<11>  key;
}

struct metadata {
    /* empty */
}

struct headers {
    ethernet_t   ethernet;
    atco_t       atco;
}

/*************************************************************************
********************* P A R S E R  *********************************
*************************************************************************/

parser MyParser(packet_in packet,
                out headers hdr,
                inout metadata meta,
                inout standard_metadata_t standard_metadata) {

    state start {
        transition parse_ethernet;
    }

    state parse_ethernet {
        packet.extract(hdr.ethernet);
        transition select(hdr.ethernet.etherType) {
            TYPE_ATCO: parse_atco;
            default: accept;
        }
    }

    state parse_atco {
        packet.extract(hdr.atco);
        transition accept;
    }

}

/*************************************************************************
**********   C H E C K S U M    V E R I F I C A T I O N   ***********
*************************************************************************/

control MyVerifyChecksum(inout headers hdr, inout metadata meta) {   
    apply {  }
}


/*************************************************************************
************  I N G R E S S   P R O C E S S I N G   *****************
*************************************************************************/

control MyIngress(inout headers hdr,
                  inout metadata meta,
                  inout standard_metadata_t standard_metadata) {

    /* This register is used to keep track of request numbers for
     * load balancing/flow control.
     */
    register<bit<16>>((bit<32>)MAX_CON) yes_votes;
    bit<1> decision;


    action forward(egressSpec_t port) {
        standard_metadata.egress_spec = port;
    }

    action multicast(bit<16> mc, bit<2> new_msg_type) {
        hdr.atco.msg_type = new_msg_type;
        standard_metadata.mcast_grp = mc;
    }

    /* This action votes to either commit or abort the transaction
     */
    action vote(bit<1> v) {
        hdr.atco.msg_type = MSG_VOTE;
        hdr.atco.vote = v;
    }

    action decide() {
        bit<16> temp;
        yes_votes.read(temp, (bit<32>)(hdr.atco.req_n % MAX_CON));
        temp = temp + 1;
        yes_votes.write((bit<32>)(hdr.atco.req_n % MAX_CON), temp);
        if(temp == NUM_PARTICIPANTS) {
          decision = 1;
        }
    }

    /* This action drops the packet
     */
    action drop() {
        mark_to_drop(standard_metadata);
    }

    /* This table allows us to use the control plane to specify if a switch
     * will vote to commit or abort a transaction
     */
    table atco {
        key = {
            hdr.atco.msg_type: exact;
            hdr.atco.key: exact;
        }
        actions = {
            forward;
            multicast;
            vote;
            decide;
            drop;
        }
        default_action = drop();
    }

    apply {
        if (hdr.atco.isValid()) {
            decision = 0;
            standard_metadata.egress_spec = standard_metadata.ingress_port;
            if(hdr.atco.req_type == REQ_GET){
                if (hdr.atco.resp == 0) {
                    forward(1);
                }
                else {
                    forward(5);
                }
            }

            else {
                atco.apply();
                if (hdr.atco.msg_type == MSG_VOTE && hdr.atco.vote == VOTE_COMMIT) {
                    if (decision == 1) {
                        bit<16> temp = 0;
                        yes_votes.write((bit<32>)(hdr.atco.req_n % MAX_CON), temp);
                        multicast(1, MSG_DO);
                    }

                    else {
                        //drop();
                    }
                }
            }
        }

        else {
            drop();
        }
    }
}

/*************************************************************************
**************  E G R E S S   P R O C E S S I N G   *****************
*************************************************************************/

control MyEgress(inout headers hdr,
                 inout metadata meta,
                 inout standard_metadata_t standard_metadata) {
    apply {  }
}

/*************************************************************************
***********   C H E C K S U M    C O M P U T A T I O N   ************
*************************************************************************/

control MyComputeChecksum(inout headers  hdr, inout metadata meta) {
     apply {
    }
}

/*************************************************************************
*********************  D E P A R S E R  *****************************
*************************************************************************/

control MyDeparser(packet_out packet, in headers hdr) {
    apply {
        packet.emit(hdr.ethernet);
        packet.emit(hdr.atco);
    }
}

/*************************************************************************
*********************  S W I T C H  *****************************
*************************************************************************/

V1Switch(
MyParser(),
MyVerifyChecksum(),
MyIngress(),
MyEgress(),
MyComputeChecksum(),
MyDeparser()
) main;
