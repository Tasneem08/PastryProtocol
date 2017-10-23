defmodule PastryHelper do

  @base 4

    def convertToBaseString(nodeID, len) do
      baseNodeID = Integer.to_string(nodeID, @base)
      String.pad_leading(baseNodeID, len, "0")
    end
    
    def findNearest([neighbor | rest], toId, nearest, diff) do
        if(abs(toId - neighbor) < diff) do
                nearest=neighbor
                diff=abs(toId-neighbor)
        end
        findNearest(rest, toId, nearest, diff)
    end
    
    def findNearest([], toId, nearest, diff) do
       {nearest, diff}
    end

    def inform_nodes(routingTable, i, j, numberOfBits, myNodeID, numOfBack) do
    if i >= numberOfBits or j >= 4 do
        numOfBack
    else
       node = elem(elem(routingTable, i), j)
       if node != -1 do
            numOfBack=numOfBack+1
            GenServer.cast(String.to_atom("child"<>Integer.to_string(node)), {:update_me, myNodeID})
       end
       numOfBack = inform_nodes(routingTable, i, j + 1, numberOfBits, myNodeID, numOfBack)
       if j == 0 do
            numOfBack = inform_nodes(routingTable, i + 1, j, numberOfBits, myNodeID, numOfBack)
       end
       numOfBack
    end
    end

    def equiPrefix(node1, node2, bit_position) do
      if String.first(node1) != String.first(node2) do
        bit_position
      else
        equiPrefix(String.slice(node1, 1..(String.length(node1)-1)), String.slice(node2, 1..(String.length(node2)-1)), bit_position+1)
      end   
    end

    
  def addEntries(myNodeID, firstEntries, numberOfBits, minLeafSet, maxLeafSet, routingTable) do

      if length(firstEntries) == 0 do

        {minLeafSet, maxLeafSet, routingTable}

      else
      # add to Larger leaf set
        node_id = List.first(firstEntries)        
        
        maxLeafSet = if (node_id > myNodeID && !Enum.member?(maxLeafSet, node_id)) do

          if(length(maxLeafSet) < 4) do
            maxLeafSet ++ [node_id]
            
          else
            if (node_id < Enum.max(maxLeafSet)) do

              maxLeafSet = List.delete(maxLeafSet, Enum.max(maxLeafSet))
              maxLeafSet ++ [node_id]
              
            else
              maxLeafSet
            end
          end
        else
          maxLeafSet
        end
        
        # add to Lesser leaf
        minLeafSet = if (!Enum.member?(minLeafSet, node_id) && node_id < myNodeID ) do
          if(length(minLeafSet) < 4) do
            minLeafSet ++ [node_id]
          else
            if (node_id > Enum.min(minLeafSet)) do
              minLeafSet = List.delete(minLeafSet, Enum.min(minLeafSet))
                minLeafSet ++ [node_id]
            else
              minLeafSet
            end
          end
        else
          minLeafSet
        end
      
        
        equiPref = equiPrefix(convertToBaseString(myNodeID, numberOfBits), convertToBaseString(node_id, numberOfBits), 0) # routing table chk
        nextBit = String.to_integer(String.at(convertToBaseString(node_id, numberOfBits), equiPref))

        routingTable = if elem(elem(routingTable, equiPref), nextBit) == -1 do

          row_elem = elem(routingTable, equiPref)
          added_row = Tuple.insert_at(Tuple.delete_at(row_elem, nextBit), nextBit, node_id)
          Tuple.insert_at(Tuple.delete_at(routingTable, equiPref), equiPref, added_row)

        else
          routingTable
        end

          addEntries(myNodeID, List.delete_at(firstEntries, 0), numberOfBits, minLeafSet, maxLeafSet, routingTable)
    #  {minLeafSet, maxLeafSet, routingTable} = 
      end
    end

    def transmit_request([i | remaining_items], myNodeID, node_IdSpace) do
        Process.sleep(920)
        neighbor_list = Enum.to_list(0..node_IdSpace-1)

        destination = Enum.random(List.delete(neighbor_list, myNodeID))

        GenServer.cast(String.to_atom("child"<>Integer.to_string(myNodeID)), {:route, "Route", myNodeID, destination, 0})

        transmit_request(remaining_items, myNodeID, node_IdSpace)
    end

    def transmit_request([], myNodeID, node_IdSpace) do
     {:ok}
    end

    def leafRecover([], myID, lesserLeaf, largerLeaf) do
       {lesserLeaf, largerLeaf}
    end

   def leafRecover([nodeID | newList], myID, lesserLeaf, largerLeaf) do
      largerLeaf = if nodeID > myID && largerLeaf != nil && !Enum.member?(largerLeaf, nodeID) do
        if length(largerLeaf) < 4 do
          largerLeaf ++ [nodeID]
        else
          if nodeID < Enum.max(largerLeaf) do
            largerLeaf = List.delete(largerLeaf, Enum.max(largerLeaf))
            largerLeaf ++ [nodeID]
          else
            largerLeaf
          end
        end
      else
        largerLeaf
      end
            
      lesserLeaf = if nodeID < myID && lesserLeaf != nil && !Enum.member?(lesserLeaf, nodeID) do
        if length(lesserLeaf) < 4 do
          lesserLeaf ++ [nodeID]
        else
          if nodeID > Enum.min(lesserLeaf) do
            lesserLeaf = List.delete(lesserLeaf, Enum.min(lesserLeaf))
            lesserLeaf ++ [nodeID]
          else 
            lesserLeaf
          end
        end
      else
        lesserLeaf
      end
       leafRecover(newList, myID, lesserLeaf, largerLeaf)
    end

end