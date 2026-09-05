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
    _ = :sys.get_state(ConvoSim.ConversationRegistry)

    refute id in ConversationManager.list_conversations()
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
