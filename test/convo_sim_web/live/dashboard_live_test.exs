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

  describe "user interactions, edge cases, and rate limits" do
    test "sends a customer message to a conversation", %{conn: conn} do
      {:ok, id} = ConvoSim.ConversationManager.start_conversation()

      {:ok, view, _html} = live(conn, ~p"/")

      assert has_element?(view, "#send-btn-#{id}")

      view
      |> element("#send-btn-#{id}")
      |> render_click()

      # Verify the conversation process processed the message
      [{pid, _}] = Registry.lookup(ConvoSim.ConversationRegistry, id)
      _ = :sys.get_state(pid)

      state = ConvoSim.ConversationManager.get_state(id)
      assert state.message_count >= 1
      assert state.status == :responding

      ConvoSim.ConversationManager.stop_conversation(id)
    end

    test "stops a conversation and removes it from stream", %{conn: conn} do
      {:ok, id} = ConvoSim.ConversationManager.start_conversation()

      {:ok, view, _html} = live(conn, ~p"/")
      assert has_element?(view, "#conversations-#{id}")

      view
      |> element("#stop-btn-#{id}")
      |> render_click()

      refute has_element?(view, "#conversations-#{id}")
      assert Registry.lookup(ConvoSim.ConversationRegistry, id) == []
    end

    test "handles error flash when stopping an already terminated conversation", %{conn: conn} do
      {:ok, id} = ConvoSim.ConversationManager.start_conversation()

      {:ok, view, _html} = live(conn, ~p"/")

      # Stop the conversation externally first
      assert ConvoSim.ConversationManager.stop_conversation(id) == :ok
      _ = :sys.get_state(ConvoSim.ConversationRegistry)

      # Attempt to stop via dashboard event
      view
      |> element("#stop-btn-#{id}")
      |> render_click()

      assert render(view) =~ "Failed to stop conversation. It may have already ended."
    end

    test "rejects send_message and stop_conversation with oversized IDs (>64 bytes)", %{
      conn: conn
    } do
      {:ok, view, _html} = live(conn, ~p"/")

      oversized_id = String.duplicate("x", 65)

      # Direct LiveView event dispatch for oversized id
      render_hook(view, "send_message", %{"id" => oversized_id})
      render_hook(view, "stop_conversation", %{"id" => oversized_id})

      # No crashes, empty state still rendered
      assert has_element?(view, "#conversations")
    end

    test "enforces rate limits on spawn, message, and stop events", %{conn: conn} do
      {:ok, id} = ConvoSim.ConversationManager.start_conversation()
      {:ok, view, _html} = live(conn, ~p"/")

      # 1. Trigger spawn twice immediately to test spawn rate limit
      view
      |> element("#spawn-convo-btn")
      |> render_click()

      html_spawn_rate_limited =
        view
        |> element("#spawn-convo-btn")
        |> render_click()

      assert html_spawn_rate_limited =~
               "Please wait a moment before spawning another conversation."

      # 2. Trigger send_message twice immediately to test message rate limit
      view
      |> element("#send-btn-#{id}")
      |> render_click()

      # Because the conversation status transitions to :responding (which removes phx-click from the button),
      # sending the event directly via render_hook tests the server-side rate limit guard for send_message.
      html_msg_rate_limited =
        render_hook(view, "send_message", %{"id" => id})

      assert html_msg_rate_limited =~
               "Please wait a moment before sending another message to this conversation."

      # 3. Trigger stop_conversation with an unknown id twice immediately to test stop rate limit
      render_hook(view, "stop_conversation", %{"id" => "conv-mockrate1"})
      html_stop_rate_limited = render_hook(view, "stop_conversation", %{"id" => "conv-mockrate1"})

      assert html_stop_rate_limited =~
               "Please wait a moment before trying to stop this conversation again."

      _ = ConvoSim.ConversationManager.stop_conversation(id)
    end

    test "renders real-time PubSub updates for conversation state transitions and messages", %{
      conn: conn
    } do
      {:ok, view, _html} = live(conn, ~p"/")

      convo_id = "conv-testpub1"

      # Simulate PubSub update: conversation responding with customer message
      state_responding = %ConvoSim.Conversation{
        id: convo_id,
        status: :responding,
        message_count: 1,
        messages: [
          %{
            role: :customer,
            content: "Can you help me reset my password?",
            timestamp: DateTime.utc_now()
          }
        ]
      }

      send(view.pid, {:conversation_updated, convo_id, state_responding})

      html = render(view)
      assert html =~ convo_id
      assert html =~ "AI Responding..."
      assert html =~ "Can you help me reset my password?"
      assert html =~ "Customer"

      # Simulate PubSub update: AI response arrives, status becomes idle
      state_idle = %ConvoSim.Conversation{
        id: convo_id,
        status: :idle,
        message_count: 2,
        messages: [
          %{
            role: :assistant,
            content: "Sure, click on Forgot Password.",
            timestamp: DateTime.utc_now()
          },
          %{
            role: :customer,
            content: "Can you help me reset my password?",
            timestamp: DateTime.utc_now()
          }
        ]
      }

      send(view.pid, {:conversation_updated, convo_id, state_idle})

      html_idle = render(view)
      assert html_idle =~ "Idle"
      assert html_idle =~ "Sure, click on Forgot Password."
      assert html_idle =~ "AI Assistant"
    end
  end
end
