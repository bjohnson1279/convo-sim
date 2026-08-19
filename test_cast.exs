Registry.start_link(keys: :unique, name: ConvoSim.ConversationRegistry)
GenServer.cast({:via, Registry, {ConvoSim.ConversationRegistry, "nonexistent"}}, :hello)
IO.puts("Cast succeeded")
