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
**Action:** Always use \
ole="log"\ and \ria-live="polite"\ on chat message containers to ensure screen readers announce incoming messages.

## 2026-08-26 - Decorative Icon Accessibility
**Learning:** Decorative icons rendered as spans or SVGs without `aria-hidden="true"` can confuse screen readers by reading out obscure class names or creating extra stops.
**Action:** Always add `aria-hidden="true"` to core icon components so screen readers ignore them and read the parent element's text or `aria-label` instead.

## 2024-06-25 - [Accessibility Improvements]
**Learning:** For screen readers, raw abbreviations (like "msgs") and visually-styled collections without semantic list tags can hinder navigation and comprehension. Tailwind's `list-style: none` removes list semantics in Safari, so explicit `role="list"` and `<li>` elements are necessary to preserve accessibility.
**Action:** Use `<ul role="list">` and `<li>` tags for collections instead of purely nested `<div>`s, and ensure visual abbreviations are accompanied by full screen-reader text using `aria-hidden="true"` and `<span class="sr-only">`.

## 2024-11-20 - In-Context Visual Typing Indicator in UI
**Learning:** When using Tailwind CSS `flex-col-reverse` for newest-first chat ordering natively, placing the typing indicator HTML element *before* the message loop ensures it renders visually at the bottom. Adding `aria-hidden="true"` to this typing bubble is critical to prevent screen readers from announcing it redundantly when a global `aria-live` region (like a status pill) is already broadcasting the "AI Responding..." state.
**Action:** Always check the direction of flex containers (`flex-col-reverse` vs `flex-col`) before inserting temporary visual state elements like typing indicators. Additionally, audit `aria-live` regions on the page to prevent duplicate screen reader announcements by silencing visual-only indicators with `aria-hidden="true"`.

