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

    def init(myID, numNodes) do
      numBits = round(Float.ceil(:math.log(numNodes)/:math.log(@base)))
      # Initialize routing table to -1
      rowTab = Tuple.duplicate(-1, @base)
      routing_table = Tuple.duplicate(rowTab, numBits)
      {:ok, {myID, numNodes, [], [], routing_table}}
    end

    def samePrefix(nodeID1, nodeID2, bitPos) do
      if String.first(nodeID1) != String.first(nodeID2) do
        bitPos
      else
        samePrefix(String.slice(nodeID1, 1..(String.length(nodeID1)-1)), String.slice(nodeID2, 1..(String.length(nodeID2)-1)), bitPos+1)
      end   
    end

    def toBaseString(nodeID, len) do
      baseNodeID = Integer.to_string(nodeID, @base)
      String.pad_leading(baseNodeID, len, "0")
    end

end