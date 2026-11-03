# ConvoSim Architecture & Concurrency Design

This document details the architectural design and concurrency model behind **ConvoSim**, demonstrating how BEAM processes, OTP supervision trees, and Phoenix LiveView cooperate to achieve scalable, real-time simulated customer conversations.

---

## 1. Concurrency Model: Process Isolation on the BEAM

In ConvoSim, each customer conversation is modeled as an independent, lightweight Elixir process (`GenServer`) rather than a row in a relational database or an entry in a shared in-memory dictionary.

### Key Benefits
- **Fault Isolation**: If an unhandled exception occurs while processing an individual conversation's state or interacting with an external LLM, only that specific conversation process crashes. Other concurrent conversations continue running without interruption.
- **Preemptive Scheduling**: BEAM schedules process execution using reductions. Even when hundreds of conversations handle incoming messages simultaneously, no single conversation can monopolize system CPU time.
- **Non-Blocking External I/O**: When generating AI responses (e.g. calling LM Studio via HTTP), the conversation process delegates the network I/O to a background asynchronous `Task`. The GenServer process itself remains responsive and can receive other messages or status requests without blocking its message queue.

---

## 2. Supervision Tree & Process Lifecycle

The supervision tree is initialized in `ConvoSim.Application` with the following hierarchy:

```
ConvoSim.Supervisor (one_for_one)
├── ConvoSimWeb.Telemetry
├── DNSCluster
├── ConvoSim.PubSub (Phoenix.PubSub)
├── ConvoSim.ConversationRegistry (Elixir Registry)
├── ConvoSim.ConversationSupervisor (DynamicSupervisor)
└── ConvoSimWeb.Endpoint (Bandit HTTP / WebSocket Server)
```

### Dynamic Supervision (`ConvoSim.ConversationSupervisor`)
- Active conversations are started dynamically under `ConvoSim.ConversationSupervisor` using `restart: :temporary`.
- Because conversations represent temporary simulated sessions, terminating a conversation cleans up the process without triggering an automatic restart by the supervisor.
- A maximum concurrency ceiling of 50 active conversations is enforced by `ConvoSim.ConversationManager` before starting a child, preventing resource exhaustion (DoS).

---

## 3. State Management & O(1) Lookups via `Registry`

Rather than relying on named atoms (which are not garbage collected) or querying all processes via sequential `GenServer.call` invocations (which would introduce an $O(N)$ N+1 bottleneck), ConvoSim uses Elixir's `Registry`:

1. **Process Registration**: Each conversation registers under `ConvoSim.ConversationRegistry` using a `:via` tuple:
   ```elixir
   {:via, Registry, {ConvoSim.ConversationRegistry, id, initial_state}}
   ```
2. **State Caching in Registry Values**: Whenever a conversation's state changes (e.g., status changes to `:responding` or new messages are appended), the GenServer updates its associated value in the Registry ETS table using `Registry.update_value/3`.
3. **$O(1)$ State Querying**:
   - A single conversation's state can be fetched in $O(1)$ directly from the Registry value via `Registry.lookup/2` without messaging the GenServer process.
   - All active conversations can be retrieved simultaneously via `Registry.select/2` in a single native ETS match, avoiding process message queue latency during dashboard renders.

---

## 4. Real-Time Synchronization via `Phoenix.PubSub`

ConvoSim synchronizes conversation events across all connected browser clients via `Phoenix.PubSub`:

- **Global Topic (`"conversations"`)**: Broadcasts state updates (`{:conversation_updated, id, state}`) whenever a conversation starts, receives a message, begins responding, or finishes responding.
- **Per-Conversation Topic (`"conversation:<id>"`)**: Scoped updates for views or clients focusing on an individual conversation session.
- **LiveView Stream Consumption**: `ConvoSimWeb.DashboardLive` subscribes to `"conversations"` upon WebSocket connection and streams updates directly into the UI with minimal DOM patching via `stream_insert/3` and `stream_delete/3`.

---

## 5. AI Responder Architecture (`ConvoSim.Responder`)

The `ConvoSim.Responder` behaviour defines the contract for AI integration:

```elixir
@callback respond(message :: String.t(), history :: list()) :: String.t()
```

### Implementations
- **`ConvoSim.Responder.LMStudio`**: Connects via `Req` to local OpenAI-compatible endpoints (`/v1/chat/completions`), constructing conversation history chronologically and returning LLM responses.
- **`ConvoSim.Responder.Simulated`**: Offline responder generating simulated customer support replies with realistic randomized latency (1–4 seconds), ideal for automated testing and offline development.
