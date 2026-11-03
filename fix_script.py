import re
with open("test/convo_sim/conversation_test.exs", "r") as f:
    content = f.read()
new_content = content.replace(
    "assert String.match?(id, ~r/^conv-[0-9a-f]{8}$/)",
    "assert String.match?(id, ~r/^conv-[0-9a-f]{32}$/)"
)
with open("test/convo_sim/conversation_test.exs", "w") as f:
    f.write(new_content)
