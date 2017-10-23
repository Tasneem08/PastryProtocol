defmodule PastryNode do
use GenServer

    @name :master
    @base 4

     def handle_cast({:requestInTable, samePre, column, sender}, state) do
      {myID, numNodes, lesserLeaf, largerLeaf, routing_table, numOfBack} = state
      
      if ((elem(elem(routing_table, samePre), column)) != -1) do
        GenServer.cast(String.to_atom("child"<>Integer.to_string(sender)), {:table_recover, samePre, column, elem(elem(routing_table, samePre), column)})   
      end

      {:noreply, {myID, numNodes, lesserLeaf, largerLeaf, routing_table, numOfBack}}
     end


     def handle_cast({:table_recover, row1, column ,newId}, state) do
    #  IO.inspect "row = #{row1}, column = #{column}"
      {myID, numNodes, lesserLeaf, largerLeaf, routing_table, numOfBack} = state
      # IO.inspect (elem(elem(routing_table, row1), column))
        if ((elem(elem(routing_table, row1), column)) == -1) do
            # IO.inspect "in here"
            row = elem(routing_table, row1)
            updatedRow = Tuple.insert_at(Tuple.delete_at(row, column), column, newId)
           # routing_table = 
           Tuple.insert_at(Tuple.delete_at(routing_table, row1), row1, updatedRow)     
        end
      {:noreply, {myID, numNodes, lesserLeaf, largerLeaf, routing_table, numOfBack}}
     end


    def handle_cast({:remove_me, theId}, state) do
      {myID, numNodes, lesserLeaf, largerLeaf, routing_table, numOfBack} = state
      numBits = round(Float.ceil(:math.log(numNodes)/:math.log(@base)))
          if theId > myID && Enum.member?(largerLeaf, theId) do
              largerLeaf = List.delete(largerLeaf,theId)
              if length(largerLeaf) > 0 do
                GenServer.cast(String.to_atom("child"<>Integer.to_string(Enum.max(largerLeaf))), {:request_leaf_without, theId,myID})
              end
          end

          if theId < myID && Enum.member?(lesserLeaf, theId) do
              lesserLeaf = List.delete(lesserLeaf,theId)
              if length(lesserLeaf) > 0 do
                GenServer.cast(String.to_atom("child"<>Integer.to_string(Enum.min(lesserLeaf))), {:request_leaf_without, theId,myID})
              end
          end

        samePref = PastryHelper.equiPrefix(PastryHelper.convertToBaseString(myID, numBits), PastryHelper.convertToBaseString(theId, numBits), 0)
        nextBit = String.to_integer(String.at(PastryHelper.convertToBaseString(theId, numBits), samePref))

          routing_table = if elem(elem(routing_table, samePref), nextBit) == theId do
              row = elem(routing_table, samePref)
              updatedRow = Tuple.insert_at(Tuple.delete_at(row, nextBit), nextBit, -1)
              Tuple.insert_at(Tuple.delete_at(routing_table, samePref), samePref, updatedRow)
            else
              routing_table
            end

          for i <- 0..3 do
            if ((elem(elem(routing_table, samePref), i)) != myID && elem(elem(routing_table, samePref), i) != theId && elem(elem(routing_table, samePref), i) != -1) do
              GenServer.cast(String.to_atom("child"<>Integer.to_string(elem(elem(routing_table, samePref), i))), {:requestInTable, samePref ,nextBit, myID})
            end   
          end
          
          {:noreply, {myID, numNodes, lesserLeaf, largerLeaf, routing_table, numOfBack}}
        end

    def handle_cast({:leaf_recover, newList}, state) do
      {myID, numNodes, lesserLeaf, largerLeaf, routing_table, numOfBack} = state
      {lesserLeaf, largerLeaf} = PastryHelper.leafRecover(newList, myID, lesserLeaf, largerLeaf)
      {:noreply, {myID, numNodes, lesserLeaf, largerLeaf, routing_table, numOfBack}}
    end

    def handle_cast({:request_leaf_without, theID, sender}, state) do
      {myID, numNodes, lesserLeaf, largerLeaf, routing_table, numOfBack} = state 
      temp = lesserLeaf ++ largerLeaf
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
      Process.sleep(1000)
      Process.exit(self(), :kill)
      {:noreply, {myID, numNodes, lesserLeaf, largerLeaf, routing_table, numOfBack}}
    end

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