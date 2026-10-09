## 2024-08-15 - Hardcoded Internal IP in Configuration
**Vulnerability:** Internal network IP (192.168.0.249) was hardcoded in LM Studio API configurations.
**Learning:** Hardcoding internal infrastructure IPs can leak information about the network topology if the codebase is exposed or deployed.
**Prevention:** Use localhost (127.0.0.1) as a safe default for local services or read entirely from environment variables.

## 2026-08-15 - Hardcoded Secrets in Configs
**Vulnerability:** Hardcoded `secret_key_base` strings found in `config/dev.exs` and `config/test.exs`.
**Learning:** Even in non-production environments, hardcoded secrets can be accidentally promoted or provide cryptographic material to attackers if the codebase is exposed.
**Prevention:** Read secrets from environment variables (e.g., `System.get_env`) and provide safe, dummy fallbacks if needed.

## 2026-08-16 - Prevent Information Leakage in API Responders
**Vulnerability:** The AI responder (`lib/convo_sim/responder/lm_studio.ex`) was leaking full external API response bodies and HTTP status codes directly to the UI when errors occurred.
**Learning:** Exposing internal system errors, raw API responses, or stack traces directly to the end user can leak sensitive infrastructure details, network topology, or authentication materials.
**Prevention:** Always log the verbose error details internally (e.g. `Logger.error`) and return a safe, generic error message to the user.

## 2024-08-22 - Prevent Resource Exhaustion (DoS)
**Vulnerability:** A lack of limits on concurrently spawned conversations allowed a Denial of Service via Resource Exhaustion (crashing the BEAM).
**Learning:** Publicly accessible endpoints or events that dynamically spawn GenServers must have concurrency limits to prevent attackers from exhausting VM resources (PIDs/Memory).
**Prevention:** Use fast mechanisms like `Registry.count/1` to enforce maximum process bounds before spawning new workers.

## 2026-08-22 - Bandit HTTP/2 Vulnerabilities
**Vulnerability:** High severity HTTP/2 connection-window starvation (CVE-2026-74836) and Medium severity header validation issues (CVE-2026-75484) in `bandit` v1.12.4.
**Learning:** Outdated web server dependencies can expose the application to denial-of-service (DoS) and request smuggling attacks.
**Prevention:** Regularly audit dependencies using tools like `mix hex.audit` (or other dependency audit tools) and apply security patches promptly.

## 2026-08-25 - Log Injection Prevention
**Vulnerability:** Unsanitized user input was interpolated directly into log messages, allowing potential log injection or manipulation of the terminal/log viewer.
**Learning:** Raw string interpolation of user-provided data into logs is a dangerous vector. Even seemingly benign identifiers can carry malicious payloads like newline characters.
**Prevention:** Always use `inspect/1` when logging untrusted user input to ensure it is safely encoded and escaped.

## 2026-08-25 - Prevent DoS via Missing Input Length Limits
**Vulnerability:** LiveView event handlers accepted arbitrarily large string identifiers without validation, posing a Denial of Service (DoS) risk through memory exhaustion.
**Learning:** Relying on Cowboy or Plug to limit HTTP body sizes does not protect individual WebSocket event handlers or GenServer boundaries from massive string payloads. Furthermore, silently truncating these strings (e.g., via `String.slice/3`) is an anti-pattern as it does not prevent the initial memory allocation and introduces functional collision risks.
**Prevention:** Enforce input length limits early at the event boundary using guard clauses (e.g., `when byte_size(id) <= 64`) and explicitly reject oversized payloads instead of silently truncating them.

## 2026-08-26 - Missing Rate Limiting in LiveView Events
**Vulnerability:** LiveView event handlers like `spawn_conversation` were missing rate limiting, allowing a user to spam the event and spawn maximum processes instantly (DoS).
**Learning:** LiveView events over WebSockets do not have built-in rate limiting like Plug might provide for HTTP requests. Any resource-intensive event can be trivially spammed.
**Prevention:** Implement rate limiting manually within the LiveView by tracking the last event timestamp in the socket assigns (e.g. `socket.assigns.last_event_time`) and checking the elapsed time with `System.system_time(:millisecond)`.

## 2024-05-18 - GenServer queue buildup (DoS) via global WebSocket rate limiting
**Vulnerability:** A global rate limit implementation on a WebSocket event (`send_message`) allowed users to be rate-limited out of sending messages on independent conversations because the rate limiter checked a single, shared state tracking the last message time across all conversations.
**Learning:** In highly concurrent environments like Elixir's Phoenix LiveView, applying a global limit where a per-entity (e.g. per-conversation) limit is needed can break isolation and create an inadvertent DoS vector where rapid actions on one entity block legitimate actions on another.
**Prevention:** Always scope rate limiting to the entity level (e.g. using a map `%{id => timestamp}`) when dealing with decoupled processes (like individual GenServers) in a LiveView WebSocket context.

