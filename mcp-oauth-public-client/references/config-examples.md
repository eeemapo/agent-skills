# Configuration Examples

## pi-mcp-adapter config

In `.mcp.json` / `~/.config/mcp/mcp.json`:

```json
{
  "mcpServers": {
    "vendor-mcp": {
      "url": "https://api.vendor.com/mcp/service",
      "auth": "oauth",
      "lifecycle": "lazy",
      "protocolVersion": "auto",
      "oauth": {
        "grantType": "authorization_code",
        "clientId": "https://vscode.dev/oauth/client-metadata.json",
        "scope": "mcp:read mcp:write offline_access",
        "redirectUri": "http://127.0.0.1:33418/"
      }
    }
  }
}
```

Important constraints:
* `clientId` must be a URL that matches the public client’s metadata document
* `redirectUri` must be one of the `redirect_uris` listed in that metadata document
* Do not run another process on the same redirect port while authenticating

### Authentication flow

```
/reload
mcp({ action: "auth-start", server: "vendor-mcp" })
```

You will be sent to vendor sign-in, then back to the redirect URI. Tokens are stored in the OS credential store.

## Full example

Server: `https://api.vendor.com/mcp/service`
Issuer: `https://api.vendor.com/oauth`
Client metadata: `https://vscode.dev/oauth/client-metadata.json`
Redirect: `http://127.0.0.1:33418/`
Scope: `mcp:read mcp:write offline_access`
Audience: `https://api.vendor.com/mcp/service`
