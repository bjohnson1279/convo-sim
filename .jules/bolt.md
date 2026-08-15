
## $(date +%Y-%m-%d) - [O(1) List Prepending]
**Learning:** Appending to a linked list via `list ++ [new_item]` inside a long-running process (like a GenServer state) causes `O(N^2)` accumulation performance because `++` has to copy the entire list on every append. Reversing the list dynamically inside `handle_call` or right before broadcasting is surprisingly fast compared to the penalty of `++` copying for large state lists.
**Action:** When accumulating state over time in Elixir GenServers, ALWAYS prepend lists (`[item | list]`) which is `O(1)`. Only reverse the list via `Enum.reverse/1` right at the edge when formatting the state for the UI, broadcasts, or returning to callers.