## 2024-09-05 - Mint HTTP/1 Vulnerabilities
**Vulnerability:** High severity HTTP/1 status-line buffering (CVE-2026-82728) and Medium severity chunk-size parsing issues (CVE-2026-82729) in `mint` v1.9.3.
**Learning:** Outdated web server client dependencies can expose the application to denial-of-service (DoS) attacks.
**Prevention:** Regularly audit dependencies using tools like `mix hex.audit` and apply security patches promptly.

## 2026-08-27 - Type Confusion Bypass of Length Validation Guards
**Vulnerability:** Guard clauses enforcing length validation on LiveView event parameters (e.g., `when byte_size(id) > 64`) were bypassed when non-binary values (like maps or lists) were provided, exposing the system to memory exhaustion DoS.
**Learning:** In Elixir, if a guard function (like `byte_size/1`) fails (e.g., when called on a map), it does not crash the process; instead, it silently evaluates to `false` for that guard and falls through to the next function clause. This can cause attackers to bypass strict length checks by sending complex, non-string JSON payloads to WebSocket event handlers, creating a type confusion vulnerability.
**Prevention:** Always combine length validation guards with strict type checking (e.g., `when not is_binary(id) or byte_size(id) > 64`) to ensure unexpected types are securely rejected and do not bypass the safeguard.

## 2026-09-10 - Prevent CSP unsafe-eval XSS Vector
**Vulnerability:** The Content Security Policy (CSP) in `router.ex` included `'unsafe-eval'` in the `script-src` directive, which could allow arbitrary JavaScript execution via `eval()` or similar constructs.
**Learning:** Phoenix LiveView applications do not require `'unsafe-eval'` for their client-side JavaScript to function correctly, so its inclusion unnecessarily expands the attack surface.
**Prevention:** Always restrict CSP directives to the minimum required permissions. Omit `'unsafe-eval'` and rely on strict `'self'` or nonce/hash based execution for scripts in Phoenix apps.

## 2026-09-15 - Prevent GenServer DoS via State Validation
**Vulnerability:** A GenServer did not validate its internal state before spawning background tasks in response to asynchronous casts (`handle_cast`). Because client-side limits (e.g., a disabled button) can be bypassed by firing WebSocket events directly, an attacker could spam events and exhaust system resources (threads/memory).
**Learning:** Never rely exclusively on client-side state to prevent event spamming in stateful servers.
**Prevention:** To prevent DoS via resource exhaustion in Elixir GenServers, explicitly check the process's current internal state (e.g., `if state.status == :responding`) before spawning new asynchronous tasks or executing heavy workloads in `handle_cast` or `handle_call`.

## 2026-09-22 - Prevent Type Confusion Bypass of Length Validation Guards
**Vulnerability:** A missing type check on the `id` argument in the `send_message/2` function could lead to type confusion where non-binary types implicitly bypass length validations like `byte_size(id) <= 64` when evaluated by Elixir's guards, posing a Denial of Service (DoS) risk through unexpected resource consumption down the pipeline.
**Learning:** In Elixir, if a guard function (like `byte_size/1`) fails (e.g., when called on an invalid type like a list), it does not crash the process; instead, it silently evaluates to `false` and falls through to the next function clause. Missing an explicit `is_binary/1` guard when using `byte_size/1` enables attackers to craft type confusion payloads that bypass strict length checks.
**Prevention:** Always combine length validation guards with strict type checking (e.g., `when is_binary(id) and byte_size(id) <= 64`) to ensure inputs are exactly what they're expected to be and malicious bypasses via type confusion are securely rejected.

## 2026-09-27 - Update lazy_html to fix XSS vulnerability
**Vulnerability:** `lazy_html` < 0.1.13 is vulnerable to mutation XSS due to unescaped serialization of SVG and MathML style/script text (EEF-CVE-2026-92106).
**Learning:** Dependency vulnerabilities can be introduced in mix.lock and checking via mix hex.audit is important.
**Prevention:** Keep dependencies updated via mix deps.update and regularly audit packages.

## 2026-09-29 - Non-Destructive Security Patching & CI Protection
**Learning:** Security patches must never weaken CI workflow files (`.github/workflows/**`) by appending `|| true` or `continue-on-error: true` to suppress test/build failures. Furthermore, when adding defensive type assertions or input validators in TypeScript, omitting explicit types can introduce `TS7006: Parameter implicitly has an 'any' type`.
**Action:** Never modify CI workflow definitions to bypass test failures; resolve the underlying issue in source code or test fixtures. Always provide explicit types on newly introduced parameters and helper functions. Ensure zero scratch scripts (`fix_*.php`, `test_*.js`) are committed.

