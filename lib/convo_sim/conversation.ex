defmodule ConvoSim.Conversation do
  @moduledoc """
  GenServer representing an isolated customer conversation process.

  Maintains conversation history and status, caches state in `Registry` for O(1)
  lookups, broadcasts events over PubSub, and delegates AI responses to background tasks.
  """
  use GenServer

  defstruct id: nil, status: :idle, messages: [], message_count: 0, created_at: nil

  @doc """
  Starts a new conversation GenServer process.
  Registers the process with the ConversationRegistry using a 'via tuple'.
  """
  def start_link(id) do
    # Register via Registry with initial state value for O(1) reads without mailbox queuing.
    name = {:via, Registry, {ConvoSim.ConversationRegistry, id, %__MODULE__{id: id}}}
    GenServer.start_link(__MODULE__, id, name: name)
  end

  @doc """
  Gets the current state of a conversation by id.
  """
  def get_state(id) do
    # Fetch state directly from Registry ETS table to avoid blocking the GenServer mailbox.
    case Registry.lookup(ConvoSim.ConversationRegistry, id) do
      [{_pid, state}] ->
        state

      [] ->
        # Fall back to synchronous GenServer call to retain expected noproc exit semantics.
        GenServer.call({:via, Registry, {ConvoSim.ConversationRegistry, id}}, :get_state)
    end
  end

  @doc """
  Sends a message to the conversation.
  """
  def send_message(id, content)
      when is_binary(id) and byte_size(id) <= 64 and is_binary(content) and
             byte_size(content) <= 4000 do
    # Cast asynchronously so callers are not blocked waiting on response generation.
    GenServer.cast(
      {:via, Registry, {ConvoSim.ConversationRegistry, id}},
      {:customer_message, content}
    )
  end

  def send_message(_id, _content) do
    # Reject oversized identifiers or content payloads exceeding length thresholds.
    {:error, :content_too_large}
  end

  @impl GenServer
  def init(id) do
    state = %__MODULE__{
      id: id,
      status: :idle,
      messages: [],
      message_count: 0,
      created_at: DateTime.utc_now()
    }

    # Store initial state in Registry for O(1) external lookups.
    Registry.update_value(ConvoSim.ConversationRegistry, state.id, fn _ -> state end)

    broadcast("conversations", state)

    {:ok, state}
  end

  @impl GenServer
  def handle_call(:get_state, _from, state) do
    # Return state directly to avoid O(N) list reversals in the process loop.
    {:reply, state, state}
  end

  require Logger

  @impl GenServer
  def handle_cast({:customer_message, content}, state) do
    if state.status == :responding do
      Logger.warning(
        "Rejected customer message: conversation #{inspect(state.id)} is already responding"
      )

      {:noreply, state}
    else
      customer_msg = %{
        role: :customer,
        content: content,
        timestamp: DateTime.utc_now()
      }

      # Prepend message and increment cached count to avoid O(N) list operations.
      new_state = %{
        state
        | messages: [customer_msg | state.messages],
          message_count: state.message_count + 1,
          status: :responding
      }

      # Sync updated state to Registry for O(1) external lookups.
      Registry.update_value(ConvoSim.ConversationRegistry, new_state.id, fn _ -> new_state end)

      broadcast_all(new_state)

      # Offload AI response generation to a background task to prevent blocking the GenServer.
      responder = Application.get_env(:convo_sim, :responder, ConvoSim.Responder.Simulated)
      pid = self()

      Task.start(fn ->
        # Pass newest-first history directly to avoid redundant list reversal.
        response = responder.respond(content, state.messages)
        send(pid, {:ai_response, response})
      end)

      {:noreply, new_state}
    end
  end

  @impl GenServer
  def handle_info({:ai_response, response_content}, state) do
    ai_msg = %{
      role: :assistant,
      content: response_content,
      timestamp: DateTime.utc_now()
    }

    # Prepend assistant response and increment cached message count.
    new_state = %{
      state
      | messages: [ai_msg | state.messages],
        message_count: state.message_count + 1,
        status: :idle
    }

    # Sync updated state to Registry for O(1) external lookups.
    Registry.update_value(ConvoSim.ConversationRegistry, new_state.id, fn _ -> new_state end)

    broadcast_all(new_state)

    {:noreply, new_state}
  end

  defp broadcast_all(state) do
    broadcast("conversations", state)
    broadcast("conversation:#{state.id}", state)
  end

  defp broadcast(topic, state) do
    Phoenix.PubSub.broadcast(ConvoSim.PubSub, topic, {:conversation_updated, state.id, state})
  end
end
