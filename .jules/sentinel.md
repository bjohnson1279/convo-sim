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
