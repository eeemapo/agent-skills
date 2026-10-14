# Reading repositories, issues, and CI

## Repositories

    scripts/gitea.sh repos                 # yours
    scripts/gitea.sh repo owner/name       # name, private, default branch, size
    scripts/gitea.sh search <query>        # by name/description

## Issues and pull requests

    scripts/gitea.sh issues owner/name            # open (default)
    scripts/gitea.sh issues owner/name all        # every state
    scripts/gitea.sh pulls  owner/name            # PRs only

Gitea returns pull requests from the issues endpoint; the `issues` verb filters
them out (`select(.pull_request == null)`), so use `pulls` for PRs.

Output is `#<number>\t<state>\t<title>` — one line per row.

## Actions runs

    scripts/gitea.sh runs owner/name

Prints `#<run>\t<status>\t<conclusion>\t<branch>\t<title>` for the most recent
runs. An empty result usually means the repo has no workflows yet.

## Files

    scripts/gitea.sh file owner/name README.md          # ref defaults to main
    scripts/gitea.sh file owner/name path/to/f.yml dev

Decodes the API's base64 `content` field to raw bytes.

## Paging

Lists default to `limit=50`. If you need more, narrow with a search query rather
than raising the limit; the API caps pages anyway.
