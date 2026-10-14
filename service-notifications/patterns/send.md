# Sending a notification

## Choose a path

| Path | Use when |
|------|----------|
| `bark` | You have the device key and want a direct push with level control |
| `apprise` | The hub is configured with several destinations, or you want Apprise's type vocabulary |

Both ultimately reach the same phone. Prefer `apprise` when the deployment has a
hub (it centralises destinations); prefer `bark` for level control and a direct
push.

## Examples

    scripts/notify.sh bark "Backup complete" "12 files, no errors"
    scripts/notify.sh bark "Deploy failed" "step 3 exited 1" --level timeSensitive
    scripts/notify.sh apprise "Nightly report" "All green" --type success

## Etiquette

- **One message per outcome.** Do not narrate progress; the lock screen is not a log.
- Put the *what* in the title and the *detail* in the body.
- Use `--level passive` for low-importance notices so they do not wake anyone.
- Stay under ~120 characters of body where possible.

## Verifying delivery

    scripts/notify.sh ping     # {"code":200,"message":"pong"}
    scripts/notify.sh info     # bark v2.3.7 — 3 device(s)

A `200` from `/push` means the server accepted the message for APNs; it does not
prove the device displayed it.
