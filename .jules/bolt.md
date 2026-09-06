## 2024-08-14 - N+1 process state fetching in BEAM
**Learning:** In Phoenix/Elixir apps, sequentially fetching state from many processes (e.g., using `Enum.map` with `GenServer.call`) causes an N+1 bottleneck. Since each process has its own message queue, these independent requests can be processed concurrently.
**Action:** Use `Task.async_stream` instead of `Enum.map` when fetching state from multiple independent GenServers to parallelize the calls and drastically reduce overall latency.

## 2026-08-15 - [O(1) List Prepending]
**Learning:** Appending to a linked list via `list ++ [new_item]` inside a long-running process (like a GenServer state) causes `O(N^2)` accumulation performance because `++` has to copy the entire list on every append. Reversing the list dynamically inside `handle_call` or right before broadcasting is surprisingly fast compared to the penalty of `++` copying for large state lists.
**Action:** When accumulating state over time in Elixir GenServers, ALWAYS prepend lists (`[item | list]`) which is `O(1)`. Only reverse the list via `Enum.reverse/1` right at the edge when formatting the state for the UI, broadcasts, or returning to callers.


## 2024-05-20 - O(N) length/1 penalty in Elixir templates
**Learning:** `length/1` in Elixir is an `O(N)` operation because it traverses the entire linked list to count its elements. Calling it within a LiveView template (e.g. `{length(list)}`) means this `O(N)` penalty is paid on every re-render. As lists (like conversation histories) grow, this can degrade rendering performance.
**Action:** When you need the length of a frequently-updated list in a LiveView, track the count as an integer property in the state struct (e.g., `message_count: 0`), and increment it when prepending items. This turns the UI lookup into an `O(1)` property access.
## 2024-05-24 - [O(1) Chat Rendering with flex-col-reverse]
**Learning:** Reversing large GenServer lists via `Enum.reverse/1` before broadcasting to the UI is an O(N) operation that blocks the GenServer. By utilizing Tailwind's `flex-col-reverse` in the UI, we can send the list exactly as it's stored (prepended, newest-first) and the browser natively renders it chronologically bottom-to-top.
**Action:** Always consider if CSS can solve data-ordering problems in the UI to prevent O(N) data transformations in Elixir processes.

## 2024-11-20 - O(N) penalty with list concatenation (++)
**Learning:** Using the `++` operator to concatenate lists creates unnecessary list copies, causing `O(N^2)` accumulation performance, and combining it with `Enum.map/2` involves traversing the list multiple times.
**Action:** To avoid O(N^2) list concatenation performance penalties in Elixir, prefer using `Enum.reduce/3` to build, map, and reverse prepended lists in a single O(N) pass, rather than combining `Enum.map/2` with the `++` operator.

## 2023-10-24 - Native Pattern Matching vs `get_in/2` in Elixir
**Learning:** While `get_in/2` combined with `Access.at/1` is convenient for deeply nested map/list extraction (like parsing OpenAI API responses), it is significantly slower than native BEAM pattern matching. The dynamic nature of `get_in` requires allocating closures and intermediate lists under the hood. In microbenchmarks on this codebase, a native pattern match (`%{"choices" => [%{"message" => %{"content" => content}} | _]}`) gave a ~5x speedup over `get_in(body, ["choices", Access.at(0), "message", "content"])`.
**Action:** When extracting data from heavily nested JSON maps (especially in critical paths or where high throughput is expected), prefer idiomatic Elixir pattern matching over `get_in/2` unless the path itself needs to be dynamic.

## 2024-08-22 - Optimize UUID generation string allocations and entropy usage
**Learning:** Generating full 16-byte UUIDs and then hex-encoding and slicing them just to get an 8-character ID is highly inefficient. It wastes 12 bytes of system entropy (which can be a bottleneck on `/dev/urandom` under high concurrency) and causes unnecessary memory allocations for the 32-character intermediate string and the subsequent string slice operation.
**Action:** When a short random string ID is needed (like an 8-character hex string), generate exactly the required bytes (`:crypto.strong_rand_bytes(4)`) and encode them directly, avoiding both entropy waste and intermediate string allocations.

## 2024-11-20 - Defer expensive GenServer state fetches on initial page load
**Learning:** In Phoenix LiveView apps, fetching distributed GenServer state sequentially or in parallel during the disconnected HTTP render (`mount`) blocks the response and increases time-to-first-byte (TTFB), causing an N+1 bottleneck. This duplicate work is discarded when the WebSocket connects and triggers another `mount`.
**Action:** When a LiveView depends on expensive operations like distributed state fetching, use `if connected?(socket)` in the `mount` callback to defer loading data until the stateful WebSocket connection is established, rendering a lightweight initial HTTP response.

## 2024-12-10 - O(1) fetching of all GenServer states via Registry
**Learning:** In Elixir, fetching state sequentially or in parallel from many processes (e.g. `Task.async_stream` with `GenServer.call`) incurs message queue processing overhead. By storing the process state directly in the Registry value via `Registry.update_value/3`, we can fetch all process states globally in a single O(1) native ETS match (`Registry.select`), completely bypassing GenServer message queues.
**Action:** When you frequently need the state of many independent GenServers simultaneously, register the state in the Registry value and keep it updated, then fetch all states simultaneously via `Registry.select` to avoid N+1 process calls.

## 2024-08-25 - Bulk ETS lookup to avoid N+1 GenServer calls
**Learning:** Even though \Task.async_stream\ parallelizes sequential GenServer state fetches, getting state from thousands of processes still has significant overhead (entering the message queue of each process). \Registry\ in Elixir is backed by an ETS table. By registering the actual process state as the *value* in the Registry tuple (\{:via, Registry, {MyRegistry, id, state}}\) and keeping it synced, you can use \Registry.select\ to perform an \O(1)\ native ETS match that returns all states simultaneously without sending a single GenServer message.
**Action:** When a UI needs to list the state of thousands of dynamic processes, register and sync the state into the Registry value itself, and fetch it directly via \Registry.select\ to eliminate N+1 process messaging completely.

## 2024-12-15 - O(1) single process state fetching via ETS Registry lookup
**Learning:** By storing the process state directly in the Registry value via `Registry.update_value/3`, we can fetch the state of a process natively in O(1) time using `Registry.lookup/2`. This avoids synchronous messaging to the GenServer (`GenServer.call`), bypassing process message queues entirely, reducing latency, and preventing the fetch from being blocked by other messages being processed.
**Action:** When a GenServer's state is frequently read by other processes (e.g. `get_state/1`), register and sync the state into the Registry value itself. Then, read it directly via `Registry.lookup/2` rather than sending a blocking `GenServer.call`.

## 2025-01-20 - [Clean up dynamic state collections in LiveView]
**Learning:** In Phoenix LiveView, accumulating state in Maps or Sets stored in socket assigns (such as for tracking timestamps for per-entity rate limiting) without removing the entries when the corresponding entities are deleted results in a memory leak. Because LiveView processes are long-running WebSockets, these dynamically populated maps will continue to grow and retain memory for the lifetime of the connection.
**Action:** Always explicitly clean up dynamically populated state Maps or Sets in socket assigns (e.g., using `Map.delete/2`) when the corresponding entity or stream item is removed to prevent memory leaks.
