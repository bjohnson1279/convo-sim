defmodule ConvoSimWeb.DashboardLiveTest do
  use ConvoSimWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  test "renders dashboard title, logo alt text, and empty state", %{conn: conn} do
    {:ok, view, html} = live(conn, ~p"/")

    assert html =~ "Real-Time Conversation Simulator"
    assert has_element?(view, ~s|img[alt="ConvoSim Logo"]|)
    assert has_element?(view, ~s|button#spawn-convo-btn|)
    assert has_element?(view, ~s|button#empty-state-spawn-btn|)
    assert has_element?(view, "#conversations")
  end

  test "spawns a conversation when clicking spawn button", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    view
    |> element("#spawn-convo-btn")
    |> render_click()

    # Verify a conversation card appeared in the stream
    assert has_element?(view, "#conversations")
    assert render(view) =~ "conv-"
  end

  test "spawns a conversation when clicking empty state spawn button", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    view
    |> element("#empty-state-spawn-btn")
    |> render_click()

    # Verify a conversation card appeared in the stream
    assert has_element?(view, "#conversations")
    assert render(view) =~ "conv-"
  end

  test "renders accessibility attributes and data-confirm on conversation buttons", %{conn: conn} do
    {:ok, id} = ConvoSim.ConversationManager.start_conversation()

    {:ok, view, _html} = live(conn, ~p"/")

    assert has_element?(
             view,
             ~s|button#stop-btn-#{id}[data-confirm="Are you sure you want to stop this conversation?"]|
           )

    assert has_element?(view, ~s|button#stop-btn-#{id}[aria-label="Stop conversation #{id}"]|)
    assert has_element?(view, ~s|button#send-btn-#{id}[title="Send Customer Message"]|)

    ConvoSim.ConversationManager.stop_conversation(id)
  end

  test "loads existing active conversations concurrently on mount", %{conn: conn} do
    {:ok, id1} = ConvoSim.ConversationManager.start_conversation()
    {:ok, id2} = ConvoSim.ConversationManager.start_conversation()

    {:ok, view, _html} = live(conn, ~p"/")

    assert has_element?(view, "#conversations-#{id1}")
    assert has_element?(view, "#conversations-#{id2}")

    ConvoSim.ConversationManager.stop_conversation(id1)
    ConvoSim.ConversationManager.stop_conversation(id2)
  end

  test "displays error flash when spawn limit is reached", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    current_count = Registry.count(ConvoSim.ConversationRegistry)
    needed = max(0, 50 - current_count)

    for i <- 1..needed do
      Registry.register(ConvoSim.ConversationRegistry, "dash-limit-#{i}", :ok)
    end

    view
    |> element("#spawn-convo-btn")
    |> render_click()

    assert render(view) =~ "Maximum limit of 50 active conversations reached"

    for i <- 1..needed do
      Registry.unregister(ConvoSim.ConversationRegistry, "dash-limit-#{i}")
    end
  end

  describe "send_message event handling and edge cases" do
    test "sends a message to an active conversation and transitions state", %{conn: conn} do
      {:ok, id} = ConvoSim.ConversationManager.start_conversation()
      {:ok, view, _html} = live(conn, ~p"/")

      # Send a customer message via render_click on send button
      view
      |> element("#send-btn-#{id}")
      |> render_click()

      # Sync GenServer message processing
      [{pid, _}] = Registry.lookup(ConvoSim.ConversationRegistry, id)
      _ = :sys.get_state(pid)

      state = ConvoSim.ConversationManager.get_state(id)
      assert state.status == :responding
      assert state.message_count == 1

      ConvoSim.ConversationManager.stop_conversation(id)
    end

    test "rate limits rapid consecutive send_message clicks", %{conn: conn} do
      {:ok, id} = ConvoSim.ConversationManager.start_conversation()
      {:ok, view, _html} = live(conn, ~p"/")

      # First send
      view
      |> element("#send-btn-#{id}")
      |> render_click()

      # Rapid second send via render_hook
      assert render_hook(view, "send_message", %{"id" => id}) =~
               "Please wait a moment before sending another message to this conversation."

      ConvoSim.ConversationManager.stop_conversation(id)
    end

    test "rejects oversized or invalid IDs sent to send_message", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      oversized_id = String.duplicate("x", 65)

      # Should not crash or dispatch message
      render_hook(view, "send_message", %{"id" => oversized_id})
      render_hook(view, "send_message", %{"id" => 12345})
      render_hook(view, "send_message", %{"id" => nil})

      refute render(view) =~ oversized_id
    end
  end

  describe "stop_conversation event handling and edge cases" do
    test "stops active conversation, cleans up state, and removes card from stream", %{conn: conn} do
      {:ok, id} = ConvoSim.ConversationManager.start_conversation()
      {:ok, view, _html} = live(conn, ~p"/")

      assert has_element?(view, "#conversations-#{id}")

      # Trigger stop_conversation
      view
      |> element("#stop-btn-#{id}")
      |> render_click()

      refute has_element?(view, "#conversations-#{id}")
      assert ConvoSim.ConversationManager.stop_conversation(id) == {:error, :not_found}
    end

    test "rate limits rapid consecutive stop_conversation calls when first attempt fails or is repeated",
         %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      # First attempt with an id that fails to stop so entry is kept in last_stop_times
      render_hook(view, "stop_conversation", %{"id" => "conv-fail-stop"})

      # Immediate second attempt within 1000ms triggers rate limit
      assert render_hook(view, "stop_conversation", %{"id" => "conv-fail-stop"}) =~
               "Please wait a moment before trying to stop this conversation again."
    end

    test "displays error flash when stopping an already ended conversation", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      assert render_hook(view, "stop_conversation", %{"id" => "conv-nonexistent"}) =~
               "Failed to stop conversation. It may have already ended."
    end

    test "rejects oversized or invalid IDs sent to stop_conversation", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      oversized_id = String.duplicate("x", 65)

      render_hook(view, "stop_conversation", %{"id" => oversized_id})
      render_hook(view, "stop_conversation", %{"id" => 12345})
      render_hook(view, "stop_conversation", %{"id" => nil})

      # Still renders normally
      assert has_element?(view, "#conversations")
    end
  end

  describe "rate limiting and PubSub streaming" do
    test "rate limits rapid consecutive spawn_conversation clicks", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      view
      |> element("#spawn-convo-btn")
      |> render_click()

      assert render_hook(view, "spawn_conversation", %{}) =~
               "Please wait a moment before spawning another conversation."
    end

    test "updates conversation card when receiving PubSub broadcast", %{conn: conn} do
      {:ok, id} = ConvoSim.ConversationManager.start_conversation()
      {:ok, view, _html} = live(conn, ~p"/")

      # Initial state check
      assert render(view) =~ "Idle"

      # Broadcast status update
      updated_state = %ConvoSim.Conversation{
        id: id,
        status: :responding,
        message_count: 1,
        messages: [
          %{role: :customer, content: "Hello broadcast test", timestamp: DateTime.utc_now()}
        ],
        created_at: DateTime.utc_now()
      }

      send(view.pid, {:conversation_updated, id, updated_state})

      assert render(view) =~ "AI Responding..."
      assert render(view) =~ "Hello broadcast test"

      ConvoSim.ConversationManager.stop_conversation(id)
    end
  end
end
