defmodule PastryNode do
use GenServer

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
      {:ok, {nodeID, numNodes, [], [], routing_table, numOfBack}}
    end

    def handle_cast({:pastryInit, firstGroup}, state) do
      {myID, numNodes, lesserLeaf, largerLeaf, routing_table, numOfBack} = state
      numBits = round(Float.ceil(:math.log(numNodes)/:math.log(@base)))
      firstGroup = List.delete(firstGroup, myID)
      {lesserLeaf, largerLeaf, routing_table} = PastryHelper.addBuffer(myID, firstGroup, numBits, lesserLeaf, largerLeaf, routing_table)

      for i <- 0..(numBits-1) do
        nextBit = String.to_integer(String.at(PastryHelper.toBaseString(myID, numBits), i))
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

     if  msg=="Join" do
          samePref = PastryHelper.samePrefix(PastryHelper.toBaseString(myID, numBits), PastryHelper.toBaseString(toId, numBits), 0)
          nextBit = String.to_integer(String.at(PastryHelper.toBaseString(toId, numBits), samePref))
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
          if myID == toId do
            GenServer.cast(:global.whereis_name(@name), {:route_finish,hops+1})# to be implemented
          else 
            samePref = PastryHelper.samePrefix(PastryHelper.toBaseString(myID, numBits), PastryHelper.toBaseString(toId, numBits), 0)
            nextBit = String.to_integer(String.at(PastryHelper.toBaseString(toId, numBits), samePref))
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
                GenServer.cast(:global.whereis_name(@name), {:route_finish,hops+1})
              end                      
              
              length(lesserLeaf)<4 && length(lesserLeaf)>0 && toId < Enum.min(lesserLeaf) ->
                GenServer.cast(String.to_atom("child"<>Integer.to_string(Enum.min(lesserLeaf))), {:route,"Route",fromId,toId,hops+1})
              length(largerLeaf)<4 && length(largerLeaf)>0 && toId > Enum.max(largerLeaf) ->
                GenServer.cast(String.to_atom("child"<>Integer.to_string(Enum.max(largerLeaf))), {:route,"Route",fromId,toId,hops+1})
              (length(lesserLeaf)==0 && toId<myID) || (length(largerLeaf)==0 && toId>myID) -> #I am the nearest
                GenServer.cast(:global.whereis_name(@name), {:route_finish,hops+1})
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
        {myID, numNodes, lesserLeaf, largerLeaf, routing_table, numOfBack} = state
        routing_table =  Tuple.insert_at(Tuple.delete_at(routing_table, rowNum), rowNum, newRow)  
        {:noreply, {myID, numNodes, lesserLeaf, largerLeaf, routing_table, numOfBack}}
    end

    def handle_cast({:update_me, newNode}, state) do
      {myID, numNodes, lesserLeaf, largerLeaf, routing_table, numOfBack} = state
      numBits = round(Float.ceil(:math.log(numNodes)/:math.log(@base)))
      {lesserLeaf, largerLeaf, routing_table} = PastryHelper.addBuffer(myID, [newNode], numBits, lesserLeaf, largerLeaf, routing_table)
      #Send ack
      GenServer.cast(String.to_atom("child"<>Integer.to_string(newNode)), :ack)
      {:noreply, {myID, numNodes, lesserLeaf, largerLeaf, routing_table, numOfBack}}
    end

    def handle_cast({:add_leaf, allLeaf}, state) do
      # IO.puts "In addLeaf"
      {myID, numNodes, lesserLeaf, largerLeaf, routing_table, numOfBack} = state
      numBits = round(Float.ceil(:math.log(numNodes)/:math.log(@base)))
      {lesserLeaf, largerLeaf, routing_table} = PastryHelper.addBuffer(myID, allLeaf, numBits, lesserLeaf, largerLeaf, routing_table)
      for i <- lesserLeaf do
            GenServer.cast(String.to_atom("child"<>Integer.to_string(i)), {:update_me, myID})
      end
      for i <- largerLeaf do
            GenServer.cast(String.to_atom("child"<>Integer.to_string(i)), {:update_me, myID})
      end
      numOfBack = numOfBack + length(lesserLeaf) + length(largerLeaf)
      # Iterate over the routing_table and call Update_Me on valid entries
        numOfBack = PastryHelper.tellRoutingNodes(routing_table, 0, 0, numBits, myID, numOfBack)
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

    def handle_cast({:begin_routing, numRequests}, state) do
      {myID, numNodes, lesserLeaf, largerLeaf, routing_table, numOfBack} = state
      numBits = round(Float.ceil(:math.log(numNodes)/:math.log(@base)))
      nodeIDSpace = round(Float.ceil(:math.pow(@base, numBits)))
      PastryHelper.sendRequest(Enum.to_list(1..numRequests), myID, nodeIDSpace)
      {:noreply, {myID, numNodes, lesserLeaf, largerLeaf, routing_table, numOfBack}}
    end
end