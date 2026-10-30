# ConvoSim 💬

**ConvoSim** is a real-time customer conversation simulator built with Elixir and Phoenix LiveView. It demonstrates OTP concurrency and process architecture by managing each conversation as an isolated BEAM process (GenServer).

---

## 🚀 Key Architectural Highlights

- **`ConvoSim.Conversation` (GenServer)**: Each active customer conversation is run in its own GenServer process state, holding conversation history, status, message count, and timestamps.
- **`ConvoSim.ConversationSupervisor` (DynamicSupervisor)**: Manages dynamic lifecycle spawning and termination of individual conversation processes (`strategy: :one_for_one`).
- **`ConvoSim.ConversationRegistry` (Registry)**: Provides fast `:unique` lookup and custom via-tuple registration for conversation processes while storing state values natively for $O(1)$ ETS state fetching without process bottlenecks.
- **`Phoenix.PubSub`**: Broadcasts real-time state updates (`conversations` and `conversation:<id>` topics) to connected LiveView subscribers.
- **Asynchronous Task Responders**: AI responses block only isolated `Task` processes while keeping the main conversation GenServers responsive.

---

## 🛠️ Prerequisites & Setup

### Requirements
- **Elixir**: 1.14+ (compiled with OTP 25+)
- **Erlang/OTP**: 25+
- **Node.js**: 18+ (for asset compilation via Tailwind and Esbuild)

### Quick Start

1. Install and setup project dependencies:
   ```bash
   mix setup
   ```

2. Start the Phoenix server:
   ```bash
   mix phx.server
   ```
   Or start inside Interactive Elixir (IEx):
   ```bash
   iex -S mix phx.server
   ```

3. Open your browser and navigate to [`http://localhost:4000`](http://localhost:4000).

---

## ⚙️ Configuration & Responders

ConvoSim supports multiple AI responder backends, configured in `config/dev.exs` or `config/config.exs`.

### 1. Simulated Responder (`ConvoSim.Responder.Simulated`)
Ideal for offline development and fast testing without external dependencies. Simulates AI response latency (1-4 seconds) and returns random canned support responses.

```elixir
config :convo_sim, :responder, ConvoSim.Responder.Simulated
```

### 2. LM Studio / OpenAI-Compatible Responder (`ConvoSim.Responder.LMStudio`)
Connects to a local LM Studio instance (or any OpenAI `/v1/chat/completions` API endpoint).

```elixir
config :convo_sim, :responder, ConvoSim.Responder.LMStudio
config :convo_sim, :lm_studio_url, "http://127.0.0.1:1234"
config :convo_sim, :lm_studio_model, "qwen2.5-coder-3b-instruct"
```

---

## 🧪 Testing & Code Quality

Run unit and integration tests:
```bash
mix test
```

Check code formatting:
```bash
mix format --check
```

Run pre-commit checks and linter aliases:
```bash
mix precommit
```

---

## 📚 Learn More

- **Phoenix Framework Documentation**: https://phoenix.hexdocs.pm
- **Elixir OTP Documentation**: https://elixir-lang.org/getting-started/mix-otp/genserver.html
