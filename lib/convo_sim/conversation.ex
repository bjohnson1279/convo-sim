defmodule ConvoSim.Conversation do
  @moduledoc """
  A GenServer representing a single customer conversation.
  """
  use GenServer

  # State struct definition for cleaner access and default values
  defstruct id: nil, status: :idle, messages: [], message_count: 0, created_at: nil

  # --- Public API ---

  @doc """
  Starts a new conversation GenServer process.
  Registers the process with the ConversationRegistry using a 'via tuple'.
  """
  def start_link(id) do
    # The :via tuple is a way to register a process under a custom name,
    # in this case using our custom Registry instead of a global atom.
    name = {:via, Registry, {ConvoSim.ConversationRegistry, id}}
    GenServer.start_link(__MODULE__, id, name: name)
  end

  @doc """
  Gets the current state of a conversation by id.
  """
  def get_state(id) do
    # We construct the same via tuple to find the process and send it a synchronous message
    GenServer.call({:via, Registry, {ConvoSim.ConversationRegistry, id}}, :get_state)
  end

  @doc """
  Sends a message to the conversation.
  """
  def send_message(id, content) do
    # Using cast because we don't need to block waiting for the result.
    GenServer.cast(
      {:via, Registry, {ConvoSim.ConversationRegistry, id}},
      {:customer_message, content}
    )
  end

  # --- GenServer Callbacks ---

  @impl GenServer
  def init(id) do
    state = %__MODULE__{
      id: id,
      status: :idle,
      messages: [],
      message_count: 0,
      created_at: DateTime.utc_now()
    }

    # Broadcast that the conversation started to the global topic
    broadcast("conversations", state)

    {:ok, state}
  end

  @impl GenServer
  def handle_call(:get_state, _from, state) do
    # ⚡ Bolt: Return prepended state directly to avoid O(N) Enum.reverse/1 blocking the GenServer
    {:reply, state, state}
  end

  @impl GenServer
  def handle_cast({:customer_message, content}, state) do
    customer_msg = %{
      role: :customer,
      content: content,
      timestamp: DateTime.utc_now()
    }

    # Prepend instead of append (O(1) instead of O(N))
    # ⚡ Bolt: We cache message_count to avoid O(N) length() calls in the UI
    new_state = %{
      state
      | messages: [customer_msg | state.messages],
        message_count: state.message_count + 1,
        status: :responding
    }

    # Broadcast status change
    broadcast_all(new_state)

    # Spawn a Task for the AI response so we don't block the GenServer.
    # The GenServer can still process other messages while waiting.
    responder = Application.get_env(:convo_sim, :responder, ConvoSim.Responder.Simulated)
    pid = self()

    Task.start(fn ->
      # Reverse messages to pass chronological history to the responder
      response = responder.respond(content, Enum.reverse(state.messages))
      # Send the result back to the GenServer using standard Erlang messaging
      send(pid, {:ai_response, response})
    end)

    {:noreply, new_state}
  end

  @impl GenServer
  def handle_info({:ai_response, response_content}, state) do
    ai_msg = %{
      role: :assistant,
      content: response_content,
      timestamp: DateTime.utc_now()
    }

    # Prepend instead of append (O(1) instead of O(N))
    # ⚡ Bolt: We cache message_count to avoid O(N) length() calls in the UI
    new_state = %{
      state
      | messages: [ai_msg | state.messages],
        message_count: state.message_count + 1,
        status: :idle
    }

    broadcast_all(new_state)

    {:noreply, new_state}
  end

  # --- Private Helpers ---

  defp broadcast_all(state) do
    # ⚡ Bolt: Broadcast prepended state directly to avoid O(N) Enum.reverse/1 on every message
    # The UI will use CSS flex-col-reverse to display them chronologically

    # Broadcast to global topic
    broadcast("conversations", state)
    # Broadcast to per-conversation topic
    broadcast("conversation:#{state.id}", state)
  end

  defp broadcast(topic, state) do
    # Broadcast payloads should be: {:conversation_updated, id, state} for simplicity
    Phoenix.PubSub.broadcast(ConvoSim.PubSub, topic, {:conversation_updated, state.id, state})
  end
end
