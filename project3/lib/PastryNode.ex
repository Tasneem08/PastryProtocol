defmodule PastryNode do
use GenServer

    # def start_link(nodeId, numNodes, numRequests) do
    #     IO.inspect nodeId
    #     GenServer.start_link(PastryNode, [nodeId, numNodes, numRequests], name: :nodeId)
    # end
     
    # # Maintains a state  nodeId, numNodes, numRequests, nodeMap, lower, higher, routingTable }
    # def init(nodeId, numNodes, numRequests) do
    #     {:ok, {nodeId, numNodes, numRequests, %{}, [], [], [-1,-1,-1,-1] }}
    # end

    use GenServer
    use Application
    
    # API
  
    @doc """
    """
    @name :master
    @base 4
     def start_link(nodeID, numNodes) do
      GenServer.start_link(__MODULE__, {nodeID, numNodes}, [debug: [:statistics, :trace]])
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

    def addBuffer(myID, firstGroup, numBits, lesserLeaf, largerLeaf, routing_table) do

      if length(firstGroup) == 0 do
        {lesserLeaf, largerLeaf, routing_table}
      else
        nodeID = List.first(firstGroup)
        
        # May be added to Larger leaf
        largerLeaf = if (nodeID > myID && !Enum.member?(largerLeaf, nodeID)) do
          if(length(largerLeaf) < 4) do
            largerLeaf ++ [nodeID]
          else
            if (nodeID < Enum.max(largerLeaf)) do
              largerLeaf = List.delete(largerLeaf, Enum.max(largerLeaf))
              largerLeaf ++ [nodeID]
            else
              largerLeaf
            end
          end
        else
          largerLeaf
        end
        
        # May be added to Lesser leaf
        lesserLeaf = if (nodeID < myID && !Enum.member?(lesserLeaf, nodeID)) do
          if(length(lesserLeaf) < 4) do
            lesserLeaf ++ [nodeID]
          else
            if (nodeID > Enum.min(lesserLeaf)) do
              lesserLeaf = List.delete(lesserLeaf, Enum.min(lesserLeaf))
              lesserLeaf ++ [nodeID]
            else
              lesserLeaf
            end
          end
        else
          lesserLeaf
        end
      
        # Check routing table
        samePref = samePrefix(toBaseString(myID, numBits), toBaseString(nodeID, numBits), 0)
        nextBit = String.to_integer(String.at(toBaseString(nodeID, numBits), samePref))
        routing_table = if elem(elem(routing_table, samePref), nextBit) == -1 do
          row = elem(routing_table, samePref)
          updatedRow = Tuple.insert_at(Tuple.delete_at(row, nextBit), nextBit, nodeID)
          Tuple.insert_at(Tuple.delete_at(routing_table, samePref), samePref, updatedRow)
        else
          routing_table
        end
          {lesserLeaf, largerLeaf, routing_table} = addBuffer(myID, List.delete_at(firstGroup, 0), numBits, lesserLeaf, largerLeaf, routing_table)
      end
    end
    
    # SERVER
    def init({myID, numNodes}) do
      numBits = round(Float.ceil(:math.log(numNodes)/:math.log(@base)))
      # Initialize routing table to -1
      rowTab = Tuple.duplicate(-1, @base)
      routing_table = Tuple.duplicate(rowTab, numBits)
      numOfBack = 0
      {:ok, {myID, numNodes, [], [], routing_table, numOfBack}}
    end
    
    def addOne(newNode, myID, numBits, lesserLeaf, largerLeaf, routing_table) do
        largerLeaf = if (newNode > myID && !Enum.member?(largerLeaf, newNode)) do
          if(length(largerLeaf) < 4) do
            largerLeaf ++ [newNode]
          else
            if (newNode < Enum.max(largerLeaf)) do
              largerLeaf = List.delete(largerLeaf, Enum.max(largerLeaf))
              largerLeaf ++ [newNode]
            else
              largerLeaf
            end
          end
        else
          largerLeaf
        end

        lesserLeaf = if (newNode < myID && !Enum.member?(lesserLeaf, newNode)) do
          if(length(lesserLeaf) < 4) do
            lesserLeaf ++ [newNode]
          else
            if (newNode > Enum.min(lesserLeaf)) do
              lesserLeaf = List.delete(lesserLeaf, Enum.min(lesserLeaf))
              lesserLeaf ++ [newNode]
            else
              lesserLeaf
            end
          end
        else
          lesserLeaf
        end

        # Check routing table
        samePref = samePrefix(toBaseString(myID, numBits), toBaseString(newNode, numBits), 0)
        nextBit = String.to_integer(String.at(toBaseString(newNode, numBits), samePref))
        routing_table = if elem(elem(routing_table, samePref), nextBit) == -1 do
          row = elem(routing_table, samePref)
          updatedRow = Tuple.insert_at(Tuple.delete_at(row, nextBit), nextBit, newNode)
          Tuple.insert_at(Tuple.delete_at(routing_table, samePref), samePref, updatedRow)
        else
          routing_table
        end
        {lesserLeaf, largerLeaf, routing_table}
    end
    @doc """
    """   
    def handle_cast({:first_join, firstGroup}, state) do
      {myID, numNodes, lesserLeaf, largerLeaf, routing_table, numOfBack} = state
      numBits = round(Float.ceil(:math.log(numNodes)/:math.log(@base)))
      firstGroup = List.delete(firstGroup, myID)
      {lesserLeaf, largerLeaf, routing_table} = addBuffer(myID, firstGroup, numBits, lesserLeaf, largerLeaf, routing_table)
      {:noreply, {myID, numNodes, lesserLeaf, largerLeaf, routing_table, numOfBack}}
    end

    def handle_cast({:update_me, newNode}, state) do
      {myID, numNodes, lesserLeaf, largerLeaf, routing_table, numOfBack} = state
      numBits = round(Float.ceil(:math.log(numNodes)/:math.log(@base)))
      {lesserLeaf, largerLeaf, routing_table} = addOne(newNode, myID, numBits, lesserLeaf, largerLeaf, routing_table)
      # Send ack
      {:noreply, {myID, numNodes, lesserLeaf, largerLeaf, routing_table, numOfBack}}
    end

end