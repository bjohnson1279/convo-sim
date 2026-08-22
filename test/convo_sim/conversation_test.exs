defmodule ConvoSim.ConversationTest do
  use ExUnit.Case, async: true

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
end
