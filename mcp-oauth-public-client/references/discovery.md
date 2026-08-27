# Server OAuth Discovery

Discover the server and issuer metadata to confirm Client ID Metadata Document support.

```bash
curl -s https://<server>/.well-known/oauth-protected-resource/<path>
curl -s https://<issuer>/.well-known/oauth-authorization-server
```

Confirm the following claims in the issuer metadata:
* `client_id_metadata_document_supported: true`
* `code_challenge_methods_supported` includes `S256`
* `token_endpoint_auth_methods_supported` includes `none`

Verify support quickly:
```bash
curl -s "https://<issuer>/.well-known/oauth-authorization-server" | grep -q client_id_metadata_document_supported && echo "✓ Supports CIMD" || echo "✗ May require custom registration"
```

The protected resource metadata must list the issuer via `authorization_servers` and the resource URI you are connecting to.
