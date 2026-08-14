## 2024-08-14 - N+1 process state fetching in BEAM
**Learning:** In Phoenix/Elixir apps, sequentially fetching state from many processes (e.g., using `Enum.map` with `GenServer.call`) causes an N+1 bottleneck. Since each process has its own message queue, these independent requests can be processed concurrently.
**Action:** Use `Task.async_stream` instead of `Enum.map` when fetching state from multiple independent GenServers to parallelize the calls and drastically reduce overall latency.
