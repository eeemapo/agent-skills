# Write actions

Write verbs mutate the account. They refuse to run without `--yes` (exit 3):

    scripts/freshrss.sh mark-read <itemId> --yes
    scripts/freshrss.sh mark-unread <itemId> --yes
    scripts/freshrss.sh star <itemId> --yes
    scripts/freshrss.sh unstar <itemId> --yes
    scripts/freshrss.sh subscribe <feedUrl> [--title T] --yes
    scripts/freshrss.sh unsubscribe <streamId|feedUrl> --yes
    scripts/freshrss.sh mark-all-read <streamId> --yes

## Getting an item id

    scripts/freshrss.sh stream "user/-/state/com.google/reading-list" 20

Each entry has an `id` like `tag:google.com,2005:reader/item/<hex>`. Pass that
as `<itemId>`. To confirm one item, use `scripts/freshrss.sh item <itemId>`.

## Mechanism

Writes POST to `/reader/api/0/edit-tag` (read/starred) or
`/reader/api/0/subscription/edit` (feeds) with a **per-session action token**
from `GET /reader/api/0/token`, sent as `T=`. The script fetches that token
automatically on each write.

## Guidance

- Ask the user before any write. `--yes` is an explicit approval token, not a
  formality.
- Prefer the narrowest change (`star` one item) over broad ones
  (`mark-all-read`).
- Verify with a read afterwards (`item <itemId>`) if the outcome matters.
