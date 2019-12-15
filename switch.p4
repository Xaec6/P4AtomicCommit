/* -*- P4_16 -*- */
#include <core.p4>
#include <v1model.p4>

const bit<16> TYPE_ATCO = 0x1313;

// Atco req_types
const bit<1> REQ_GET = 0x0;
const bit<1> REQ_SET = 0x1;

// Atco votes
const bit<1> VOTE_ABORT = 0x0;
const bit<1> VOTE_COMMIT = 0x1;

// Atco msg_types
const bit<2> MSG_REQ = 0x0;
const bit<2> MSG_VOTE_REQ = 0x1;
const bit<2> MSG_VOTE = 0x2;
const bit<2> MSG_DO = 0x3;

/*************************************************************************
*********************** H E A D E R S  ***********************************
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
    bit<16> req_n;
    bit<1>  req_type;
    bit<1>  vote;
    bit<2>  msg_type;
    bit<4>  padding;
}

struct metadata {
    /* empty */
}

struct headers {
    ethernet_t   ethernet;
    atco_t       atco;
}

/*************************************************************************
*********************** P A R S E R  ***********************************
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
************   C H E C K S U M    V E R I F I C A T I O N   *************
*************************************************************************/

control MyVerifyChecksum(inout headers hdr, inout metadata meta) {   
    apply {  }
}


/*************************************************************************
**************  I N G R E S S   P R O C E S S I N G   *******************
*************************************************************************/

control MyIngress(inout headers hdr,
                  inout metadata meta,
                  inout standard_metadata_t standard_metadata) {

    /* Index 0 of this register is used to keep track of request numbers for
     * load balancing/flow control.
     * Index 1 of this register is used to keep track of request numbers for
     * atomic commits.
     */
    register<bit<16>>(2) c;

    /* This action votes to abort the transaction
     */
    action vote_abort() {
        if (hdr.atco.isValid() && hdr.atco.msg_type == MSG_VOTE_REQ) {
            hdr.atco.msg_type = MSG_VOTE;
            hdr.atco.vote = VOTE_ABORT;
        }
    }

    /* This action votes to commit the transaction
     */
    action vote_commit() {
        if (hdr.atco.isValid() && hdr.atco.msg_type == MSG_VOTE_REQ) {
            hdr.atco.msg_type = MSG_VOTE;
            hdr.atco.vote = VOTE_COMMIT;
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
    table atco_vote {
        key = { }
        actions = {
            vote_commit;
            vote_abort;
            drop;
        }
        default_action = drop();
    }

    apply {
        if (hdr.atco.isValid()) {
            /* For simplicity, we assume that only coordinators will receive
             * MSG_REQ and MSG_VOTE whereas only participants will receive
             * MSG_VOTE_REQ and MSG_DO.
             */

            if(hdr.atco.msg_type == MSG_REQ){
                // TODO: whatever this is
                bit<16> r;
                c.read(r, 0);
                c.write(0, r + 1);
                if (hdr.atco.req_n == 0){
                    if (hdr.atco.req_type == 0){
                        bit<16> port;
                        bit<4> tw = 2;
                        bit<4> fr = 4;
                        hash(port, HashAlgorithm.identity, tw, {r}, fr);
                        hdr.atco.req_n = r;
                        standard_metadata.egress_spec = (egressSpec_t)port;
                    }
                    else {
                        c.read(r, 1);
                        c.write(1, r + 1);
                    }
                }
            }

            else if(hdr.atco.msg_type == MSG_VOTE_REQ){
                atco_vote.apply();
                // Forward the packet to both the database and back to the coordinator
                standard_metadata.mcast_grp = 1;
            }

            else if(hdr.atco.msg_type == MSG_VOTE){
                // TODO: tally up the vote
            }

            else if(hdr.atco.msg_type == MSG_DO){
                // Forward the packet to the database to commit the transaction
                standard_metadata.egress_spec = 1;
            }
        }

        else {
            drop();
        }
    }


}

/*************************************************************************
****************  E G R E S S   P R O C E S S I N G   *******************
*************************************************************************/

control MyEgress(inout headers hdr,
                 inout metadata meta,
                 inout standard_metadata_t standard_metadata) {
    apply {  }
}

/*************************************************************************
*************   C H E C K S U M    C O M P U T A T I O N   **************
*************************************************************************/

control MyComputeChecksum(inout headers  hdr, inout metadata meta) {
     apply {
    }
}

/*************************************************************************
***********************  D E P A R S E R  *******************************
*************************************************************************/

control MyDeparser(packet_out packet, in headers hdr) {
    apply {
        packet.emit(hdr.ethernet);
        packet.emit(hdr.atco);
    }
}

/*************************************************************************
***********************  S W I T C H  *******************************
*************************************************************************/

V1Switch(
MyParser(),
MyVerifyChecksum(),
MyIngress(),
MyEgress(),
MyComputeChecksum(),
MyDeparser()
) main;
