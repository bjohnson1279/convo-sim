defmodule ConvoSim.Responder.LMStudio do
  @moduledoc """
  Responder that calls a local LM Studio instance via its OpenAI-compatible API.

  LM Studio exposes a standard OpenAI `/v1/chat/completions` endpoint, so this
  module works with any model loaded in LM Studio (Qwen, Gemma, Llama, etc.).

  ## How this demonstrates real-world BEAM concurrency

  In production, this is exactly how you'd call OpenAI/Anthropic per-conversation:
  each conversation's GenServer spawns a Task that makes this HTTP call. The Task
  blocks on the network I/O, but the GenServer (and every other conversation) stays
  responsive because BEAM processes are preemptively scheduled. 500 conversations
  can all be waiting on API responses simultaneously without any thread pool
  exhaustion — the BEAM scheduler handles it.
  """

  @behaviour ConvoSim.Responder

  require Logger

  # Default system prompt that gives the AI a customer-service persona
  @system_prompt """
  You are a helpful, friendly customer support assistant. Keep your responses
  concise (2-3 sentences max). Be warm but professional.
  """

  @impl ConvoSim.Responder
  def respond(message, history) do
    # Build the messages array in OpenAI chat format
    # The history gives the AI context of the full conversation so far
    messages = build_messages(history, message)

    # Get config — these are set in config/dev.exs
    base_url = Application.get_env(:convo_sim, :lm_studio_url, "http://127.0.0.1:1234")
    model = Application.get_env(:convo_sim, :lm_studio_model, "qwen2.5-coder-3b-instruct")

    # Make the API call using Req (the preferred Elixir HTTP client).
    # This call blocks the current process (a Task) until the response arrives,
    # but does NOT block the calling GenServer — that's the whole point.
    case Req.post("#{base_url}/v1/chat/completions",
           json: %{
             model: model,
             messages: messages,
             temperature: 0.7,
             max_tokens: 150
           },
           # LM Studio can be slow with larger models — give it room
           receive_timeout: 30_000
         ) do
      {:ok, %{status: 200, body: body}} ->
        # Extract the assistant's reply from the OpenAI-format response
        # body is already decoded as a map because Req auto-decodes JSON
        get_in(body, ["choices", Access.at(0), "message", "content"]) ||
          "I'm sorry, I couldn't generate a response."

      {:ok, %{status: status, body: body}} ->
        Logger.error("LM Studio returned HTTP #{status}: #{inspect(body)}")
        "⚠️ I'm sorry, I encountered an internal error."

      {:error, reason} ->
        Logger.error("Failed to reach LM Studio: #{inspect(reason)}")
        "⚠️ I'm sorry, I encountered an internal error."
    end
  end

  # Converts our internal message format to OpenAI's chat format
  defp build_messages(history, current_message) do
    # ⚡ Bolt: Use Enum.reduce to build the chronological list in O(N) single pass
    # from the newest-first history list without using O(N) ++ concatenation.
    acc = [%{role: "user", content: current_message}]

    past_and_current =
      Enum.reduce(history, acc, fn msg, acc_list ->
        role = if msg.role == :customer, do: "user", else: "assistant"
        [%{role: role, content: msg.content} | acc_list]
      end)

    [%{role: "system", content: @system_prompt} | past_and_current]
  end
end
