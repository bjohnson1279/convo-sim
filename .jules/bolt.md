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
