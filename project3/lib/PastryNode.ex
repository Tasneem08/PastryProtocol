defmodule PastryNode do
use GenServer

    def start_link(nodeId, numNodes, numRequests) do
        IO.inspect nodeId
        GenServer.start_link(PastryNode, [nodeId, numNodes, numRequests], name: :nodeId)
    end
     
    # Maintains a state  nodeId, numNodes, numRequests, nodeMap, lower, higher, routingTable }
    def init(nodeId, numNodes, numRequests) do
        {:ok, {nodeId, numNodes, numRequests, %{}, [], [], [-1,-1,-1,-1] }}
    end

    # def handle_cast({:join, msg, key}, _from , state)) do

    # end
    # lower
    # larger
    # list (list) for routing table

end