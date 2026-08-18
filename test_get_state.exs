Registry.start_link(keys: :unique, name: ConvoSim.ConversationRegistry)
id = "nonexistent_id"
try do
  GenServer.call({:via, Registry, {ConvoSim.ConversationRegistry, id}}, :get_state)
catch
  :exit, {reason, _} -> IO.puts("Caught exit: #{inspect(reason)}")
end
