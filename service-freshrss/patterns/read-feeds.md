# Read feeds and articles

All reads use the `Authorization: GoogleLogin auth=<token>` header and return
JSON with `?output=json`.

## Subscriptions

    scripts/freshrss.sh subscriptions

Returns `{"subscriptions":[{"id":"feed/<url>","title":"...","categories":[...]}, ...]}`.

## Tags / labels

    scripts/freshrss.sh tags

## Articles from a stream

    scripts/freshrss.sh stream "user/-/state/com.google/reading-list" 20

Common stream IDs:

- `user/-/state/com.google/reading-list` — all unread items
- `user/-/state/com.google/starred` — starred items
- `feed/<feed-url>` — items from one feed

Use `n` to bound the page size. Large accounts should page rather than pull
everything at once.
