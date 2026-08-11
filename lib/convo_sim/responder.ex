defmodule ConvoSim.Responder do
  @moduledoc """
  Behaviour defining the contract for AI responders.
  """

  @doc "Given a customer message and conversation history, return an AI response string."
  @callback respond(message :: String.t(), history :: list()) :: String.t()
end

defmodule ConvoSim.Responder.Simulated do
  @moduledoc """
  A simulated responder that returns a random canned response after a delay.
  """

  @behaviour ConvoSim.Responder

  @canned_responses [
    "Hello! How can I help you today?",
    "That is an interesting question.",
    "Let me check on that for you.",
    "I understand your concern. We are looking into it.",
    "Could you provide more details please?",
    "Thank you for sharing that with us.",
    "I am just a simulation, but I try my best!",
    "Have a wonderful day!"
  ]

  @impl ConvoSim.Responder
  def respond(_message, _history) do
    # Sleep between 1000 and 4000 milliseconds to simulate AI processing time
    # The sleep happens in the calling process (which will be a Task, not the GenServer),
    # so it does not block the GenServer from handling other messages.
    delay = Enum.random(1000..4000)
    Process.sleep(delay)

    Enum.random(@canned_responses)
  end
end
