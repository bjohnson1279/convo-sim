defmodule ConvoSim.ConversationManager do
  @moduledoc """
  Facade module managing conversation lifecycles via DynamicSupervisor and Registry.

  This module coordinates conversation processes (`ConvoSim.Conversation`) supervised
  by `ConvoSim.ConversationSupervisor` and indexed in `ConvoSim.ConversationRegistry`.
  It is not a stateful process itself, but provides public API functions for starting,
  stopping, and querying conversation states without N+1 process call bottlenecks.
  """

  @doc """
  Starts a new conversation process under the DynamicSupervisor.
  Returns the generated id.
  """
  def start_conversation() do
    # 🛡️ Sentinel: Prevent Resource Exhaustion (DoS) by limiting active conversations
    if Registry.count(ConvoSim.ConversationRegistry) >= 50 do
      {:error, :too_many_conversations}
    else
      # ⚡ Bolt: Generate 4 random bytes directly to avoid entropy depletion and intermediate string slicing.
      id = "conv-" <> Base.encode16(:crypto.strong_rand_bytes(16), case: :lower)

      # Start the child dynamically under our supervisor
      # The child spec is based on ConvoSim.Conversation's use of GenServer
      spec = %{
        id: ConvoSim.Conversation,
        start: {ConvoSim.Conversation, :start_link, [id]},
        # Only run once, don't restart on normal termination
        restart: :temporary
      }

      case DynamicSupervisor.start_child(ConvoSim.ConversationSupervisor, spec) do
        {:ok, _pid} -> {:ok, id}
        {:error, reason} -> {:error, reason}
      end
    end
  end

  @doc """
  Stops a conversation.
  """
  def stop_conversation(id) do
    # Look up the process ID (pid) from the Registry
    case Registry.lookup(ConvoSim.ConversationRegistry, id) do
      [{pid, _}] ->
        # Terminate the process cleanly via the DynamicSupervisor
        DynamicSupervisor.terminate_child(ConvoSim.ConversationSupervisor, pid)

      [] ->
        {:error, :not_found}
    end
  end

  @doc """
  Lists all active conversation IDs from the Registry.
  """
  def list_conversations() do
    # Use Registry.select to match all keys in the registry
    # The match spec extracts just the key (`id`) from each entry
    Registry.select(ConvoSim.ConversationRegistry, [{{:"$1", :_, :_}, [], [:"$1"]}])
  end

  @doc """
  Lists all active conversation states from the Registry directly.
  By fetching from the Registry value, we avoid N+1 GenServer.call bottlenecks.
  """
  def list_all_states() do
    # ⚡ Bolt: O(1) state fetching via native ETS match.
    # The match spec `{{:_, :_, :"$1"}, [], [:"$1"]}` returns only the 3rd element
    # of the registry tuple, which is the state value we populated.
    Registry.select(ConvoSim.ConversationRegistry, [{{:_, :_, :"$1"}, [], [:"$1"]}])
  end

  @doc """
  Gets the state of a specific conversation by delegating to the Conversation process.
  """
  def get_state(id) do
    ConvoSim.Conversation.get_state(id)
  end
end
