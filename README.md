# ConvoSim

Real-Time Customer Conversation Simulator demonstrating BEAM and OTP concurrency with Phoenix LiveView.

Each active customer conversation runs as an isolated GenServer process under a `DynamicSupervisor`. State synchronization across browser clients is managed via `Phoenix.PubSub` and backed by `Registry` for O(1) in-memory state lookups.

---

## Architecture Overview

- **`ConvoSim.Conversation`**: GenServer representing a single customer conversation. Tracks conversation messages, status (`:idle` vs `:responding`), and delegates AI responses to asynchronous background tasks without blocking process message queues.
- **`ConvoSim.ConversationManager`**: Facade module managing conversation lifecycles under `ConvoSim.ConversationSupervisor` (`DynamicSupervisor`) and querying active conversations from `ConvoSim.ConversationRegistry` (`Registry`). Enforces a maximum limit of 50 concurrent active conversations.
- **`ConvoSim.Responder`**: Behaviour module defining the contract for AI responders.
  - `ConvoSim.Responder.LMStudio`: Connects to a local LM Studio OpenAI-compatible endpoint (`/v1/chat/completions`) using Req.
  - `ConvoSim.Responder.Simulated`: Offline responder providing simulated AI responses with randomized realistic typing latency.
- **`ConvoSimWeb.DashboardLive`**: Real-time Phoenix LiveView dashboard consuming PubSub updates and rendering streamed conversation cards.

---

## Prerequisites

- **Elixir**: `~> 1.17` (tested with 1.17 and 1.18)
- **Erlang/OTP**: `25` or higher (tested with OTP 25, 27)
- **Node.js** (optional, assets are handled via standalone `esbuild` and `tailwind` mix packages)
- **Docker & Docker Compose** (optional, for containerized development)

---

## Getting Started

### Local Setup

1. **Install dependencies and setup assets:**
   ```bash
   mix setup
   ```

2. **Start the Phoenix server:**
   ```bash
   mix phx.server
   ```
   Or run interactively inside IEx:
   ```bash
   iex -S mix phx.server
   ```

3. Visit [`http://localhost:4000`](http://localhost:4000) in your web browser.

### Docker Setup

You can also run ConvoSim using Docker and Docker Compose:

```bash
docker compose up --build
```

The application will be accessible at [`http://localhost:4000`](http://localhost:4000).

---

## Configuration & Environment Variables

Key environment variables used across development and production:

| Variable | Default (Dev) | Description |
| :--- | :--- | :--- |
| `PORT` | `4000` | HTTP port on which the web server listens. |
| `PHX_SERVER` | unset (`false`) | Set to `true` (or `1`) to start the HTTP endpoint when running via releases. |
| `PHX_HOST` | `example.com` (Prod) | Hostname used for URL generation in production. |
| `SECRET_KEY_BASE` | Dummy fallback in dev/test | Secret key base used for signing session cookies and tokens (required in production). Generate with `mix phx.gen.secret`. |
| `SESSION_SIGNING_SALT`| Dummy fallback in dev/test | Signing salt used for live session cookies (required in production). |
| `DNS_CLUSTER_QUERY` | unset | Service name query for clustering nodes via DNS (e.g. Fly.io). |

### AI Responder Configuration

Configure the responder implementation in `config/dev.exs` or `config/runtime.exs`:

```elixir
# LM Studio (default in dev)
config :convo_sim, :responder, ConvoSim.Responder.LMStudio
config :convo_sim, :lm_studio_url, "http://127.0.0.1:1234"
config :convo_sim, :lm_studio_model, "qwen2.5-coder-3b-instruct"

# Offline / Simulated Responder (no external LLM server needed)
config :convo_sim, :responder, ConvoSim.Responder.Simulated
```

---

## Running Tests & Code Quality Checks

Run the automated test suite:
```bash
mix test
```

Check code formatting:
```bash
mix format --check-formatted
```

Run the complete pre-commit verification pipeline:
```bash
mix precommit
```
*(Runs `compile --warnings-as-errors`, `deps.unlock --unused`, `format`, and `test`)*
