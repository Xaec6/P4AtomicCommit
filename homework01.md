---
layout: single
permalink: homework01.html
title: "Homework 1"
---

# Changelog

* v1: September 5, 2019
    
# Overview
    
In this assignment, you will set up a virtual machine that we will use
for assignments throughout the course, and gain familiarity with
common utilities and data formats and utilities by implementing a
simple program to forward IPv4 packets in a three-switch topology.

# Due Date

* 11:59pm, September, 17, 2019
    
# Academic Integrity

This assignment must be completed individually. All work you submit
must be your own and sharing or receiving code is forbidden. The
assignment is self-contained. Please do not look for or submit code
you find on the Internet, and do not post solutions or partial
solutions on the discussion site. If you make use of _any_ outside
materials, you must give attribution. You may ask general questions
about the development environment, `p4c`, `bmv2`, Mininet, etc., and
you may discuss high-level details of the exercises with your
classmates. If you have any questions about what is allowed and what
is not allowed, please ask the instructor first!

# Background Assumptions

The instructions for this assignment are written assuming basic
familiarity with virtual machines, the Unix command-line, and the
Python programming language. If any of these things are new to you,
that's totally fine! But please let us know so we can give you some
additional background so you can quickly complete this assignment.

# Virtual Machine and Starter Code

We have created a virtual machine image with all of the software
needed to complete this assignment pre-installed. However, to run the
virtual machine, you will need to install a hypervisor---e.g.,
VirtualBox, Parallels, VMware Workstation, etc. We recommend using
[VirtualBox](https://www.virtualbox.org/) as it is free and is
available on many platforms (e.g., OS X, Linux, and Windows).

After you've installed a hypervisor, download the virtual machine
image. It is approximately 5.7GB and is available
[here](http://stanford.edu/~sibanez/docs/P4%20Tutorial%202019-08-15.ova).

Next, import the virtual machine image and boot it up. After a few
minutes, it should login automatically and leave you in an intuitive,
graphical development environment. Most common tools and editors are
already installed, but just in case, feel free to reconfigure the
machine to your liking. The user name and password are both `p4` and
it is an administrator (i.e., in Unix parlance, it is a "sudoer").

Finally, download the starter code for this assignment from CMS and
unzip the file on your virtual machine. This should create a directory
named `homework01` in your home directory.

## Exercise 0: Warmup

First, let's check out the starter code and make sure it compiles.
```
% make
```

Assuming this step is successful, it will use the Mininet emulator to
create a network with three switches and three hosts connected in a
triangle topology. Look at the `topology.json` file to see the precise
structure of the topology, including the connections beween the
switches and hosts, and the IPv4 addresses of the hosts. You will see
a `mininet>` prompt where you can issue commands, such as `h1 ping h2`
or `quit`.

Next, in a separate terminal window, start a controller that can
be used to populate the tables on the switches with forwarding rules.
```
% ./mycontroller.py
```
You should see some output on the command-line indicating that the
controller has successfully connected to the switches:
```
Established as controller for s1
Installed P4 Program using SetForwardingPipelineConfig on s1
...
```
Finally, let's run a simple test to see if the hosts in the topology
can already communicate with each other.
```
mininet> pingall
*** Ping: testing ping reachability
h1 -> X 
h2 -> X 
*** Results: 100% dropped (0/2 received)
```
As you can see, this test shows that packets are *not* being correctly
received. However, this is expected as the forwarding tables have not
yet been populated with rules.

**To submit:** Nothing

## Exercise 1: Implement Basic Forwarding

Your maintask in this exercise is to implement a controller that
populates the tables with forwarding rules that establish connectivity
between hosts `h1`, `h2`, and `h3`. To help you get started, we have
provided a `mycontroller.py` file that includes a helper function
`addForwardingRule` that can be used to populate the tables on each
switch.

For example, the command
```
addForwardingRule("s1", "10.0.1.11", 1)
```
adds a rule packets on `s1` that matches packets whose IPv4
destination address is `10.0.1.11` and forwards them out on port
`1`. Note that the switch and IPv4 destination address are encoded as
strings, while the port number is encoded as an integer in Python.

### Implementation Notes

For each pair of hosts, you should:

* Calculate (by hand) a suitable path that connects those hosts in the
  topology, and then

* Install forwarding rules to implement that path.

If you search for `TODO` in the Python starter code, you will see
where the required code should be added.

Note that mininet uses a number of processes, files, and other
resources to emulate a network. If anything goes wrong, you can kill
the scripts by typing control-C. However, the resources used by
Mininet will need to be cleaned up or you may see strange behaviors
the next time you run the code. Use the `make clean` command to return
your development environment to a pristine state.

### Testing
    
To test that your solution is working as expected you can use the
`pingall` command from the Mininet CLI.

**To submit:** submit `mycontroller.py` on CMS.
        
## Debriefing

* How many hours did you spend on this assignment? 

* Would you rate it as easy, moderate, or difficult? 
    
* How deeply do you feel you understand the material it covers (0%-100%)?

* If you have any other comments, I would like to hear them! Please
write them down or send email to `jnfoster@cs.cornell.edu`

**To submit:** `debriefing.txt`
