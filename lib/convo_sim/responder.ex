defmodule ConvoSim.Responder do
  @moduledoc """
  Behaviour defining the contract for AI responders.
  """

  @doc "Given a customer message and conversation history (newest-first), return an AI response string."
  @callback respond(message :: String.t(), history :: list()) :: String.t()
end

defmodule ConvoSim.Responder.Simulated do
  @moduledoc """
  A simulated responder that returns a random canned response after a delay.
  """

  @behaviour ConvoSim.Responder

  # Converted to a tuple for O(1) random element selection without list traversal.
  @canned_responses {
    "Hello! How can I help you today?",
    "That is an interesting question.",
    "Let me check on that for you.",
    "I understand your concern. We are looking into it.",
    "Could you provide more details please?",
    "Thank you for sharing that with us.",
    "I am just a simulation, but I try my best!",
    "Have a wonderful day!"
  }
  @canned_responses_size tuple_size(@canned_responses)

  @impl ConvoSim.Responder
  def respond(_message, _history) do
    # Sleep between 1000 and 4000 milliseconds to simulate AI processing time
    # The sleep happens in the calling process (which will be a Task, not the GenServer),
    # so it does not block the GenServer from handling other messages.
    # Equivalent to Enum.random(1000..4000)
    delay = :rand.uniform(3001) + 999
    Process.sleep(delay)

    elem(@canned_responses, :rand.uniform(@canned_responses_size) - 1)
  end
end
