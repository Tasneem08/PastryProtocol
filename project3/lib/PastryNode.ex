defmodule PastryNode do
use GenServer

    @name :master
    @base 4

    def startlink(nodeID, numNodes) do
      nodename = String.to_atom("child"<>Integer.to_string(nodeID))
      GenServer.start_link(PastryNode, [nodeID, numNodes], name: nodename)
    end

    def init([nodeID, numNodes]) do

      numberOfBits = round(Float.ceil(:math.log(numNodes)/:math.log(@base)))
     
      rowTab = Tuple.duplicate(-1, @base)
      routingTable = Tuple.duplicate(rowTab, numberOfBits)
      numOfBack = 0
      {:ok, {nodeID, numNodes, [], [], routingTable, numOfBack}}
    end


    def handle_cast({:route, message, fromId, toId, hops}, state) do
      {myID, numNodes, minLeafSet, maxLeafSet, routingTable, numOfBack} = state
      numberOfBits = round(Float.ceil(:math.log(numNodes)/:math.log(@base)))
      node_IdSpace = round(Float.ceil(:math.pow(@base, numberOfBits)))

     if  message=="Join" do
          equiPref = PastryHelper.equiPrefix(PastryHelper.convertToBaseString(myID, numberOfBits), PastryHelper.convertToBaseString(toId, numberOfBits), 0)
          nextBit = String.to_integer(String.at(PastryHelper.convertToBaseString(toId, numberOfBits), equiPref))
          if(hops == 0 && equiPref > 0) do
            for i <- 0..(equiPref-1) do
            GenServer.cast(String.to_atom("child"<>Integer.to_string(toId)), {:add_new_row, i, elem(routingTable,i)})
            end
          end
          GenServer.cast(String.to_atom("child"<>Integer.to_string(toId)), {:add_new_row, equiPref, elem(routingTable, equiPref)})

        cond do
          #first condition
          (length(minLeafSet)>0 && toId >= Enum.min(minLeafSet) && toId <= myID) || (length(maxLeafSet)>0 && toId <= Enum.max(maxLeafSet) && toId >= myID) ->        
            diff=node_IdSpace + 10
            nearest=-1
            {nearest,diff} = if(toId < myID) do
                 PastryHelper.findNearest(minLeafSet, toId, nearest, diff)
            else 
                 PastryHelper.findNearest(maxLeafSet, toId, nearest, diff)
            end

            if(abs(toId - myID) > diff) do
              GenServer.cast(String.to_atom("child"<>Integer.to_string(nearest)), {:route,message,fromId,toId,hops+1}) 
            else #I am the nearest
              # IO.puts "in leaf"
              allLeaf = [myID] ++ minLeafSet ++ maxLeafSet # check syntax
              GenServer.cast(String.to_atom("child"<>Integer.to_string(toId)), {:add_leaf,allLeaf})
            end 
          #cond else if       
          length(minLeafSet)<4 && length(minLeafSet)>0 && toId < Enum.min(minLeafSet) ->
            GenServer.cast(String.to_atom("child"<>Integer.to_string(Enum.min(minLeafSet))), {:route,message,fromId,toId,hops+1})
          length(maxLeafSet)<4 && length(maxLeafSet)>0 && toId > Enum.max(maxLeafSet) ->
            GenServer.cast(String.to_atom("child"<>Integer.to_string(Enum.max(maxLeafSet))), {:route,message,fromId,toId,hops+1})
          (length(minLeafSet)==0 && toId<myID) || (length(maxLeafSet)==0 && toId>myID) -> #I am the nearest
            # IO.puts "in leaf"
            allLeaf = [myID] ++ minLeafSet ++ maxLeafSet # check syntax
            GenServer.cast(String.to_atom("child"<>Integer.to_string(toId)), {:add_leaf,allLeaf})
          elem(elem(routingTable, equiPref), nextBit) != -1 ->
            # row = elem(routingTable, equiPref)
            GenServer.cast(String.to_atom("child"<>Integer.to_string(elem(elem(routingTable, equiPref), nextBit))), {:route,message,fromId,toId,hops+1})
          toId > myID ->
            GenServer.cast(String.to_atom("child"<>Integer.to_string(Enum.max(maxLeafSet))), {:route,message,fromId,toId,hops+1})
          #not in both
          toId < myID ->
            GenServer.cast(String.to_atom("child"<>Integer.to_string(Enum.min(minLeafSet))), {:route,message,fromId,toId,hops+1})
          #not in both ..else condition
          true ->
            IO.puts("Impossible")
        end
     else
        # message=="Route" ->
          if myID == toId do
            GenServer.cast(:global.whereis_name(@name), {:route_finish,hops+1})# to be implemented
          else 
            equiPref = PastryHelper.equiPrefix(PastryHelper.convertToBaseString(myID, numberOfBits), PastryHelper.convertToBaseString(toId, numberOfBits), 0)
            nextBit = String.to_integer(String.at(PastryHelper.convertToBaseString(toId, numberOfBits), equiPref))
          cond do
            #first condition
            (length(minLeafSet)>0 && toId >= Enum.min(minLeafSet) && toId < myID) || (length(maxLeafSet)>0 && toId <= Enum.max(maxLeafSet) && toId > myID) ->
              diff=node_IdSpace + 10
              nearest=-1
              {nearest,diff} = if(toId < myID) do
                 PastryHelper.findNearest(minLeafSet, toId, nearest, diff)
            else 
                 PastryHelper.findNearest(maxLeafSet, toId, nearest, diff)
            end

              if(abs(toId - myID) > diff) do
                GenServer.cast(String.to_atom("child"<>Integer.to_string(nearest)), {:route,"Route",fromId,toId,hops+1})
              else #I am the nearest
                GenServer.cast(:global.whereis_name(@name), {:route_finish,hops+1})
              end                      
              
              length(minLeafSet)<4 && length(minLeafSet)>0 && toId < Enum.min(minLeafSet) ->
                GenServer.cast(String.to_atom("child"<>Integer.to_string(Enum.min(minLeafSet))), {:route,"Route",fromId,toId,hops+1})
              length(maxLeafSet)<4 && length(maxLeafSet)>0 && toId > Enum.max(maxLeafSet) ->
                GenServer.cast(String.to_atom("child"<>Integer.to_string(Enum.max(maxLeafSet))), {:route,"Route",fromId,toId,hops+1})
              (length(minLeafSet)==0 && toId<myID) || (length(maxLeafSet)==0 && toId>myID) -> #I am the nearest
                GenServer.cast(:global.whereis_name(@name), {:route_finish,hops+1})
               elem(elem(routingTable, equiPref), nextBit) != -1 ->
                GenServer.cast(String.to_atom("child"<>Integer.to_string(elem(elem(routingTable, equiPref), nextBit))), {:route,"Route",fromId,toId,hops+1})
              toId > myID ->
                GenServer.cast(String.to_atom("child"<>Integer.to_string(Enum.max(maxLeafSet))), {:route,"Route",fromId,toId,hops+1})
              toId < myID ->
                GenServer.cast(String.to_atom("child"<>Integer.to_string(Enum.min(minLeafSet))), {:route,"Route",fromId,toId,hops+1})
              true ->
                IO.puts("Impossible")
          end  #end of cond       


        end #end of if myId = toId
        
      end  #end of cond
      {:noreply, {myID, numNodes, minLeafSet, maxLeafSet, routingTable, numOfBack}}
    end
    
    #Add row
    def handle_cast({:add_new_row,rowNum,newRow}, state) do 
        {myID, numNodes, minLeafSet, maxLeafSet, routingTable, numOfBack} = state
        routingTable =  Tuple.insert_at(Tuple.delete_at(routingTable, rowNum), rowNum, newRow)  
        {:noreply, {myID, numNodes, minLeafSet, maxLeafSet, routingTable, numOfBack}}
    end

    def handle_cast({:pastryInit, firstEntries}, state) do
      {myID, numNodes, minLeafSet, maxLeafSet, routingTable, numOfBack} = state
      numberOfBits = round(Float.ceil(:math.log(numNodes)/:math.log(@base)))
      firstEntries = List.delete(firstEntries, myID)
      {minLeafSet, maxLeafSet, routingTable} = PastryHelper.addEntries(myID, firstEntries, numberOfBits, minLeafSet, maxLeafSet, routingTable)

      for i <- 0..(numberOfBits-1) do
        nextBit = String.to_integer(String.at(PastryHelper.convertToBaseString(myID, numberOfBits), i))
        row = elem(routingTable, i)
        updatedRow = Tuple.insert_at(Tuple.delete_at(row, nextBit), nextBit, myID)
        Tuple.insert_at(Tuple.delete_at(routingTable, i), i, updatedRow)
      end

      GenServer.cast(:global.whereis_name(@name), :join_finish)
      {:noreply, {myID, numNodes, minLeafSet, maxLeafSet, routingTable, numOfBack}}
    end


    def handle_cast({:add_leaf, allLeaf}, state) do
      # IO.puts "In addLeaf"
      {myID, numNodes, minLeafSet, maxLeafSet, routingTable, numOfBack} = state
      numberOfBits = round(Float.ceil(:math.log(numNodes)/:math.log(@base)))
      {minLeafSet, maxLeafSet, routingTable} = PastryHelper.addEntries(myID, allLeaf, numberOfBits, minLeafSet, maxLeafSet, routingTable)
      for i <- minLeafSet do
            GenServer.cast(String.to_atom("child"<>Integer.to_string(i)), {:update_me, myID})
      end
      for i <- maxLeafSet do
            GenServer.cast(String.to_atom("child"<>Integer.to_string(i)), {:update_me, myID})
      end
      numOfBack = numOfBack + length(minLeafSet) + length(maxLeafSet)
      # Iterate over the routingTable and call Update_Me on valid entries
        numOfBack = PastryHelper.inform_nodes(routingTable, 0, 0, numberOfBits, myID, numOfBack)
      for i <- 0..(numberOfBits-1) do
        for j <- 0..3 do
          row = elem(routingTable, i)
          updatedRow = Tuple.insert_at(Tuple.delete_at(row, j), j, myID)
          Tuple.insert_at(Tuple.delete_at(routingTable, i), i, updatedRow)
        end
      end
      {:noreply, {myID, numNodes, minLeafSet, maxLeafSet, routingTable, numOfBack}}
    end

    def handle_cast(:ack, state) do
      {myID, numNodes, minLeafSet, maxLeafSet, routingTable, numOfBack} = state
      #IO.inspect state
      numOfBack = numOfBack - 1
      if(numOfBack == 0) do
        GenServer.cast(:global.whereis_name(@name), :join_finish)
      end
      {:noreply, {myID, numNodes, minLeafSet, maxLeafSet, routingTable, numOfBack}}
    end

    
    def handle_cast({:update_me, newNode}, state) do
      {myID, numNodes, minLeafSet, maxLeafSet, routingTable, numOfBack} = state
      numberOfBits = round(Float.ceil(:math.log(numNodes)/:math.log(@base)))
      {minLeafSet, maxLeafSet, routingTable} = PastryHelper.addEntries(myID, [newNode], numberOfBits, minLeafSet, maxLeafSet, routingTable)
      #Send ack
      GenServer.cast(String.to_atom("child"<>Integer.to_string(newNode)), :ack)
      {:noreply, {myID, numNodes, minLeafSet, maxLeafSet, routingTable, numOfBack}}
    end

    def handle_cast({:begin_routing, numRequests}, state) do
      {myID, numNodes, minLeafSet, maxLeafSet, routingTable, numOfBack} = state
      numberOfBits = round(Float.ceil(:math.log(numNodes)/:math.log(@base)))
      node_IdSpace = round(Float.ceil(:math.pow(@base, numberOfBits)))
      PastryHelper.transmit_request(Enum.to_list(1..numRequests), myID, node_IdSpace)
      {:noreply, {myID, numNodes, minLeafSet, maxLeafSet, routingTable, numOfBack}}
    end
end