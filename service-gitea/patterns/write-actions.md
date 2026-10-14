# Write actions

Write verbs mutate the server. They **refuse to run without `--yes`** (exit 3):

    scripts/gitea.sh repo-create <name> [--private] [--description D] --yes
    scripts/gitea.sh repo-delete <owner/repo> --yes
    scripts/gitea.sh issue-create <owner/repo> --title T [--body B] --yes
    scripts/gitea.sh issue-close <owner/repo> <index> --yes
    scripts/gitea.sh issue-comment <owner/repo> <index> --body B --yes

## Guidance

- **Ask the user before any write.** `--yes` is an explicit approval token. Do
  not pass it "just to see if it works".
- **Prefer the narrowest change.** Comment on one issue rather than bulk-editing.
- **Verify after writing**: re-read with the matching read verb
  (`issues`, `repo`) to confirm the result.
- **Deletes are irreversible.** `repo-delete` removes the repository and its
  data; confirm the exact `owner/repo` first.

## Scope reminder

Creating or deleting a repository needs the **`write:user`** scope. If you get a
`403` naming `required=[write:user]`, the token is fine for issues/PRs but not for
repo lifecycle — report that rather than retrying.
