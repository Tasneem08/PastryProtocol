# Project3

**Mugdha Mathkar UFID:54147979    Tasneem Sheikh UFID:01360914**

## How to run?

Navigate to the right directory and run the following commands;

mix escript.build
./project3 <numNodes> <numRequests>

Brief Description:

PASTRY is an implementation of the Distributed Hash Tables(DHT) algorithm in Peer to Peer network overlay. It is fully decentralized, scalable and has high fault tolerance.

Each node is identified by a unique 128 bit node identifier (NodeId). This node identifier is assumed to be generated randomly. Also, each nodeId has the same chances of being picked and two nodes with similar nodeId may be geographically far.

Given a key, PASTRY can deliver a message to the node with the closest NodeId to key within ceil(logb N) steps, where b=2^c is a configuration parameter and N is the number of nodes.

What is working?

The Pastry protocol runs properly in our project with join and route methods.
PastryNode.ex:
This has the handle_casts for the Genserver and is responsible for routing and joining the network.
PastryHelper.ex has the methods used by the handle_casts
MainController.ex is the starting point of the code.

Here is the result obtained for numNodes=100 and numRequests=3
Number of Total Routes: 300
Number of Total Hops: 1014
Average hops per Route: 3.38
** (EXIT from #PID<0.74.0>) shutdown

Results obtained for various numNodes:

NumNodes    NumRequests    Number of routes  Total number of hops  Average Hops
100         3              300                1014                 3.38
500         3              1500               6241                 4.161
700         3              2100               9069                 4.319


What is the largest network you managed to deal with?

We tested the code on 10000 nodes and got the following results:
./project3 10000 10
Number of Total Hops: 654677
Number of Total Routes: 100000
Average hops per route: 6.3466
** (EXIT from #PID<0.74.0>) shutdown

Results for 5000 nodes:

./project3 5000 10
Number of Total Routes: 50000
Number of Total Hops: 295723
Average hops per Route: 5.91446
** (EXIT from #PID<0.74.0>) shutdown




