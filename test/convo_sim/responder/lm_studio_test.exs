defmodule ConvoSim.Responder.LMStudioTest do
  use ExUnit.Case, async: false

  alias ConvoSim.Responder.LMStudio

  @port 1234
  @ip {127, 0, 0, 1}

  defp start_mock_server!(plug_fun) do
    # Bandit child specification using start_supervised! to guarantee cleanup
    child_spec = {Bandit, plug: plug_fun, port: @port, ip: @ip}
    start_supervised!(child_spec)
  end

  describe "respond/2" do
    test "handles successful 200 OK response and extracts content" do
      test_pid = self()

      start_mock_server!(fn conn, _opts ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        send(test_pid, {:received_payload, Jason.decode!(body)})

        json_reply =
          Jason.encode!(%{
            "choices" => [
              %{"message" => %{"content" => "Hello! How can I assist you?"}}
            ]
          })

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, json_reply)
      end)

      # Test with conversation history containing both customer and assistant roles
      # Note: history in Conversation GenServer is stored newest-first
      history = [
        %{role: :assistant, content: "What is your order number?"},
        %{role: :customer, content: "I need to check order status."}
      ]

      response = LMStudio.respond("My order number is 12345", history)

      assert response == "Hello! How can I assist you?"

      assert_receive {:received_payload, payload}
      assert payload["model"] == "qwen2.5-coder-3b-instruct"
      assert payload["temperature"] == 0.7
      assert payload["max_tokens"] == 150

      # Verify message structure:
      # [0] System prompt
      # [1] Customer message ("I need to check order status.") -> role: "user"
      # [2] Assistant message ("What is your order number?") -> role: "assistant"
      # [3] Current message ("My order number is 12345") -> role: "user"
      messages = payload["messages"]
      assert length(messages) == 4

      [system_msg, prev_user, prev_assistant, current_msg] = messages
      assert system_msg["role"] == "system"
      assert system_msg["content"] =~ "customer support assistant"

      assert prev_user["role"] == "user"
      assert prev_user["content"] == "I need to check order status."

      assert prev_assistant["role"] == "assistant"
      assert prev_assistant["content"] == "What is your order number?"

      assert current_msg["role"] == "user"
      assert current_msg["content"] == "My order number is 12345"
    end

    test "handles other/custom roles in history by mapping them to assistant" do
      test_pid = self()

      start_mock_server!(fn conn, _opts ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        send(test_pid, {:received_payload, Jason.decode!(body)})

        json_reply =
          Jason.encode!(%{
            "choices" => [
              %{"message" => %{"content" => "Custom role handled."}}
            ]
          })

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, json_reply)
      end)

      history = [
        %{role: :custom_agent, content: "Custom agent prompt."}
      ]

      response = LMStudio.respond("Follow-up inquiry", history)

      assert response == "Custom role handled."

      assert_receive {:received_payload, payload}
      [_system_msg, custom_msg, _current_msg] = payload["messages"]
      assert custom_msg["role"] == "assistant"
      assert custom_msg["content"] == "Custom agent prompt."
    end

    test "returns fallback when 200 OK has empty choices or unexpected body shape" do
      start_mock_server!(fn conn, _opts ->
        json_reply =
          Jason.encode!(%{
            "choices" => []
          })

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, json_reply)
      end)

      response = LMStudio.respond("Hello", [])
      assert response == "I'm sorry, I couldn't generate a response."
    end

    test "returns fallback when 200 OK choices contain non-binary content" do
      start_mock_server!(fn conn, _opts ->
        json_reply =
          Jason.encode!(%{
            "choices" => [
              %{"message" => %{"content" => nil}}
            ]
          })

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, json_reply)
      end)

      response = LMStudio.respond("Hello", [])
      assert response == "I'm sorry, I couldn't generate a response."
    end

    test "handles non-200 HTTP error responses gracefully" do
      start_mock_server!(fn conn, _opts ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(500, Jason.encode!(%{"error" => "Internal model crash"}))
      end)

      response = LMStudio.respond("Hello", [])
      assert response =~ "I'm sorry, I encountered an internal error"
    end

    test "handles HTTP 429 rate limit or 400 bad request error responses" do
      start_mock_server!(fn conn, _opts ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(429, Jason.encode!(%{"error" => "Too Many Requests"}))
      end)

      response = LMStudio.respond("Hello", [])
      assert response =~ "I'm sorry, I encountered an internal error"
    end

    test "gracefully handles connection failure when server is unreachable" do
      # Since no mock server is started in this test on port 1234, the connection fails with :econnrefused
      response = LMStudio.respond("Hello", [])
      assert response =~ "I'm sorry, I encountered an internal error"
    end
  end
end
