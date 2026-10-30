defmodule ConvoSim.ConversationTest do
  use ExUnit.Case, async: false

  alias ConvoSim.Conversation
  alias ConvoSim.ConversationManager

  test "starts a conversation and handles state transitions" do
    {:ok, id} = ConversationManager.start_conversation()
    assert String.match?(id, ~r/^conv-[0-9a-f]{8}$/)
    assert id in ConversationManager.list_conversations()

    state = ConversationManager.get_state(id)
    assert state.status == :idle
    assert state.messages == []

    # Send customer message
    Conversation.send_message(id, "Hello test")

    # Because send_message is an asynchronous GenServer.cast, the test process might race ahead
    # before the GenServer updates its state in the Registry.
    # For testing, we can sync by doing a sys.get_state which blocks until the queue is processed
    _ = :sys.get_state(Registry.lookup(ConvoSim.ConversationRegistry, id) |> hd() |> elem(0))

    state = ConversationManager.get_state(id)
    assert state.status == :responding
    assert length(state.messages) == 1
    assert hd(state.messages).content == "Hello test"

    # Find PID and monitor before stopping to synchronize cleanup
    [{pid, _}] = Registry.lookup(ConvoSim.ConversationRegistry, id)
    ref = Process.monitor(pid)

    assert ConversationManager.stop_conversation(id) == :ok
    assert_receive {:DOWN, ^ref, :process, ^pid, _reason}
    # Wait for the Registry to asynchronously process the process death and remove the entry
    Process.sleep(100)
    _ = :sys.get_state(ConvoSim.ConversationRegistry)

    refute id in ConversationManager.list_conversations()
  end

  test "rejects messages exceeding payload boundaries" do
    {:ok, id} = ConversationManager.start_conversation()

    # Content exceeds 4000 bytes
    large_content = String.duplicate("a", 4001)
    assert Conversation.send_message(id, large_content) == {:error, :content_too_large}

    # ID exceeds 64 bytes
    large_id = String.duplicate("a", 65)
    assert Conversation.send_message(large_id, "hello") == {:error, :content_too_large}

    ConversationManager.stop_conversation(id)
  end

  test "rejects customer messages when already in :responding status" do
    {:ok, id} = ConversationManager.start_conversation()

    # First message sets status to :responding
    Conversation.send_message(id, "First message")
    [{pid, _}] = Registry.lookup(ConvoSim.ConversationRegistry, id)
    _ = :sys.get_state(pid)

    state = ConversationManager.get_state(id)
    assert state.status == :responding
    assert state.message_count == 1

    # Second message sent while responding should be ignored
    Conversation.send_message(id, "Second message while busy")
    _ = :sys.get_state(pid)

    state_after = ConversationManager.get_state(id)
    assert state_after.status == :responding
    assert state_after.message_count == 1
    assert hd(state_after.messages).content == "First message"

    ConversationManager.stop_conversation(id)
  end

  test "handles :ai_response message and updates state and PubSub subscribers" do
    # Subscribe to global topic before starting conversation
    Phoenix.PubSub.subscribe(ConvoSim.PubSub, "conversations")

    {:ok, id} = ConversationManager.start_conversation()

    # Subscribe to per-conversation topic
    Phoenix.PubSub.subscribe(ConvoSim.PubSub, "conversation:#{id}")

    # Assert creation broadcast received on global topic
    assert_receive {:conversation_updated, ^id, %Conversation{status: :idle}}

    Conversation.send_message(id, "Hello PubSub")
    [{pid, _}] = Registry.lookup(ConvoSim.ConversationRegistry, id)
    _ = :sys.get_state(pid)

    # Assert broadcast after customer message
    assert_receive {:conversation_updated, ^id, %Conversation{status: :responding}}

    # Manually send :ai_response message to simulate task completion
    send(pid, {:ai_response, "AI response text"})
    _ = :sys.get_state(pid)

    # Assert broadcast after AI response
    assert_receive {:conversation_updated, ^id, %Conversation{status: :idle} = updated_state}
    assert updated_state.message_count == 2
    assert updated_state.status == :idle
    assert hd(updated_state.messages).content == "AI response text"
    assert hd(updated_state.messages).role == :assistant

    ConversationManager.stop_conversation(id)
  end

  test "ConversationManager handles stopping non-existent conversation and listing states" do
    assert ConversationManager.stop_conversation("conv-nonexistent") == {:error, :not_found}

    {:ok, id} = ConversationManager.start_conversation()
    states = ConversationManager.list_all_states()

    assert Enum.any?(states, fn state -> state.id == id end)

    ConversationManager.stop_conversation(id)
  end

  test "enforces maximum concurrent conversation limit of 50" do
    # Register mock entries in the Registry to reach 50
    current_count = Registry.count(ConvoSim.ConversationRegistry)
    needed = max(0, 50 - current_count)

    mock_pids =
      for i <- 1..needed do
        {:ok, pid} =
          Task.start(fn ->
            Registry.register(ConvoSim.ConversationRegistry, "mock-limit-#{i}", :ok)
            Process.sleep(:infinity)
          end)

        pid
      end

    # Wait for the tasks to register
    Process.sleep(100)

    assert Registry.count(ConvoSim.ConversationRegistry) >= 50
    assert ConversationManager.start_conversation() == {:error, :too_many_conversations}

    # Clean up so other tests don't fail
    for pid <- mock_pids, do: Process.exit(pid, :kill)

    # Wait for cleanup
    Process.sleep(100)
  end
end
