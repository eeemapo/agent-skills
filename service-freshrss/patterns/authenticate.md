# Authenticate to FreshRSS

1. Confirm the base URL and username (`FRESHRSS_BASE_URL`, `FRESHRSS_USER`).
2. Confirm the credential is the **API password**, not the login password.
3. Run `scripts/freshrss.sh auth` (or `whoami`).
4. On success, ClientLogin returned an `Auth=` token that the script reuses per
   request. On failure, see below.

## Failure signals

- **HTTP 401** — wrong credential, or the wrong form field name. Verify the
  field is `Passwd` (not `Password`) before assuming the password is wrong.
- **HTTP 404** — wrong path. The endpoint is `accounts/ClientLogin`, not
  `accounts/Login`.
- **HTTP 200 with an empty/odd body** — usually a redirect to a login page;
  confirm the base URL has no trailing path and the instance has the API
  enabled.

## Notes

The script performs ClientLogin on every invocation and never prints the token.
Write actions additionally require a per-session token from
`reader/api/0/token` — see [`../references/greader-api.md`](../references/greader-api.md).
