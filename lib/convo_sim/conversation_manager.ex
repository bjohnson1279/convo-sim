defmodule ConvoSim.ConversationManager do
  @moduledoc """
  Facade module to manage conversation lifecycles via DynamicSupervisor and Registry.
  This module itself is NOT a process, just a collection of functions acting as the API.
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
      # Generate a short readable ID (e.g., "conv-" <> first 8 chars of a UUID)
      # Using Ecto.UUID if available, or just purely Erlang's unique id generator if not.
      # Let's use :crypto.strong_rand_bytes to avoid depending on Ecto just for UUIDs.
      # ⚡ Bolt: Generate 4 bytes instead of 16 to avoid entropy depletion and eliminate
      # O(N) String.slice/3 allocation of intermediate 32-char string.
      id = "conv-" <> Base.encode16(:crypto.strong_rand_bytes(4), case: :lower)

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
  Gets the state of a specific conversation by delegating to the Conversation process.
  """
  def get_state(id) do
    ConvoSim.Conversation.get_state(id)
  end
end
