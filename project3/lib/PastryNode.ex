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

    # API
  
    @doc """
    """
    @name :master
    @base 4

    def startlink(nodeID, numNodes) do
       nodename = String.to_atom("child"<>Integer.to_string(nodeID))
      GenServer.start_link(PastryNode, [nodeID, numNodes], name: nodename, debug: [:statistics, :trace])
      #debug: [:statistics, :trace]
    end

    # SERVER
    def init([nodeID, numNodes]) do
      numBits = round(Float.ceil(:math.log(numNodes)/:math.log(@base)))
      # Initialize routing table to -1
      rowTab = Tuple.duplicate(-1, @base)
      routing_table = Tuple.duplicate(rowTab, numBits)
      numOfBack = 0
      # lesserLeaf = 1
      # largerLeaf = 10000
      {:ok, {nodeID, numNodes, [], [], routing_table, numOfBack}}
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
    

    def tellRoutingNodes(routing_table, i, j, numBits, myID, numOfBack) do
    if i >= numBits or j >= 4 do
        numBits
    else
    node = elem(elem(routing_table, i), j)
       if node != -1 do
            numBits=numBits+1
            GenServer.cast(String.to_atom("child"<>Integer.to_string(node)), {:update_me, myID})
       end
       tellRoutingNodes(routing_table, i, j + 1, numBits, myID, numOfBack)
       if j == 0 do
            tellRoutingNodes(routing_table, i + 1, j, numBits, myID, numOfBack)
       end
       numBits
    end
    end

    def addRow(routing_table, rowNum, newRow, i) do

    IO.puts "addrow"
     if(i==4) do 
        routing_table
     else 
      if elem(elem(routing_table, rowNum),i) == -1 do
        #elem(elem(routing_table, rowNum),i) = elem(newRow,i)
        row = elem(routing_table, rowNum)
        updatedRow = Tuple.insert_at(Tuple.delete_at(row, i), i, elem(newRow, i))
        Tuple.insert_at(Tuple.delete_at(routing_table, rowNum), rowNum, updatedRow)
      end
       addRow(routing_table, rowNum, newRow, i+1)
       routing_table
      end
    end

    @doc """
    """   
    def sendRequest([i | rest], myID, nodeIDSpace) do
        Process.sleep(1000)
        destination = Enum.random(0..nodeIDSpace)
        GenServer.cast(String.to_atom("child"<>Integer.to_string(myID)), {:route, "Route", myID, destination, -1})
        sendRequest(rest, myID, nodeIDSpace)
    end

    def sendRequest([], myID, nodeIDSpace) do
     {:ok}
    end

    def handle_cast({:first_join, firstGroup}, state) do
      {myID, numNodes, lesserLeaf, largerLeaf, routing_table, numOfBack} = state
      numBits = round(Float.ceil(:math.log(numNodes)/:math.log(@base)))
      firstGroup = List.delete(firstGroup, myID)
      {lesserLeaf, largerLeaf, routing_table} = addBuffer(myID, firstGroup, numBits, lesserLeaf, largerLeaf, routing_table)

      for i <- 0..(numBits-1) do
        nextBit = String.to_integer(String.at(toBaseString(myID, numBits), i))
        row = elem(routing_table, i)
        updatedRow = Tuple.insert_at(Tuple.delete_at(row, nextBit), nextBit, myID)
        Tuple.insert_at(Tuple.delete_at(routing_table, i), i, updatedRow)
      end

      GenServer.cast(:global.whereis_name(@name), :join_finish)
      {:noreply, {myID, numNodes, lesserLeaf, largerLeaf, routing_table, numOfBack}}
    end

    def handle_cast({:route, msg, fromId, toId, hops}, state) do
      {myID, numNodes, lesserLeaf, largerLeaf, routing_table, numOfBack} = state
      numBits = round(Float.ceil(:math.log(numNodes)/:math.log(@base)))
      nodeIDSpace = round(Float.ceil(:math.pow(@base, numBits)))
      samePref = samePrefix(toBaseString(myID, numBits), toBaseString(toId, numBits), 0)
      nextBit = String.to_integer(String.at(toBaseString(toId, numBits), samePref))  # last condition

      cond do
        msg=="Join" ->
          samePref = samePrefix(toBaseString(myID, numBits), toBaseString(toId, numBits), 0)
          if(hops == -1 && samePref > 0) do
            for i <- 0..(samePref-1) do
              GenServer.cast(String.to_atom("child"<>Integer.to_string(toId)), {:addRow, i, elem(routing_table,i)})
            end
          end
          GenServer.cast(String.to_atom("child"<>Integer.to_string(toId)), {:addRow, samePref, elem(routing_table, samePref)})
        cond do
          #first condition
          (length(lesserLeaf)>0 && toId >= Enum.min(lesserLeaf) && toId <= myID) || (length(largerLeaf)>0 && toId >= Enum.max(largerLeaf) && toId >= myID) ->        
            diff=nodeIDSpace + 10
            nearest=-1
            nearest = if(toId < myID) do
            for i<-lesserLeaf do
              if(abs(toId - i) < diff) do
                nearest=i
                diff=abs(toId-i)
              end
            end
            else 
              for i<-largerLeaf do
                if(abs(toId - i) < diff) do
                  nearest=i
                  diff=abs(toId-i)
                end
              end
              nearest
            end

            if(abs(toId - myID) > diff) do
              GenServer.cast(String.to_atom("child"<>Integer.to_string(nearest)), {:route,msg,fromId,toId,hops+1}) 
            else #I am the nearest
              allLeaf = []
              allLeaf ++ [myID] ++ [lesserLeaf] ++ [largerLeaf] # check syntax
              GenServer.cast(String.to_atom("child"<>Integer.to_string(toId)), {:add_leaf,allLeaf})
            end 
          #cond else if       
          length(lesserLeaf)<4 && length(lesserLeaf)>0 && toId < Enum.min(lesserLeaf) ->
            GenServer.cast(String.to_atom("child"<>Integer.to_string(Enum.min(lesserLeaf))), {:route,msg,fromId,toId,hops+1})
          length(largerLeaf)<4 && length(largerLeaf)>0 && toId > Enum.max(largerLeaf) ->
            GenServer.cast(String.to_atom("child"<>Integer.to_string(Enum.max(largerLeaf))), {:route,msg,fromId,toId,hops+1})
          length(lesserLeaf)==0 && toId<myID || length(largerLeaf)==0 && toId>myID -> #I am the nearest
            allLeaf = []
            allLeaf ++ [myID] ++ [lesserLeaf]++[largerLeaf] # check syntax
            GenServer.cast(String.to_atom("child"<>Integer.to_string(toId)), {:add_leaf,allLeaf})
          elem(elem(routing_table, samePref), nextBit) != -1 ->
            # row = elem(routing_table, samePref)
            GenServer.cast(String.to_atom("child"<>Integer.to_string(elem(elem(routing_table, samePref), numBits))), {:route,msg,fromId,toId,hops+1})
          toId > myID ->
            GenServer.cast(String.to_atom("child"<>Integer.to_string(Enum.max(largerLeaf))), {:route,msg,fromId,toId,hops+1})
          #not in both
          toId < myID ->
            GenServer.cast(String.to_atom("child"<>Integer.to_string(Enum.max(lesserLeaf))), {:route,msg,fromId,toId,hops+1})
          #not in both ..else condition
          true ->
            IO.puts("Impossible")
        end
        msg=="Route" ->
          #GenServer.cast(String.to_atom("child"<>Integer.to_string(max(largerLeaf)), {:route,fromId,toId,hops+1})
          if myID ==toId do
            GenServer.cast(:global.whereis_name(@name), {:route_finish,fromId,toId,hops+1})# to be implemented
          else 
            samePref = samePrefix(toBaseString(myID, numBits), toBaseString(toId, numBits), 0)
          
          cond do
            #first condition
            (length(lesserLeaf)>0 && toId >= Enum.min(lesserLeaf) && toId <= myID) || (length(largerLeaf)>0 && toId >= Enum.max(largerLeaf) && toId >= myID) ->
              diff=nodeIDSpace + 10
              nearest=-1
              nearest = if(toId < myID) do
                for i<-lesserLeaf do
                  if(abs(toId - i) < diff) do
                    nearest=i
                    diff=abs(toId-i)
                  end
                end
              else 
                for i<-largerLeaf do
                    if(abs(toId - i) < diff) do
                      nearest=i
                      diff=abs(toId-i)
                    end
                end
                nearest
              end

              if(abs(toId - myID) > diff) do
                GenServer.cast(String.to_atom("child"<>Integer.to_string(nearest)), {:route,msg,fromId,toId,hops+1})
              else #I am the nearest
                allLeaf = []
                allLeaf ++ [myID] ++ [lesserLeaf]++[largerLeaf] # check syntax
                GenServer.cast(String.to_atom("child"<>Integer.to_string(toId)), {:add_leaf, allLeaf})
              end                      
              
              length(lesserLeaf)<4 && length(lesserLeaf)>0 && toId < Enum.min(lesserLeaf) ->
                GenServer.cast(String.to_atom("child"<>Integer.to_string(Enum.min(lesserLeaf))), {:route,msg,fromId,toId,hops+1})
              length(largerLeaf)<4 && length(largerLeaf)>0 && toId > Enum.max(largerLeaf) ->
                GenServer.cast(String.to_atom("child"<>Integer.to_string(Enum.max(lesserLeaf))), {:route,msg,fromId,toId,hops+1})
              length(lesserLeaf)==0 && toId<myID || length(largerLeaf)==0 && toId>myID -> #I am the nearest
                allLeaf = []
                allLeaf ++ [myID] ++ [lesserLeaf]++[largerLeaf] # check syntax
                GenServer.cast(String.to_atom("child"<>Integer.to_string(toId)), {:add_leaf,allLeaf})
                elem(elem(routing_table, samePref), nextBit) != -1 ->
                GenServer.cast(String.to_atom("child"<>Integer.to_string(numBits)), {:route,msg,fromId,toId,hops+1})
              toId > myID ->
                GenServer.cast(String.to_atom("child"<>Integer.to_string(Enum.max(largerLeaf))), {:route,msg,fromId,toId,hops+1})
              toId < myID ->
                GenServer.cast(String.to_atom("child"<>Integer.to_string(Enum.max(largerLeaf))), {:route,msg,fromId,toId,hops+1})
              true ->
                IO.puts("Impossible")
          end  #end of cond       
        end #end of route "Route"
      end  #end of cond
      {:noreply, {myID, numNodes, lesserLeaf, largerLeaf, routing_table, numOfBack}}
    end
    
    #Add row
    def handle_cast({:addRow,rowNum,newRow}, state) do
        {myID, numNodes, lesserLeaf, largerLeaf, routing_table, numOfBack} = state
        routing_table=addRow(routing_table,rowNum,newRow,0)   
        {:noreply, {myID, numNodes, lesserLeaf, largerLeaf, routing_table, numOfBack}}
    end

    def handle_cast({:update_me, newNode}, state) do
      {myID, numNodes, lesserLeaf, largerLeaf, routing_table, numOfBack} = state
      numBits = round(Float.ceil(:math.log(numNodes)/:math.log(@base)))
      {lesserLeaf, largerLeaf, routing_table} = addBuffer(myID, [newNode], numBits, lesserLeaf, largerLeaf, routing_table)
      #Send ack
      GenServer.cast(String.to_atom("child"<>Integer.to_string(newNode)), :ack)
      {:noreply, {myID, numNodes, lesserLeaf, largerLeaf, routing_table, numOfBack}}
    end

    def handle_cast({:add_leaf, allLeaf}, state) do
      {myID, numNodes, lesserLeaf, largerLeaf, routing_table, numOfBack} = state
      numBits = round(Float.ceil(:math.log(numNodes)/:math.log(@base)))
      {lesserLeaf, largerLeaf, routing_table} = addBuffer(myID, allLeaf, numBits, lesserLeaf, largerLeaf, routing_table)
      for i <- lesserLeaf do
            GenServer.cast(String.to_atom("child"<>Integer.to_string(i)), {:update_me, myID})
      end
      for i <- largerLeaf do
            GenServer.cast(String.to_atom("child"<>Integer.to_string(i)), {:update_me, myID})
      end
      numOfBack = numOfBack + length(lesserLeaf) + length(largerLeaf)
      # Iterate over the routing_table and call Update_Me on valid entries
        numOfBack = tellRoutingNodes(routing_table, 0, 0, numBits, myID, numOfBack)
      for i <- numBits do
          row = elem(routing_table, i)
          updatedRow = Tuple.insert_at(Tuple.delete_at(row, i), i, myID)
          Tuple.insert_at(Tuple.delete_at(routing_table, i), i, updatedRow)
      end
      {:noreply, {myID, numNodes, lesserLeaf, largerLeaf, routing_table, numOfBack}}
    end

    def handle_cast({:ack}, state) do
      {myID, numNodes, lesserLeaf, largerLeaf, routing_table, numOfBack} = state
      #IO.inspect state
      numOfBack = numOfBack - 1
      if(numOfBack == 0) do
        GenServer.cast(:global.whereis_name(@name), :join_finish)
      end
      {:noreply, {myID, numNodes, lesserLeaf, largerLeaf, routing_table, numOfBack}}
    end

    def handle_cast({:begin_route, numRequests}, state) do
      {myID, numNodes, lesserLeaf, largerLeaf, routing_table, numOfBack} = state
      numBits = round(Float.ceil(:math.log(numNodes)/:math.log(@base)))
      nodeIDSpace = round(Float.ceil(:math.pow(@base, numBits)))
      sendRequest(Enum.to_list(1..numRequests), myID, nodeIDSpace)
      {:noreply, {myID, numNodes, lesserLeaf, largerLeaf, routing_table, numOfBack}}
    end
end