## 2026-10-04 - Safely Supply Module Attributes at Runtime
**Learning:** In Elixir, module attributes (e.g., `@session_options`) are evaluated strictly at compile time. Using `System.get_env/1` inside a module attribute bakes the environment variable's value during the build process, preventing dynamic runtime configuration.
**Prevention:** To supply secrets at runtime for plugs that accept options defined in module attributes, use standard mechanisms like tuples (`{Application, :fetch_env!, [:app, :key]}`) if the plug supports it, and configure the actual environment variables inside `runtime.exs`.

## Prevention Directives for Automated Refactoring
- **Never Overwrite Complete Files**: Always use range-scoped replacement chunks (`StartLine`/`EndLine`) for edits to `schema.prisma`, `index.ts`, `public/index.php`, or DDL SQL scripts.
- **Do Not Remove Core Declarations**: Do not delete existing route registrations or database DDL tables.
- **Environment Isolation Compatibility**: When replacing fallback secrets, preserve test environment execution via `!getenv('APP_ENV')` or `getenv('APP_ENV') === 'testing'`.
- **No Scratch Files**: Never stage or commit `test_*.ts`, `test_*.js`, `test.cjs`, `fix_*.php`, or `test.js` files to git.
- **No Unresolved Conflict Markers**: Never stage or commit files containing Git merge conflict markers (`<<<<<<<`, `=======`, `>>>>>>>`, `|||||||`). Always resolve conflicts cleanly before committing.
- **Never Overwrite Complete Files**: Always use range-scoped replacement chunks for edits to `schema.prisma`, `index.ts`, `public/index.php`, `db/schema.rb`, or DDL SQL scripts.

## Hallucinatory Task & Empty PR Directives
- **Zero-Diff Task Termination**: If the requested optimization, refactor, or fix is ALREADY natively present in the target branch, DO NOT create an empty pull request or commit an acknowledgment PR. Exit the task cleanly without opening a PR.
- **Stale Suggestion Guard**: Always verify the current code on `main`/`master` before planning changes. If no actionable diff is required, cancel task execution immediately.

## Completeness & Verification Directives
- **Explicit Parameter & Contract Validation**: When creating or modifying API endpoints (Express, Fastify, Rails, Laravel), always implement explicit parameter and request body validation schemas (e.g. `z.string().uuid()`) to prevent unhandled 404/500 fallthroughs.
- **Database Indexing for Queries**: When addressing query bottlenecks or adding query lookup filters, always implement native database index migrations rather than loading collections into memory and performing array filtering (`.filter()`, `.select`).
- **Co-Occurring Dependency Auditing**: When bumping any dependency version, verify that other transitive dependencies do not carry high/critical security advisories (e.g. run `bundler-audit`, `npm audit`). Never introduce a version bump that breaks underlying framework APIs.
- **Self-Verification Before Commit**: Always run syntax checks (`bash -n` for shell scripts, `tsc --noEmit` for TypeScript, linter checks) and targeted test runners locally before opening or updating a PR.

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

## Additive Documentation & Scratch Cleanliness Directives
- **Strictly Additive Journal Updates**: When updating `.jules/*.md`, strictly append new dated entries (`## YYYY-MM-DD - Title`). NEVER delete, truncate, or overwrite historical learnings or previous entries.
- **Substantive Code Diff Requirement**: Pull requests must include substantive code changes in `src/`, `app/`, `lib/`, or `tests/`. Never open PRs that modify only `.jules/*.md` journals or root scratch scripts.
- **Zero Scratch File Commits**: Never commit `*.diff`, `*.patch`, `test_*.ts`, `test_*.js`, `test.cjs`, `fix_*.php`, or `patch_*.py` files. Always remove temporary debugging or verification scripts prior to committing.

## Scope Quarantine, Journaling & Security Test Invariants
- **Strictly Append-Only Journaling**: When adding learnings to `.jules/*.md`, append strictly at the end of the file. Do not rewrite, deduplicate, or remove lines beginning with `## YYYY-MM-DD`.
- **Surgical Scope Quarantine**: Modify only the files directly involved in the issue and their corresponding test fixtures. Do not delete, rename, or perform drive-by cleanups of unrelated root-level scripts or legacy files.
- **Coupled Test Fixture Awareness for Security Invariants**: When changing fail-open fallback behavior (such as hardening decryption to fail closed), always update upstream test mocks that rely on plaintext credentials or mock values.

- **Strict Lowercase Directory Casing**: Always write learning notes to lowercase `.jules/<bot>.md`. Never create, commit, or reference uppercase `.Jules/`.

- **Clean Markdown Formatting**: Always append journal entries using actual newline characters, never literal string escape sequences `\n`.
