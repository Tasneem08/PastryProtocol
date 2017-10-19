defmodule MainController do
use GenServer
# entry point to the code. Read command line arguments and invoke the right things here.
  # Entry point to the code. 
  def main(args) do
    [nNodes,nRequests] = args
    numNodes=nNodes|>String.to_integer()
    numRequests=nRequests|>String.to_integer()
 
    # Start up nodes with blank routing table information
    nodeMap=%{}
    nodeList=Enum.to_list(1..numNodes)
    numDigits = Float.ceil(:math.log(numNodes) / :math.log(4)) |> round
    {nodeMap, nodeList} = loadGenservers(nodeList, numDigits, numNodes, numRequests, nodeMap, [])
    IO.inspect nodeList
    # Start gen server
    start_link(nodeMap, numNodes)

    #GenServer.cast(:main_server, {:initiateProtocol, map})

    :timer.sleep(:infinity)

  end

  def loadGenservers([nodeId|nodeList], numDigits, numNodes, numRequests, nodeMap, newNodeList) do
   nodeId = Integer.to_string(nodeId,4)|> String.pad_leading(numDigits, "0")
   newNodeList = List.insert_at(newNodeList, 0, nodeId)
   {_, pid} = PastryNode.start_link(nodeId, numNodes, numRequests)
   nodeMap = Map.put(nodeMap,pid,nodeId)
   loadGenservers(nodeList, numDigits, numNodes, numRequests, nodeMap, newNodeList)
  end

  def loadGenservers([], numDigits, numNodes, numRequests, nodeMap, newNodeList) do
    {nodeMap, newNodeList}
  end
  
  def start_link(nodeMap, numNodes) do
    GenServer.start_link(MainController, [nodeMap, numNodes], name: :main_server)
  end





    def init(map, numNodes, algorithm, count, starttime) do
      {:ok, {map, numNodes, algorithm, count, starttime}}
  end

  def handle_cast({:iDied, pid}, state) do
    [map, numNodes, algorithm, count, starttime] = state
    if  Map.has_key?(map, pid) do
    # IO.inspect pid
      map = Map.delete(map, pid)
      
      count = count + 1
      spawn(fn->GenServer.cast(:main_server, {:initiateProtocol, map})end)
    # if count >= Float.floor(0.50*numNodes) do
    #     diff =  DateTime.diff(DateTime.utc_now, starttime, :millisecond)
    #     IO.puts "Most nodes have died. Shutting down the protocol.. Convergence took #{diff} milliseconds."
    #     Process.exit(self(), :shutdown)
    # end
    end 
    {:noreply, [map, numNodes, algorithm,count, starttime]}
  end

  def handle_cast({:initiateProtocol, map}, state) do
      # Process.sleep(50)
      [_, numNodes, algorithm, count, starttime] = state
      if map_size(map) <= 0.5*numNodes do
       diff =  DateTime.diff(DateTime.utc_now, starttime, :millisecond)
       IO.puts "Most nodes have died. Shutting down the protocol.. Convergence took #{diff} milliseconds."
       Process.exit(self(), :shutdown)
      end
      # IO.inspect "Infecting with #{map_size(map)} alive Nodes..."
      { pid, firstNode} = Enum.at(map, Enum.random(0..(map_size(map)-1)))
      #  selectedNeighborNode = String.to_atom("workernode"<>Integer.to_string(firstNode)<>"@"<>GossipNode.findIP())
      selectedNeighborServer =  String.to_atom("workerserver"<>Integer.to_string(firstNode))
      # a = DateTime.utc_now
      if Process.whereis(selectedNeighborServer) != nil do
      if algorithm == "push-sum" do
      GenServer.cast(selectedNeighborServer, {:infectPushSum, 0, 0})
      else
      GenServer.cast(selectedNeighborServer, {:infect})
      end
      end
      {:noreply, state}
  end

    def handle_cast({:findNextAgain}, state) do
       GenServer.cast(:main_server, {:initiateProtocol})
       {:noreply, state}
  end

      def handle_cast({:initiateProtocol, map, 0}, state) do
       [_, _, _, _, starttime] = state
       diff =  DateTime.diff(DateTime.utc_now, starttime, :millisecond)
       IO.puts "Most nodes have died. Shutting down the protocol.. Convergence took #{diff} milliseconds."
       Process.exit(self(), :shutdown)
  end

  def handle_call({:killMain}, _from, state) do
    
    IO.puts "Most nodes have died. Shutting down the protocol..."
    {:stop, :normal, state}
  end
end