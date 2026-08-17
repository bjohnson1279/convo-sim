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
