# Public Client Identities

Common public MCP clients that publish Client ID Metadata Documents.

### VS Code

Metadata URL: `https://vscode.dev/oauth/client-metadata.json`

Example metadata:
```json
{
  "client_id": "https://vscode.dev/oauth/client-metadata.json",
  "redirect_uris": ["http://127.0.0.1:33418/","https://vscode.dev/redirect"]
}
```

Required redirect URI for Pi: `http://127.0.0.1:33418/`

### Claude Code

Metadata URL: `https://claude.ai/oauth/claude-code-client-metadata`

Example metadata:
```json
{
  "client_id": "https://claude.ai/oauth/claude-code-client-metadata",
  "redirect_uris": ["http://localhost/callback","http://127.0.0.1/callback"],
  "grant_types": ["authorization_code","refresh_token"],
  "token_endpoint_auth_method": "none"
}
```

Allowed redirect URIs: `http://localhost/callback`, `http://127.0.0.1/callback`

### Finding other clients

Inspect the authorize URL the client builds when you connect to the server in that tool. The `client_id` parameter is usually a URL to a client metadata document.

Example:
```
https://<issuer>/authorize?client_id=https%3A%2F%2Fvscode.dev%2Foauth%2Fclient-metadata.json&...
```

Quick reference table:

| Server | Public client_id to try | Notes |
|--------|------------------------|-------|
| VS Code MCP Client | `https://vscode.dev/oauth/client-metadata.json` | Requires redirect_uri `http://127.0.0.1:33418/` |
| Claude Code MCP Client | `https://claude.ai/oauth/claude-code-client-metadata` | Redirects: `http://localhost/callback`, `http://127.0.0.1/callback` |
| Vendor A MCP | Same as VS Code | Requires compatible redirect_uri |
| Vendor B MCP | Same as above | Verify product access |
| Other MCP clients | Inspect authorize URL in those tools | Often public metadata URLs |
