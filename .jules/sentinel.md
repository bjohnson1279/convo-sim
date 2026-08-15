## 2024-08-15 - Hardcoded Internal IP in Configuration
**Vulnerability:** Internal network IP (192.168.0.249) was hardcoded in LM Studio API configurations.
**Learning:** Hardcoding internal infrastructure IPs can leak information about the network topology if the codebase is exposed or deployed.
**Prevention:** Use localhost (127.0.0.1) as a safe default for local services or read entirely from environment variables.

## 2026-08-15 - Hardcoded Secrets in Configs
**Vulnerability:** Hardcoded `secret_key_base` strings found in `config/dev.exs` and `config/test.exs`.
**Learning:** Even in non-production environments, hardcoded secrets can be accidentally promoted or provide cryptographic material to attackers if the codebase is exposed.
**Prevention:** Read secrets from environment variables (e.g., `System.get_env`) and provide safe, dummy fallbacks if needed.
