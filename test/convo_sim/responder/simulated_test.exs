defmodule ConvoSim.Responder.SimulatedTest do
  use ExUnit.Case, async: true

  alias ConvoSim.Responder.Simulated

  @valid_responses [
    "Hello! How can I help you today?",
    "That is an interesting question.",
    "Let me check on that for you.",
    "I understand your concern. We are looking into it.",
    "Could you provide more details please?",
    "Thank you for sharing that with us.",
    "I am just a simulation, but I try my best!",
    "Have a wonderful day!"
  ]

  test "returns a valid canned response string with empty history" do
    response = Simulated.respond("Hello simulation", [])
    assert is_binary(response)
    assert response in @valid_responses
  end

  test "returns a valid canned response string with multi-turn history" do
    history = [
      %{role: :customer, content: "First question"},
      %{role: :assistant, content: "First response"}
    ]

    response = Simulated.respond("Follow-up question", history)
    assert is_binary(response)
    assert response in @valid_responses
  end
end
