## 2024-05-24 - Phoenix LiveView Destructive Actions
**Learning:** Destructive actions in LiveView often lack native confirmation prompts and proper accessibility attributes for icon-only buttons.
**Action:** Always use native `data-confirm` for destructive actions, `aria-label` for icon-only buttons, and `focus-visible` utilities to ensure keyboard accessibility in Phoenix LiveView templates.

## 2024-05-25 - LiveView State Change Accessibility
**Learning:** Dynamic state indicators in LiveView streams (like changing from "Idle" to "Responding") are entirely invisible to screen readers unless wrapped in an `aria-live` region. Furthermore, buttons that become dynamically disabled leave users confused if not explicitly labeled with the reason.
**Action:** Wrap dynamic status pills in `<div aria-live="polite" aria-atomic="true">` to ensure smooth announcements. Additionally, use dynamic `title` or `aria-disabled` combined with descriptive text to explain disabled button states.