## 2024-11-20 - Global Button Focus Visibility
**Learning:** General button components often lack explicit `focus-visible` styles in custom Tailwind configurations, meaning keyboard users do not receive clear visual feedback when tabbing through standard form buttons or links.
**Action:** Always ensure the core button component (e.g., `lib/convo_sim_web/components/core_components.ex`'s `button/1`) includes `focus-visible` ring utilities (like `focus-visible:outline-none focus-visible:ring-2`) to guarantee keyboard accessibility across the entire application without relying on inconsistent browser defaults.

## 2024-11-20 - Continuous Animation Accessibility
**Learning:** Continuous looping animations (like `animate-pulse` or `animate-bounce`) can cause nausea and discomfort for users with vestibular disorders.
**Action:** Always prefix continuous looping animation classes with `motion-safe:` to respect the user's OS-level `prefers-reduced-motion` settings.

## 2024-11-20 - Contextual Accessible Names in Repeated Lists
**Learning:** Screen reader users can easily get lost when navigating through lists of identical components (like conversation cards) if buttons and IDs lack unique context (e.g., encountering multiple "Stop Process" or "Send Customer Message" buttons).
**Action:** Always inject unique contextual information (like an ID or entity name) into interactive elements within repeated lists, either by updating `aria-label` or appending visually hidden text using `<span class="sr-only">`.

## 2024-05-24 - Improve color contrast for empty state text
**Learning:** In dark mode interfaces, using `text-slate-600` on `bg-slate-900` for small placeholder text fails WCAG AA contrast standards, making it hard to read.
**Action:** Always use `text-slate-400` or lighter for small placeholder or descriptive text on dark backgrounds to ensure adequate accessibility color contrast.

## 2024-09-12 - Empty State Icon Contrast
**Learning:** In dark mode interfaces, using 	ext-slate-600 on g-slate-900 for empty state icons fails WCAG AA contrast standards, making it hard to read. It's important to use 	ext-slate-400 or lighter for empty state icons and text on dark backgrounds to ensure adequate accessibility color contrast.
**Action:** Always use 	ext-slate-400 or lighter for empty state icons on dark backgrounds to ensure adequate accessibility color contrast.

## 2024-11-20 - Global Navigation External Links
**Learning:** External links in primary navigation menus often fail to warn screen reader users about context shifts (opening a new tab), which can be disorienting.
**Action:** Always add `target="_blank"` and `rel="noopener noreferrer"` to external links. Additionally, append visually hidden text (e.g., `<span class="sr-only"> (opens in a new tab)</span>`) to give context to screen readers, and ensure robust `focus-visible` utility classes are applied to the anchor tags for keyboard navigation.

## 2024-09-24 - Flash Message Dismissal UX
**Learning:** Attaching click-to-dismiss handlers to the entire container of a flash/toast message creates a frustrating experience when users attempt to highlight and copy error text, as the message disappears on mouse-up/click.
**Action:** Always attach dismissal actions (`phx-click`) specifically to the close `<button>` element rather than the parent container to allow text selection.

## 2024-11-20 - Keyboard Accessibility for Scrollable Containers
**Learning:** Standalone scrollable containers (e.g., `overflow-auto`) that do not contain inherently focusable elements are inaccessible to keyboard-only users, as they cannot receive focus to be scrolled via arrow keys.
**Action:** Always include `tabindex="0"`, an appropriate `aria-label`, and robust `focus-visible` styles on scrollable containers so keyboard-only users can navigate and scroll them predictably.


## Prevention Directives for Automated Refactoring
- **Never Overwrite Complete Files**: Always use range-scoped replacement chunks for edits to `schema.prisma`, `index.ts`, `public/index.php`, `db/schema.rb`, or DDL SQL scripts.
- **Do Not Remove Core Declarations**: Do not delete existing route registrations or database DDL tables.
- **Environment Isolation Compatibility**: When replacing fallback secrets, preserve test environment execution via `!getenv('APP_ENV')` or `getenv('APP_ENV') === 'testing'`.
- **No Scratch Files**: Never stage or commit `test_*.ts`, `test_*.js`, `test.cjs`, `fix_*.php`, or `test.js` files to git.
- **No Unresolved Conflict Markers**: Never stage or commit files containing Git merge conflict markers (`<<<<<<<`, `=======`, `>>>>>>>`, `|||||||`). Always resolve conflicts cleanly before committing.

## Completeness & Verification Directives
- **Explicit Parameter & Contract Validation**: When creating or modifying API endpoints (Express, Fastify, Rails, Laravel), always implement explicit parameter and request body validation schemas (e.g. `z.string().uuid()`) to prevent unhandled 404/500 fallthroughs.
- **Database Indexing for Queries**: When addressing query bottlenecks or adding query lookup filters, always implement native database index migrations rather than loading collections into memory and performing array filtering (`.filter()`, `.select`).
- **Co-Occurring Dependency Auditing**: When bumping any dependency version, verify that other transitive dependencies do not carry high/critical security advisories (e.g. run `bundler-audit`, `npm audit`). Never introduce a version bump that breaks underlying framework APIs.
- **Self-Verification Before Commit**: Always run syntax checks (`bash -n` for shell scripts, `tsc --noEmit` for TypeScript, linter checks) and targeted test runners locally before opening or updating a PR.

## Hallucinatory Task & Empty PR Directives
- **Zero-Diff Task Termination**: If the requested optimization, refactor, or fix is ALREADY natively present in the target branch, DO NOT create an empty pull request or commit an acknowledgment PR. Exit the task cleanly without opening a PR.
- **No Journal-Only PRs**: Never open a pull request that only contains updates to .jules/*.md files without corresponding functional code changes and tests.
- **Stale Suggestion Guard**: Always verify the current code on `main`/`master` before planning changes. If no actionable diff is required, cancel task execution immediately.

## Assertiveness, Decisive PR Execution & Comparative Recommendations
- **Proactive & Decisive PR Submission**: Do NOT repeatedly pause to ask permission to open a pull request (e.g., avoid "Would you like me to open a PR for this?", "Can I submit the PR?", "Should I go ahead and create the PR?"). When an optimization, fix, or feature satisfies requirements, passes local test runners/linters, and preserves architectural invariants, proceed decisively to create and submit the Pull Request with a clear, structured summary and rationale.
- **Explicit Recommendations on Options**: When presenting multiple implementation strategies or architecture options (e.g., Option A vs. Option B), NEVER leave the choice open-ended or passive. Always make an explicit, reasoned recommendation (prefixed with `(Recommended)`) based on **overall technical effectiveness**:
  1. *Algorithmic & Complexity Gains*: Time and space complexity impact (O(N*M) -> O(N+M), reduction of nested scans).
  2. *Resource Overhead*: Heap allocations, memory pressure, and GC pause reduction.
  3. *Domain & Architecture Invariants*: Strict backward compatibility, contract stability, and prevention of regression risks.
  4. *Security & Reliability*: Input validation, cryptographic safety, and concurrency safety.
- **Lead with Recommended Path**: State clearly why the recommended solution delivers the highest net value and immediately execute or propose it as the primary course of action rather than asking open-ended questions.

## Scope Verification, Minimal Churn & CI Protection Directives
- **Scope Verification Before Variable Binding**: When adding interactive states or accessibility attributes (e.g. `disabled={loading}`, `aria-busy={loading}`, `isSubmitting`), NEVER assume a variable identifier exists. Always inspect component props, local state hooks (`useState`), or declaration scope first. If not defined, declare the state hook or reuse an existing scope variable. Never introduce TS2304 / TS2552 ("Cannot find name") compile errors.
- **Surgical Edits Only (No Whole-File Formatting)**: Never run whole-file code formatters (Prettier, Black, Pint, rustfmt) across unmodified lines. Changes must be strictly range-scoped and limited to the minimal AST block needed. Avoid noisy quote/whitespace churn that masks real logic changes and causes merge conflicts. Verify with `git diff -w` that non-functional churn is zero.
- **Zero Scratch File Commits**: Never stage or commit ad-hoc verification, patch, or debug scripts (`test.cjs`, `fix_*.cjs`, `fix_*.php`, `patch_*.py`, `patch_*.sh`, `scratch_*`). Execute checks via the project's native test commands (`npm test`, `pytest`, `phpunit`, etc.) and delete temporary scripts before creating git commits.
- **Never Weaken CI Workflows**: Do not modify `.github/workflows/**` to bypass failures (e.g. adding `|| true`, setting `continue-on-error: true`, or commenting out assertions). Always resolve the defect in the source code or test fixture.
- **Explicit Parameter & Variable Types**: In TypeScript files, avoid implicit `any` by always providing explicit types on functions, parameters, and arrow callbacks (e.g. `(id: string) => ...`). Verify zero type errors with `tsc --noEmit` before committing.

## 2026-09-29 - Scope Verification for Async Loading Attributes
**Learning:** Blindly injecting `disabled={loading}` or `aria-busy={loading}` into JSX/TSX buttons causes fatal TypeScript compilation errors (`TS2304: Cannot find name 'loading'`) when `loading` is not declared in component props, state hooks (`useState`), or mutation results. Furthermore, using temporary patch scripts (`fix_*.cjs`) to manipulate source code pollutes the git index.
**Action:** Before referencing any state identifier (such as `loading`, `isSubmitting`, `isPending`) in `disabled` or `aria-busy`, inspect the component scope. If no loading state is tracked, define it using `useState(false)` or check existing query/mutation hooks. Never bind undeclared variables. Always run `tsc --noEmit` locally and never commit temporary fix scripts.

## Additive Documentation & Scratch Cleanliness Directives
- **Strictly Additive Journal Updates**: When updating `.jules/*.md`, strictly append new dated entries (`## YYYY-MM-DD - Title`). NEVER delete, truncate, or overwrite historical learnings or previous entries.
- **Substantive Code Diff Requirement**: Pull requests must include substantive code changes in `src/`, `app/`, `lib/`, or `tests/`. Never open PRs that modify only `.jules/*.md` journals or root scratch scripts.
- **Zero Scratch File Commits**: Never commit `*.diff`, `*.patch`, `test_*.ts`, `test_*.js`, `test.cjs`, `fix_*.php`, or `patch_*.py` files. Always remove temporary debugging or verification scripts prior to committing.

## Scope Quarantine, Journaling & Security Test Invariants
- **Strictly Append-Only Journaling**: When adding learnings to `.jules/*.md`, append strictly at the end of the file. Do not rewrite, deduplicate, or remove lines beginning with `## YYYY-MM-DD`.
- **Surgical Scope Quarantine**: Modify only the files directly involved in the issue and their corresponding test fixtures. Do not delete, rename, or perform drive-by cleanups of unrelated root-level scripts or legacy files.
- **Coupled Test Fixture Awareness for Security Invariants**: When changing fail-open fallback behavior (such as hardening decryption to fail closed), always update upstream test mocks that rely on plaintext credentials or mock values.
