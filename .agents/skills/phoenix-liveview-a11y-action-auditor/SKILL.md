---
name: phoenix-liveview-a11y-action-auditor
description: >-
  Audits, verifies, and auto-generates test coverage for Phoenix LiveView interactive element accessibility, loading feedback (phx-disable-with), icon accessibility (aria-label/title), destructive confirmation guards (data-confirm), and live status announcements (aria-live).
---

# Phoenix LiveView Accessibility & Action Feedback Auditor

Audits HEEx templates and Phoenix LiveView components to ensure all interactive elements provide visual feedback on submission, adhere to accessibility standards, and protect destructive actions with confirmation prompts.

---

## Capabilities & Audited Rules

### 1. Action Loading Feedback (`phx-disable-with`)
* **Rule**: Every button, link, or form trigger executing a server action (`phx-click` or `phx-submit`) should include `phx-disable-with="..."` or `phx-loading` to give immediate visual feedback and prevent accidental double-submits.
* **Example**:
  ```heex
  <button id="send-btn" phx-click="send_message" phx-disable-with="Sending...">
    Send Message
  </button>
  ```

### 2. Icon-Only Action Accessibility (`aria-label` / `title`)
* **Rule**: Buttons or links containing only icons (`<.icon ...>` or `<svg>`) without visible text must have an explicit `aria-label`, `aria-labelledby`, or `title` for screen readers.
* **Example**:
  ```heex
  <button id="theme-btn" phx-click="toggle_theme" aria-label="Toggle Theme" title="Toggle Theme">
    <.icon name="hero-sun" class="size-4" />
  </button>
  ```

### 3. Destructive Action Confirmation Guards (`data-confirm`)
* **Rule**: Buttons executing irreversible or state-destructive operations (`delete`, `remove`, `stop`, `kill`) must include `data-confirm="..."` or trigger a confirmation dialog.
* **Example**:
  ```heex
  <button id={"stop-btn-#{convo.id}"} phx-click="stop_conversation" data-confirm="Are you sure you want to stop this conversation?">
    Stop Conversation
  </button>
  ```

### 4. Dynamic Status Announcements (`aria-live="polite"`)
* **Rule**: Status badges or dynamic message counters should be wrapped in `<div aria-live="polite" aria-atomic="true">` or `role="status"` to announce real-time transitions to assistive tech.

---

## Utility CLI Commands

The skill provides a Python CLI tool at `scripts/a11y_action_auditor.py`:

### 1. Scan Templates for Gaps
```bash
python .agents/skills/phoenix-liveview-a11y-action-auditor/scripts/a11y_action_auditor.py scan \
  --path lib \
  --output a11y_report.json
```

### 2. Generate LiveView Test Assertions
```bash
python .agents/skills/phoenix-liveview-a11y-action-auditor/scripts/a11y_action_auditor.py generate-tests \
  --path lib \
  --output test_assertions.exs
```

---

## LiveView Test Verification Pattern

When verifying LiveView accessibility in tests with `Phoenix.LiveViewTest`:

```elixir
test "renders accessibility attributes and disable-with feedback on action buttons", %{conn: conn} do
  {:ok, view, _html} = live(conn, ~p"/")

  # Verify action buttons provide disable-with feedback
  assert has_element?(view, ~s|button#spawn-convo-btn[phx-disable-with="Spawning..."]|)
  assert has_element?(view, ~s|button#stop-btn-123[phx-disable-with="Stopping..."]|)

  # Verify accessible labels and confirmation guards
  assert has_element?(view, ~s|button#stop-btn-123[aria-label="Stop Conversation"]|)
  assert has_element?(view, ~s|button#stop-btn-123[data-confirm="Are you sure?"]|)
end
```
