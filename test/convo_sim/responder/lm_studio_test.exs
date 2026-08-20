defmodule ConvoSim.Responder.LMStudioTest do
  use ExUnit.Case, async: true

  alias ConvoSim.Responder.LMStudio

  test "gracefully handles connection failure with error message" do
    # Point to an unused local port
    Application.put_env(:convo_sim, :lm_studio_url, "http://127.0.0.1:59999")

    response = LMStudio.respond("Hello", [])
    assert response =~ "I'm sorry, I encountered an internal error"
  end
end
