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

  describe "send_message/2 payload validation and boundary conditions" do
    test "rejects content exceeding 4000 bytes" do
      oversized_content = String.duplicate("a", 4001)

      assert Conversation.send_message("conv-12345678", oversized_content) ==
               {:error, :content_too_large}
    end

    test "rejects id exceeding 64 bytes" do
      oversized_id = String.duplicate("c", 65)

      assert Conversation.send_message(oversized_id, "Hello") ==
               {:error, :content_too_large}
    end

    test "rejects non-binary id or content" do
      assert Conversation.send_message(12345, "Hello") == {:error, :content_too_large}
      assert Conversation.send_message("conv-12345678", nil) == {:error, :content_too_large}
      assert Conversation.send_message(:conv_atom, "Hello") == {:error, :content_too_large}

      assert Conversation.send_message("conv-12345678", :not_a_string) ==
               {:error, :content_too_large}
    end

    test "accepts content at exactly 4000 bytes and id <= 64 bytes" do
      {:ok, id} = ConversationManager.start_conversation()
      exact_content = String.duplicate("b", 4000)

      # Should return :ok (GenServer.cast result) and not {:error, :content_too_large}
      assert Conversation.send_message(id, exact_content) == :ok

      [{pid, _}] = Registry.lookup(ConvoSim.ConversationRegistry, id)
      _ = :sys.get_state(pid)

      state = ConversationManager.get_state(id)
      assert state.message_count == 1
      assert hd(state.messages).content == exact_content

      ref = Process.monitor(pid)
      assert ConversationManager.stop_conversation(id) == :ok
      assert_receive {:DOWN, ^ref, :process, ^pid, _reason}
    end
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

  describe "concurrency, state transitions, and PubSub integration" do
    test "rejects customer message when status is already :responding" do
      {:ok, id} = ConversationManager.start_conversation()
      [{pid, _}] = Registry.lookup(ConvoSim.ConversationRegistry, id)

      # Send first message to transition to :responding
      assert Conversation.send_message(id, "First message") == :ok
      _ = :sys.get_state(pid)

      state_first = ConversationManager.get_state(id)
      assert state_first.status == :responding
      assert state_first.message_count == 1

      # Send second message while status is :responding
      assert Conversation.send_message(id, "Second message") == :ok
      _ = :sys.get_state(pid)

      # Verify the message was rejected and not appended
      state_second = ConversationManager.get_state(id)
      assert state_second.status == :responding
      assert state_second.message_count == 1
      assert hd(state_second.messages).content == "First message"

      ref = Process.monitor(pid)
      assert ConversationManager.stop_conversation(id) == :ok
      assert_receive {:DOWN, ^ref, :process, ^pid, _reason}
    end

    test "handles :ai_response info message, updates state and broadcasts to PubSub" do
      {:ok, id} = ConversationManager.start_conversation()
      [{pid, _}] = Registry.lookup(ConvoSim.ConversationRegistry, id)

      # Subscribe to both global and per-conversation topics
      Phoenix.PubSub.subscribe(ConvoSim.PubSub, "conversations")
      Phoenix.PubSub.subscribe(ConvoSim.PubSub, "conversation:#{id}")

      # Send customer message
      Conversation.send_message(id, "Hello from customer")
      _ = :sys.get_state(pid)

      # Assert broadcast of customer message status change
      assert_receive {:conversation_updated, ^id, %Conversation{status: :responding}}

      # Send simulated ai_response directly to the process
      send(pid, {:ai_response, "Simulated AI response content"})
      _ = :sys.get_state(pid)

      # Assert broadcast of AI response completed
      assert_receive {:conversation_updated, ^id,
                      %Conversation{
                        status: :idle,
                        message_count: 2,
                        messages: [latest_msg | _]
                      }}

      assert latest_msg.role == :assistant
      assert latest_msg.content == "Simulated AI response content"

      # Verify final state
      state = ConversationManager.get_state(id)
      assert state.status == :idle
      assert state.message_count == 2
      assert hd(state.messages).role == :assistant

      ref = Process.monitor(pid)
      assert ConversationManager.stop_conversation(id) == :ok
      assert_receive {:DOWN, ^ref, :process, ^pid, _reason}
    end

    test "handle_call :get_state directly returns the state" do
      {:ok, id} = ConversationManager.start_conversation()
      [{pid, _}] = Registry.lookup(ConvoSim.ConversationRegistry, id)

      call_state = GenServer.call(pid, :get_state)
      assert %Conversation{id: ^id, status: :idle} = call_state

      ref = Process.monitor(pid)
      assert ConversationManager.stop_conversation(id) == :ok
      assert_receive {:DOWN, ^ref, :process, ^pid, _reason}
    end

    test "stop_conversation returns {:error, :not_found} for unknown id" do
      assert ConversationManager.stop_conversation("conv-nonexistent") == {:error, :not_found}
    end

    test "list_all_states returns active conversation state structs directly" do
      {:ok, id1} = ConversationManager.start_conversation()
      {:ok, id2} = ConversationManager.start_conversation()

      all_states = ConversationManager.list_all_states()
      ids = Enum.map(all_states, & &1.id)

      assert id1 in ids
      assert id2 in ids
      assert Enum.all?(all_states, fn state -> match?(%Conversation{}, state) end)

      ConversationManager.stop_conversation(id1)
      ConversationManager.stop_conversation(id2)
    end
  end
end
