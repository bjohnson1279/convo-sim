Registry.start_link(keys: :unique, name: ConvoSim.ConversationRegistry)
try do
  GenServer.call({:via, Registry, {ConvoSim.ConversationRegistry, "nonexistent"}}, :hello)
catch
  :exit, {reason, _} -> IO.puts("Caught exit: #{inspect(reason)}")
end
