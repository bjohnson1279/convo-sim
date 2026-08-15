defmodule ConvoSimWeb.DashboardLiveTest do
  use ConvoSimWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  test "renders dashboard title and empty state", %{conn: conn} do
    {:ok, view, html} = live(conn, ~p"/")

    assert html =~ "Real-Time Conversation Simulator"
    assert has_element?(view, "#spawn-convo-btn")
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

  test "renders accessibility attributes and data-confirm on conversation buttons", %{conn: conn} do
    {:ok, id} = ConvoSim.ConversationManager.start_conversation()

    {:ok, view, _html} = live(conn, ~p"/")

    assert has_element?(
             view,
             ~s|button#stop-btn-#{id}[data-confirm="Are you sure you want to stop this conversation?"]|
           )

    assert has_element?(view, ~s|button#stop-btn-#{id}[aria-label="Stop Conversation"]|)
    assert has_element?(view, ~s|button#send-btn-#{id}|)

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
end
