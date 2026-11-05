defmodule ConvoSim.Responder.LMStudioTest do
  use ExUnit.Case, async: false

  alias ConvoSim.Responder.LMStudio

  setup do
    # Ensure port 1234 is clean before each test if any prior process was running
    :ok
  end

  defmodule StubServer do
    def init(opts), do: opts

    def call(conn, _opts) do
      {:ok, body, conn} = Plug.Conn.read_body(conn)
      decoded_body = if body != "", do: Jason.decode!(body), else: %{}

      # Retrieve handler or status configured for this test run
      handler = Application.get_env(:convo_sim, :stub_handler)

      case handler do
        nil ->
          conn
          |> Plug.Conn.put_resp_content_type("application/json")
          |> Plug.Conn.send_resp(
            200,
            Jason.encode!(%{
              "choices" => [
                %{"message" => %{"content" => "Hello from AI assistant!"}}
              ]
            })
          )

        fun when is_function(fun, 2) ->
          fun.(conn, decoded_body)
      end
    end
  end

  test "gracefully handles connection failure with error message" do
    # When no server is running on port 1234, LMStudio returns internal error message
    response = LMStudio.respond("Hello", [])
    assert response =~ "I'm sorry, I encountered an internal error"
  end

  test "successfully parses 200 OK OpenAI format response and sends conversation history" do
    test_pid = self()

    Application.put_env(:convo_sim, :stub_handler, fn conn, decoded_body ->
      send(test_pid, {:received_request, decoded_body})

      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.send_resp(
        200,
        Jason.encode!(%{
          "choices" => [
            %{
              "message" => %{
                "role" => "assistant",
                "content" => "I can certainly help you with your account!"
              }
            }
          ]
        })
      )
    end)

    on_exit(fn -> Application.delete_env(:convo_sim, :stub_handler) end)

    start_supervised!({Bandit, plug: StubServer, port: 1234})

    history = [
      %{role: :assistant, content: "Previous answer"},
      %{role: :customer, content: "Previous question"}
    ]

    response = LMStudio.respond("Current question", history)

    assert response == "I can certainly help you with your account!"

    assert_receive {:received_request, req_body}
    assert req_body["model"] == "qwen2.5-coder-3b-instruct"
    messages = req_body["messages"]

    # History is newest-first in arguments:
    # hd is %{role: :assistant, content: "Previous answer"}
    # tl is %{role: :customer, content: "Previous question"}
    # build_messages should order them chronologically:
    # 1. System prompt
    # 2. Previous question (user)
    # 3. Previous answer (assistant)
    # 4. Current question (user)
    assert length(messages) == 4
    assert Enum.at(messages, 0)["role"] == "system"
    assert Enum.at(messages, 1) == %{"role" => "user", "content" => "Previous question"}
    assert Enum.at(messages, 2) == %{"role" => "assistant", "content" => "Previous answer"}
    assert Enum.at(messages, 3) == %{"role" => "user", "content" => "Current question"}
  end

  test "handles 200 OK with malformed choices structure gracefully" do
    Application.put_env(:convo_sim, :stub_handler, fn conn, _decoded ->
      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.send_resp(200, Jason.encode!(%{"choices" => []}))
    end)

    on_exit(fn -> Application.delete_env(:convo_sim, :stub_handler) end)

    start_supervised!({Bandit, plug: StubServer, port: 1234})

    response = LMStudio.respond("Hello", [])
    assert response == "I'm sorry, I couldn't generate a response."
  end

  test "handles non-200 HTTP response codes from LM Studio" do
    Application.put_env(:convo_sim, :stub_handler, fn conn, _decoded ->
      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.send_resp(500, Jason.encode!(%{"error" => "Internal model error"}))
    end)

    on_exit(fn -> Application.delete_env(:convo_sim, :stub_handler) end)

    start_supervised!({Bandit, plug: StubServer, port: 1234})

    response = LMStudio.respond("Hello", [])
    assert response =~ "I'm sorry, I encountered an internal error"
  end
end
