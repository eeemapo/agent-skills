# Prerequisites and Technical Notes

## Prerequisites checklist

Before using a public client identity, confirm:
* Server is HTTP Streamable MCP with OAuth
* Authorization server advertises `client_id_metadata_document_supported: true`
* `token_endpoint_auth_methods_supported` includes `none`
* `code_challenge_methods_supported` includes `S256`
* The public client’s metadata document lists a redirect URI you can bind locally
* The public client is already granted access to the API product for the target resource
* You can reach the issuer’s `/.well-known/oauth-authorization-server` and the protected resource’s `/.well-known/oauth-protected-resource`

If any check fails, dynamic client registration or a custom third-party app is required.

## PKCE and token handling

* The flow uses Authorization Code with PKCE. pi-mcp-adapter generates the `code_verifier` and `code_challenge` automatically when `grantType` is `authorization_code` and `clientId` is a URL.
* No client secret is used; `token_endpoint_auth_method` is `none`.
* Tokens are stored per server name + URL in the OS credential store. Changing `clientId` invalidates previous tokens.
* Refresh tokens are supported if the public client metadata includes `refresh_token` in `grant_types` and the scope includes `offline_access`.

## Audience / resource

Many MCP servers require an audience / resource parameter matching the MCP service URL. Verify the issuer’s metadata for `audience` or the protected resource’s `resource` claim and ensure the server URL matches.

## Port contention

The public client’s redirect URI is fixed. Close VS Code / Claude Code or any other process using the same redirect port before authenticating with Pi.
