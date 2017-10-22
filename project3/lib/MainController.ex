defmodule MainController do
  use GenServer

    # API
  
  @doc """
  """
  @name :master
  @base 4

  def start_link(numNodes, numRequests, numJoined, numNotInBoth, numRouted, numHops, numRouteNotInBoth) do
    GenServer.start_link(MainController, [numNodes, numRequests, numJoined, numNotInBoth, numRouted, numHops, numRouteNotInBoth])
  end

  def init([numNodes, numRequests, numJoined, numNotInBoth, numRouted, numHops, numRouteNotInBoth]) do
      {:ok, {numNodes, [], numRequests, numJoined, numNotInBoth, numRouted, numHops, numRouteNotInBoth}}
  end
  @doc """
  """   
  def handle_cast(:go, state) do
    {numNodes, _, numRequests, numJoined, numNotInBoth, numRouted, numHops, numRouteNotInBoth} = state
    numBits = round(Float.ceil(:math.log(numNodes)/:math.log(@base)))
    nodeIDSpace = round(Float.ceil(:math.pow(@base, numBits)))
    numFirstGroup = if (numNodes <= 1024) do numNodes else 1024 end
    randList = Enum.shuffle(Enum.to_list(0..(numNodes-1)))
    firstGroup = Enum.slice(randList, 0..(numFirstGroup-1))

    list_pid = for nodeID <- firstGroup do
      {_, pid} = PastryNode.startlink(nodeID, numNodes)
      pid
    end 
    IO.inspect list_pid
    # First Join
    for pid <- list_pid do
      GenServer.cast(pid, {:first_join, firstGroup})
    end
    {:noreply, {numNodes, randList, numRequests, numJoined, numNotInBoth, numRouted, numHops, numRouteNotInBoth}}
  end

  def handle_cast(:join_finish, state) do
    {numNodes, randList, numRequests, numJoined, numNotInBoth, numRouted, numHops, numRouteNotInBoth} = state
    IO.inspect "Join finish #{numJoined}"
    numFirstGroup = if (numNodes <= 1024) do numNodes else 1024 end
    numJoined = numJoined + 1
    if(numJoined >= numFirstGroup) do
      if(numJoined >= numNodes) do
        GenServer.cast(:global.whereis_name(@name), :begin_route)
      else
        GenServer.cast(:global.whereis_name(@name), :second_join)
      end
    end
    {:noreply, {numNodes, randList, numRequests, numJoined, numNotInBoth, numRouted, numHops, numRouteNotInBoth}}
  end

    def handle_cast({:route_finish, fromID, toID, hops}, state) do
    {numNodes, randList, numRequests, numJoined, numNotInBoth, numRouted, numHops, numRouteNotInBoth} = state
    IO.inspect "Something finished.. From #{fromID} to #{toID}"
    numRouted = numRouted + 1
    numHops = numHops + hops
    if (numRouted >= numNodes * numRequests) do
      IO.puts "Number of Total Routes: #{numRouted}"
      IO.puts "Number of Total Hops: #{numHops}"
      IO.puts "Average hops per Route: #{numHops/numRouted}"
      Process.exit(self(), :shutdown)
    end
    {:noreply, {numNodes, randList, numRequests, numJoined, numNotInBoth, numRouted, numHops, numRouteNotInBoth}}
  end

  def handle_cast(:begin_route, state) do
    {_, randList, numRequests, _, _, _, _, _} = state
    for node <- randList do
        GenServer.cast(String.to_atom("child"<>Integer.to_string(node)), {:begin_route, numRequests})
    end
    {:noreply, state}
  end

    def handle_cast(:second_join, state) do
    IO.inspect state
    {numNodes, randList, numRequests, numJoined, numNotInBoth, numRouted, numHops, numRouteNotInBoth} = state
    startID = Enum.at(randList, Enum.random(0..(numJoined-1)))
    PastryNode.startlink(Enum.at(randList, numJoined), numNodes)
    GenServer.cast(String.to_atom("child"<>Integer.to_string(startID)), {:route, "Join", startID, Enum.at(randList, numJoined), -1})
    {:noreply, {numNodes, randList, numRequests, numJoined, numNotInBoth, numRouted, numHops, numRouteNotInBoth}}
  end

  def main(args) do
    [numNodes, numRequests] = args
    numNodes = String.to_integer(numNodes)
    numRequests = String.to_integer(numRequests)
    numJoined = 0
    numNotInBoth = 0
    numRouted = 0
    numHops = 0
    numRouteNotInBoth = 0
    {:ok, master_pid} = start_link(numNodes, numRequests, numJoined, numNotInBoth, numRouted, numHops, numRouteNotInBoth)
    :global.register_name(@name, master_pid)
    :global.sync()
    GenServer.cast(:global.whereis_name(@name), :go)
    
    :timer.sleep(:infinity)
  end
end