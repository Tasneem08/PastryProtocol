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
      GenServer.start_link(PastryNode, [nodeID, numNodes], name: nodename)
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

    def leafRecover([], myID, lesserLeaf, largerLeaf) do
    { lesserLeaf, largerLeaf}
    end

    def leafRecover([nodeID | newList], myID, lesserLeaf, largerLeaf) do
      IO.inspect newList
      IO.inspect largerLeaf
      largerLeaf = if nodeID > myID && largerLeaf != nil && !Enum.member?(largerLeaf, nodeID) do
        if length(largerLeaf) < 4 do
          largerLeaf ++ [nodeID]
        else
          if nodeID < Enum.max(largerLeaf) do
            largerLeaf = List.delete(largerLeaf, Enum.max(largerLeaf))
            largerLeaf ++ [nodeID]
          end
        end
      end
            
      lesserLeaf = if nodeID < myID && lesserLeaf != nil && !Enum.member?(lesserLeaf, nodeID) do
        if length(lesserLeaf) < 4 do
          lesserLeaf ++ [nodeID]
        else
          if nodeID > Enum.min(lesserLeaf) do
            lesserLeaf = List.delete(lesserLeaf, Enum.min(lesserLeaf))
            lesserLeaf ++ [nodeID]
          end
        end
      end
       leafRecover(newList, myID, lesserLeaf, largerLeaf)
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

     def handle_cast({:requestInTable, samePre,column}, state) do
      {myID, numNodes, lesserLeaf, largerLeaf, routing_table, numOfBack} = state
      
      if ((elem(elem(routing_table, samePre), column)) != -1) do
        GenServer.cast(:global.whereis_name(@name), {:table_recover,samePre,elem(elem(routing_table, samePre), column)})   
      end

      {:noreply, {myID, numNodes, lesserLeaf, largerLeaf, routing_table, numOfBack}}
     end


     def handle_cast({:table_recover, row1, column ,newId}, state) do
      {myID, numNodes, lesserLeaf, largerLeaf, routing_table, numOfBack} = state
        routing_table=if ((elem(elem(routing_table, row1), column)) != -1) do
            row = elem(routing_table, row1)
            updatedRow = Tuple.insert_at(Tuple.delete_at(row, column), column, newId)
            Tuple.insert_at(Tuple.delete_at(routing_table, row), row, updatedRow)
            routing_table        
        end
      {:noreply, {myID, numNodes, lesserLeaf, largerLeaf, routing_table, numOfBack}}
     end


    def handle_cast({:remove_me, theId}, state) do
      {myID, numNodes, lesserLeaf, largerLeaf, routing_table, numOfBack} = state
      numBits = round(Float.ceil(:math.log(numNodes)/:math.log(@base)))
          if theId > myID && Enum.member?(largerLeaf, theId) do
              List.delete(largerLeaf,theId)
              if length(largerLeaf) > 0 do
                GenServer.cast(String.to_atom("child"<>Integer.to_string(Enum.max(largerLeaf))), {:request_leaf_without, theId,myID})
              end
          end

          if theId < myID && Enum.member?(lesserLeaf, theId) do
              List.delete(lesserLeaf,theId)
              if length(lesserLeaf) > 0 do
                GenServer.cast(String.to_atom("child"<>Integer.to_string(Enum.min(largerLeaf))), {:request_leaf_without, theId,myID})
              end
          end

        samePref = samePrefix(toBaseString(myID, numBits), toBaseString(theId, numBits), 0)
        nextBit = String.to_integer(String.at(toBaseString(theId, numBits), samePref))

          routing_table = if elem(elem(routing_table, samePref), nextBit) == theId do
              row = elem(routing_table, samePref)
              updatedRow = Tuple.insert_at(Tuple.delete_at(row, nextBit), nextBit, -1)
              Tuple.insert_at(Tuple.delete_at(routing_table, samePref), samePref, updatedRow)
            else
              routing_table
            end

          for i <- 0..3 do
            if ((elem(elem(routing_table, samePref), i)) != myID && elem(elem(routing_table, samePref), i) != theId && elem(elem(routing_table, samePref), i) != -1) do
              GenServer.cast(String.to_atom("child"<>Integer.to_string(elem(elem(routing_table, samePref), i))), {:requestInTable, samePref ,nextBit})
            end   
          end
          
          {:noreply, {myID, numNodes, lesserLeaf, largerLeaf, routing_table, numOfBack}}
        end


    def handle_cast({:route, msg, fromId, toId, hops}, state) do
      {myID, numNodes, lesserLeaf, largerLeaf, routing_table, numOfBack} = state
      numBits = round(Float.ceil(:math.log(numNodes)/:math.log(@base)))
      nodeIDSpace = round(Float.ceil(:math.pow(@base, numBits)))

     if  msg=="Join" do
          samePref = samePrefix(toBaseString(myID, numBits), toBaseString(toId, numBits), 0)
          nextBit = String.to_integer(String.at(toBaseString(toId, numBits), samePref))
          if(hops == 0 && samePref > 0) do
            for i <- 0..(samePref-1) do
            GenServer.cast(String.to_atom("child"<>Integer.to_string(toId)), {:addRow, i, elem(routing_table,i)})
            end
          end
          GenServer.cast(String.to_atom("child"<>Integer.to_string(toId)), {:addRow, samePref, elem(routing_table, samePref)})

        cond do
          #first condition
          (length(lesserLeaf)>0 && toId >= Enum.min(lesserLeaf) && toId <= myID) || (length(largerLeaf)>0 && toId <= Enum.max(largerLeaf) && toId >= myID) ->        
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
              # IO.puts "in leaf"
              allLeaf = []
              allLeaf ++ [myID] ++ [lesserLeaf] ++ [largerLeaf] # check syntax
              GenServer.cast(String.to_atom("child"<>Integer.to_string(toId)), {:add_leaf,allLeaf})
            end 
          #cond else if       
          length(lesserLeaf)<4 && length(lesserLeaf)>0 && toId < Enum.min(lesserLeaf) ->
            GenServer.cast(String.to_atom("child"<>Integer.to_string(Enum.min(lesserLeaf))), {:route,msg,fromId,toId,hops+1})
          length(largerLeaf)<4 && length(largerLeaf)>0 && toId > Enum.max(largerLeaf) ->
            GenServer.cast(String.to_atom("child"<>Integer.to_string(Enum.max(largerLeaf))), {:route,msg,fromId,toId,hops+1})
          (length(lesserLeaf)==0 && toId<myID) || (length(largerLeaf)==0 && toId>myID) -> #I am the nearest
            # IO.puts "in leaf"
            allLeaf = []
            allLeaf ++ [myID] ++ [lesserLeaf]++[largerLeaf] # check syntax
            # GenServer.whereis(String.to_atom("child"<>Integer.to_string(toId)))
            GenServer.cast(String.to_atom("child"<>Integer.to_string(toId)), {:add_leaf,allLeaf})
          elem(elem(routing_table, samePref), nextBit) != -1 ->
            # row = elem(routing_table, samePref)
            GenServer.cast(String.to_atom("child"<>Integer.to_string(elem(elem(routing_table, samePref), nextBit))), {:route,msg,fromId,toId,hops+1})
          toId > myID ->
            GenServer.cast(String.to_atom("child"<>Integer.to_string(Enum.max(largerLeaf))), {:route,msg,fromId,toId,hops+1})
          #not in both
          toId < myID ->
            GenServer.cast(String.to_atom("child"<>Integer.to_string(Enum.min(lesserLeaf))), {:route,msg,fromId,toId,hops+1})
          #not in both ..else condition
          true ->
            IO.puts("Impossible")
        end
     else
        # msg=="Route" ->
        # IO.inspect "My id is #{myID} and destination is #{toId}"
          if myID == toId do
            # IO.inspect "Reached Real Destination!"
            GenServer.cast(:global.whereis_name(@name), {:route_finish,fromId,toId,hops+1})# to be implemented
          else 
            samePref = samePrefix(toBaseString(myID, numBits), toBaseString(toId, numBits), 0)
            nextBit = String.to_integer(String.at(toBaseString(toId, numBits), samePref))
          cond do
            #first condition
            (length(lesserLeaf)>0 && toId >= Enum.min(lesserLeaf) && toId < myID) || (length(largerLeaf)>0 && toId <= Enum.max(largerLeaf) && toId > myID) ->
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
                GenServer.cast(String.to_atom("child"<>Integer.to_string(nearest)), {:route,"Route",fromId,toId,hops+1})
              else #I am the nearest
                GenServer.cast(:global.whereis_name(@name), {:route_finish,fromId,toId,hops+1})
              end                      
              
              length(lesserLeaf)<4 && length(lesserLeaf)>0 && toId < Enum.min(lesserLeaf) ->
                GenServer.cast(String.to_atom("child"<>Integer.to_string(Enum.min(lesserLeaf))), {:route,"Route",fromId,toId,hops+1})
              length(largerLeaf)<4 && length(largerLeaf)>0 && toId > Enum.max(largerLeaf) ->
                GenServer.cast(String.to_atom("child"<>Integer.to_string(Enum.max(largerLeaf))), {:route,"Route",fromId,toId,hops+1})
              (length(lesserLeaf)==0 && toId<myID) || (length(largerLeaf)==0 && toId>myID) -> #I am the nearest
                GenServer.cast(:global.whereis_name(@name), {:route_finish,fromId,toId,hops+1})
               elem(elem(routing_table, samePref), nextBit) != -1 ->
                GenServer.cast(String.to_atom("child"<>Integer.to_string(elem(elem(routing_table, samePref), nextBit))), {:route,"Route",fromId,toId,hops+1})
              toId > myID ->
                GenServer.cast(String.to_atom("child"<>Integer.to_string(Enum.max(largerLeaf))), {:route,"Route",fromId,toId,hops+1})
              toId < myID ->
                GenServer.cast(String.to_atom("child"<>Integer.to_string(Enum.min(lesserLeaf))), {:route,"Route",fromId,toId,hops+1})
              true ->
                IO.puts("Impossible")
          end  #end of cond       
        end #end of if myId = toId
      end  #end of cond
      {:noreply, {myID, numNodes, lesserLeaf, largerLeaf, routing_table, numOfBack}}
    end
    
    #Add row
    def handle_cast({:addRow,rowNum,newRow}, state) do 
      #  IO.inspect "Updating #{rowNum}th row."
        {myID, numNodes, lesserLeaf, largerLeaf, routing_table, numOfBack} = state
        routing_table =  Tuple.insert_at(Tuple.delete_at(routing_table, rowNum), rowNum, newRow)  
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
      # IO.puts "In addLeaf"
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
      for i <- 0..(numBits-1) do
        for j <- 0..3 do
          row = elem(routing_table, i)
          updatedRow = Tuple.insert_at(Tuple.delete_at(row, j), j, myID)
          Tuple.insert_at(Tuple.delete_at(routing_table, i), i, updatedRow)
        end
      end
      {:noreply, {myID, numNodes, lesserLeaf, largerLeaf, routing_table, numOfBack}}
    end

    def handle_cast(:ack, state) do
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

    def handle_cast({:leaf_recover, newList}, state) do
      {myID, numNodes, lesserLeaf, largerLeaf, routing_table, numOfBack} = state
      {lesserLeaf, largerLeaf} = leafRecover(newList, myID, lesserLeaf, largerLeaf)
      {:noreply, {myID, numNodes, lesserLeaf, largerLeaf, routing_table, numOfBack}}
    end

    def handle_cast({:request_leaf_without, theID, sender}, state) do
      {myID, numNodes, lesserLeaf, largerLeaf, routing_table, numOfBack} = state 
      temp = []
      temp = temp ++ [lesserLeaf] ++ [largerLeaf]
      temp = List.delete(temp,theID)
      GenServer.cast(String.to_atom("child"<>Integer.to_string(sender)), {:leaf_recover, temp})
      {:noreply, {myID, numNodes, lesserLeaf, largerLeaf, routing_table, numOfBack}}
    end
    
    def handle_cast({:killYourself, randList}, state) do
      {myID, numNodes, lesserLeaf, largerLeaf, routing_table, numOfBack} = state
      randList = List.delete(randList, myID)
      for i<- randList do
       GenServer.cast(String.to_atom("child"<>Integer.to_string(i)), {:remove_me, myID})
      end
      Process.exit(self(), :kill)
      {:noreply, {myID, numNodes, lesserLeaf, largerLeaf, routing_table, numOfBack}}
    end

end