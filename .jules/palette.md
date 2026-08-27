## 2024-05-24 - Phoenix LiveView Destructive Actions
**Learning:** Destructive actions in LiveView often lack native confirmation prompts and proper accessibility attributes for icon-only buttons.
**Action:** Always use native `data-confirm` for destructive actions, `aria-label` for icon-only buttons, and `focus-visible` utilities to ensure keyboard accessibility in Phoenix LiveView templates.
## 2024-08-18 - Communicating Dynamic State
**Learning:** Sighted users often struggle to understand why a button is disabled, while screen reader users need updates when dynamic content like status badges change independently of user action.
**Action:** Always add descriptive `title` attributes explaining the disabled state dynamically, and wrap live-updating status indicators in `aria-live="polite"` regions.
## 2024-05-15 - [Theme Toggle Accessibility]
**Learning:** Icon-only buttons like theme toggles are completely invisible to screen readers without ARIA labels, and without explicit focus-visible styles, keyboard users cannot navigate them predictably.
**Action:** Always add `aria-label`, an optional `title` tooltip, and robust `focus-visible` states to any interaction element that only contains an icon.
## 2024-08-25 - Dynamic Chat Message Accessibility
**Learning:** For chat message containers in Phoenix LiveView apps where messages are appended dynamically, screen readers often fail to announce incoming messages.
**Action:** Use `role="log"` and `aria-live="polite"` on the container to ensure screen readers properly announce incoming messages as they are dynamically appended without a full page reload.

## 2024-11-20 - Chat Application Accessibility
**Learning:** Chat messages appended dynamically are invisible to screen readers without specific ARIA attributes.
**Action:** Always use \ole="log"\ and \ria-live="polite"\ on chat message containers to ensure screen readers announce incoming messages.

## 2026-08-26 - Decorative Icon Accessibility
**Learning:** Decorative icons rendered as spans or SVGs without `aria-hidden="true"` can confuse screen readers by reading out obscure class names or creating extra stops.
**Action:** Always add `aria-hidden="true"` to core icon components so screen readers ignore them and read the parent element's text or `aria-label` instead.

## 2026-08-27 - Semantic Lists for Grids
**Learning:** Sighted users can see a grid of cards as a collection, but screen reader users lose this context if the container is just a `div`. Additionally, Safari removes list semantics from `ul` elements when `list-style: none` is applied (which Tailwind does by default).
**Action:** Always use `ul` with `role="list"` for the container and `li` for the items when rendering a grid or list of repeated cards, so screen readers properly announce the collection size and boundaries.
