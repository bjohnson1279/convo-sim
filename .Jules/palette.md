## 2024-05-24 - Phoenix LiveView Destructive Actions
**Learning:** Destructive actions in LiveView often lack native confirmation prompts and proper accessibility attributes for icon-only buttons.
**Action:** Always use native `data-confirm` for destructive actions, `aria-label` for icon-only buttons, and `focus-visible` utilities to ensure keyboard accessibility in Phoenix LiveView templates.
