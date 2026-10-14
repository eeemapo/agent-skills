# Portability and secret hygiene

Contract skills are often published (a public repo, a shared workspace). Write
them so they carry **no specifics of any one environment**.

## Use placeholders

Write these forms, never a real value:

- `<base-url>` or `<service-host>` — never a real hostname or IP.
- `<credential>` or `<api-key>` — never a real token or key.
- `<vault>` or `<item-ref>` — never a real vault, item, or account name.
- `SERVICE_BASE_URL` (environment variable) — never a hardcoded URL.
- `SERVICE_TOKEN` (environment variable) — never a hardcoded secret.

Never include: real endpoints, ports, account or user names, personal file
paths, internal service names, or screenshots and logs containing values.

## Configure by environment

Scripts read configuration from documented environment variables (and optionally
a config-file path given by one). Document the variable names and provide a
redacted example. Assume the reader's endpoints and credentials differ from
yours.

## Never expose secrets

- Do not print resolved credential values.
- Do not enable shell tracing (`set -x`) around variables holding secrets.
- Have the script consume secrets from the environment; never require the agent
  to paste a value.
- Treat any transcript that captured a value as compromised and scrub it.

## Public-repo checklist

- [ ] No real host, IP, port, account, or path
- [ ] All endpoints and credentials behind placeholders or environment variables
- [ ] Examples use obviously fake values (for example `example.invalid`,
      `redacted`)
- [ ] No logs, transcripts, or screenshots carrying live values
- [ ] Secret-carrying variables are documented but never valued in the repo
