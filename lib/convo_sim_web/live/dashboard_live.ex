defmodule ConvoSimWeb.DashboardLive do
  use ConvoSimWeb, :live_view

  alias ConvoSim.ConversationManager

  @impl true
  def mount(_params, _session, socket) do
    # Only subscribe if connected to avoid subscribing twice (HTTP mount + WebSocket mount)
    if connected?(socket) do
      Phoenix.PubSub.subscribe(ConvoSim.PubSub, "conversations")
    end

    # Fetch initial active conversations
    conversations = load_conversations()

    {:ok,
     socket
     |> assign(:page_title, "Conversation Simulator")
     |> stream(:conversations, conversations)}
  end

  @impl true
  def handle_event("spawn_conversation", _params, socket) do
    case ConversationManager.start_conversation() do
      {:ok, _id} ->
        {:noreply, put_flash(socket, :info, "Started new conversation")}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Failed to start: #{inspect(reason)}")}
    end
  end

  @impl true
  def handle_event("send_message", %{"id" => id}, socket) do
    default_messages = [
      "Hello, I need help with my account billing.",
      "Can I change my subscription plan?",
      "My order hasn't arrived yet, where is it?",
      "Is there a discount available for annual plans?",
      "I am having trouble logging into my account."
    ]

    sample_msg = Enum.random(default_messages)
    ConvoSim.Conversation.send_message(id, sample_msg)

    {:noreply, socket}
  end

  @impl true
  def handle_event("stop_conversation", %{"id" => id}, socket) do
    case ConversationManager.stop_conversation(id) do
      :ok ->
        # Remove from local stream
        {:noreply, stream_delete_by_id(socket, :conversations, id)}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Failed to stop: #{inspect(reason)}")}
    end
  end

  @impl true
  def handle_info({:conversation_updated, _id, state}, socket) do
    # Stream insert automatically adds or updates an item in the stream by its DOM ID
    {:noreply, stream_insert(socket, :conversations, state)}
  end

  defp load_conversations do
    ConversationManager.list_conversations()
    # ⚡ Bolt: Optimize sequential state fetching by loading in parallel
    |> Task.async_stream(&ConversationManager.get_state/1,
      max_concurrency: System.schedulers_online() * 2,
      timeout: :infinity
    )
    |> Enum.map(fn {:ok, state} -> state end)
  end

  defp stream_delete_by_id(socket, stream_name, id) do
    # Stream delete expects a struct or map with an :id field
    stream_delete(socket, stream_name, %{id: id})
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div class="space-y-6">
        <%!-- Header Banner --%>
        <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4 p-6 bg-slate-900 border border-slate-800 rounded-2xl shadow-xl">
          <div>
            <h1 class="text-2xl font-bold text-slate-100 flex items-center gap-2">
              <.icon name="hero-chat-bubble-left-right" class="w-7 h-7 text-indigo-400" />
              Real-Time Conversation Simulator
            </h1>
            
            <p class="text-sm text-slate-400 mt-1">
              Demonstrating OTP concurrency — each conversation is an isolated BEAM process.
            </p>
          </div>
          
          <div>
            <button
              id="spawn-convo-btn"
              phx-click="spawn_conversation"
              class="px-5 py-2.5 bg-indigo-600 hover:bg-indigo-500 text-white text-sm font-semibold rounded-xl transition shadow-lg shadow-indigo-500/20 active:scale-95 flex items-center gap-2"
            >
              <.icon name="hero-plus" class="w-4 h-4" /> Spawn Conversation
            </button>
          </div>
        </div>
         <%!-- Conversation Cards Grid --%>
        <div
          id="conversations"
          phx-update="stream"
          class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4"
        >
          <div
            id="empty-state"
            class="hidden only:flex col-span-full flex-col items-center justify-center p-12 text-center bg-slate-900/50 border border-dashed border-slate-800 rounded-2xl"
          >
            <.icon name="hero-chat-bubble-oval-left" class="w-12 h-12 text-slate-600 mb-3" />
            <h3 class="text-base font-semibold text-slate-300">No Active Conversations</h3>
            
            <p class="text-sm text-slate-500 mt-1 max-w-sm">
              Click "Spawn Conversation" above to launch lightweight GenServer processes on the BEAM VM.
            </p>
          </div>
          
          <div
            :for={{dom_id, convo} <- @streams.conversations}
            id={dom_id}
            class="flex flex-col bg-slate-900 border border-slate-800 rounded-2xl p-5 shadow-lg transition hover:border-slate-700"
          >
            <%!-- Card Header --%>
            <div class="flex items-center justify-between pb-3 border-b border-slate-800/80">
              <div class="flex items-center gap-2">
                <span class="font-mono text-xs font-semibold px-2.5 py-1 bg-slate-800 text-indigo-300 rounded-lg border border-slate-700/50">
                  {convo.id}
                </span>
                
                <span class="text-xs text-slate-500">
                  {length(convo.messages)} msgs
                </span>
              </div>
               <%!-- Status Pill --%>
              <%= if convo.status == :responding do %>
                <span class="inline-flex items-center gap-1.5 text-xs font-medium px-2.5 py-1 rounded-full bg-amber-500/10 text-amber-400 border border-amber-500/20 animate-pulse">
                  <span class="w-1.5 h-1.5 rounded-full bg-amber-400"></span> AI Responding...
                </span>
              <% else %>
                <span class="inline-flex items-center gap-1.5 text-xs font-medium px-2.5 py-1 rounded-full bg-emerald-500/10 text-emerald-400 border border-emerald-500/20">
                  <span class="w-1.5 h-1.5 rounded-full bg-emerald-400"></span> Idle
                </span>
              <% end %>
            </div>
             <%!-- Messages Scroll Box --%>
            <div class="flex-1 my-4 space-y-3 min-h-[160px] max-h-[240px] overflow-y-auto pr-1 text-xs scrollbar-thin">
              <%= if convo.messages == [] do %>
                <div class="h-full flex items-center justify-center text-slate-600 italic">
                  No messages yet. Click "Send Message".
                </div>
              <% else %>
                <%= for msg <- convo.messages do %>
                  <div class={[
                    "p-3 rounded-xl max-w-[85%]",
                    if(msg.role == :customer,
                      do: "ml-auto bg-indigo-600/20 border border-indigo-500/30 text-indigo-100",
                      else: "mr-auto bg-slate-800/90 border border-slate-700/50 text-slate-200"
                    )
                  ]}>
                    <div class="font-semibold text-[10px] uppercase tracking-wider mb-1 opacity-70">
                      {if(msg.role == :customer, do: "Customer", else: "AI Assistant")}
                    </div>
                    
                    <div>{msg.content}</div>
                  </div>
                <% end %>
              <% end %>
            </div>
             <%!-- Card Actions --%>
            <div class="pt-3 border-t border-slate-800/80 flex items-center justify-between gap-2">
              <button
                id={"send-btn-#{convo.id}"}
                phx-click="send_message"
                phx-value-id={convo.id}
                disabled={convo.status == :responding}
                class="flex-1 py-1.5 px-3 bg-slate-800 hover:bg-slate-700 disabled:opacity-50 disabled:cursor-not-allowed text-slate-200 text-xs font-medium rounded-lg transition border border-slate-700/60 flex items-center justify-center gap-1.5"
              >
                <.icon name="hero-paper-airplane" class="w-3.5 h-3.5" /> Send Customer Message
              </button>
              
              <button
                id={"stop-btn-#{convo.id}"}
                phx-click="stop_conversation"
                phx-value-id={convo.id}
                data-confirm="Are you sure you want to stop this conversation?"
                aria-label="Stop Conversation"
                class="py-1.5 px-2.5 bg-red-950/40 hover:bg-red-900/60 text-red-400 text-xs font-medium rounded-lg transition border border-red-900/50 flex items-center justify-center focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-red-500"
                title="Stop Process"
              >
                <.icon name="hero-trash" class="w-3.5 h-3.5" />
              </button>
            </div>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
