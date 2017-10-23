defmodule PastryHelper do

  @name :master
  @base 4
  
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
    

    def tellRoutingNodes(routing_table, i, j, numBits, myID, numOfBack) do
    if i >= numBits or j >= 4 do
        numOfBack
    else
       node = elem(elem(routing_table, i), j)
       if node != -1 do
            numOfBack=numOfBack+1
            GenServer.cast(String.to_atom("child"<>Integer.to_string(node)), {:update_me, myID})
       end
       numOfBack = tellRoutingNodes(routing_table, i, j + 1, numBits, myID, numOfBack)
       if j == 0 do
            numOfBack = tellRoutingNodes(routing_table, i + 1, j, numBits, myID, numOfBack)
       end
       numOfBack
    end
    end

    def addRow(routing_table, rowNum, newRow, i) do
        routing_table = Tuple.insert_at(Tuple.delete_at(routing_table, rowNum), rowNum, newRow)
    end

    @doc """
    """   
    def sendRequest([i | rest], myID, nodeIDSpace) do
        Process.sleep(1000)
        listneigh = Enum.to_list(0..nodeIDSpace-1)
        destination = Enum.random(List.delete(listneigh, myID))
        if destination == myID do
          IO.inspect "@@@@@@@@@@@@@  PICKED SAME DEST  @@@@@@@@@@@@"
        end
        GenServer.cast(String.to_atom("child"<>Integer.to_string(myID)), {:route, "Route", myID, destination, 0})
        sendRequest(rest, myID, nodeIDSpace)
    end

    def sendRequest([], myID, nodeIDSpace) do
     {:ok}
    end
end