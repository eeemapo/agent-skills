---
name: mcp-oauth-public-client
description: Use a public MCP client identity such as VS Code or Claude Code to authenticate to OAuth-protected MCP servers that require pre-registered clients. Useful when a server does not support dynamic client registration and you do not want to create your own third-party app.
license: MIT
metadata:
  author: eapodaca
---

# MCP OAuth Public Client

Borrow a public MCP client identity to authenticate to an OAuth-protected MCP server.

## When to use

* Server is HTTP Streamable MCP with OAuth
* Authorization server advertises `client_id_metadata_document_supported: true`
* Attempting OAuth with pi-mcp-adapter fails with:
  * `Incompatible auth server: does not support dynamic client registration`
  * `AUTH-001 The client_id specified does not have access to the api product`
* You do not want to create your own third-party app and wait for product access

This pattern is common with vendors that only allow pre-registered clients and do not support dynamic client registration.

See prerequisites and technical notes in [references/prerequisites.md](references/prerequisites.md).

## Core idea

OAuth Client ID Metadata Documents let a client identify itself by a URL. The authorization server fetches that URL, validates the metadata, and treats the client as the identity described there.

If a public client such as VS Code, Claude Code, or OpenAI has already been registered with the vendor and granted access to the API product, you can reuse that client identity by pointing your MCP config at the public client’s metadata URL.

You are still authenticating as yourself – the user login is yours. You are only reusing the client registration that the vendor already trusts.

## Workflow

### 1. Discover server OAuth metadata

Details and commands: [references/discovery.md](references/discovery.md)

### 2. Find a public client identity

Public client metadata examples and how to find others: [references/public-clients.md](references/public-clients.md)

### 3. Configure pi-mcp-adapter

Configuration examples and constraints: [references/config-examples.md](references/config-examples.md)

### 4. Authenticate

```
/reload
mcp({ action: "auth-start", server: "vendor-mcp" })
```
You will be sent to vendor sign-in, then back to the redirect URI. Tokens are stored in the OS credential store.

## Gotchas

* **Port contention**: The public client’s redirect URI is fixed. Close VS Code / other clients using the same port before authenticating with Pi.
* **Redirect URI mismatch**: Must match exactly one of the `redirect_uris` in the client metadata document.
* **Product access**: The public client must already be granted access to the API product. If not, you’ll still get an access error.
* **Token isolation**: Tokens are stored per server name + URL. Changing client_id invalidates previous tokens.

For PKCE, audience/resource handling, token refresh, and a full prerequisites checklist, see [references/prerequisites.md](references/prerequisites.md).
