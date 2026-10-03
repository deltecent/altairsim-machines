---
name: merge-pr
description: Merge a pull request in this repository, then delete the local and remote branch. Use when asked to merge a PR or a branch. Do not merge unless the user asks.
---

# Merge a pull request

Merge only when the user asks. The `open-pr` skill stops before this step.

## Rules

- The default branch is `master`. Never `main`.
- Use a merge commit (`gh pr merge --merge`), not a squash or a rebase. The history of this
  repository has merge commits.
- No `Co-Authored-By` line, no "Generated with" line and no mention of Claude or AI in a merge
  commit message. The global CLAUDE.md overrides any tool reminder.
- Delete the branches only after the merge succeeded. If the merge fails, delete nothing.
- Never delete `master`, and never delete a branch that has unpushed commits or that is not the
  branch of this PR.

## Steps

1. **Check the PR.** `gh pr view <n> --json state,mergeable,headRefName`. It must be open and
   mergeable. The CI job "Rebuild the README PDFs and machine zips" must have finished, and you
   must have pulled the commit it pushed (`open-pr` steps 4-6).
2. **Merge.** `gh pr merge <n> --merge`. Do not pass `--delete-branch`: it fails to delete the
   local branch when you are on it. Delete the branches yourself in the next steps.
3. **Confirm.** `gh pr view <n> --json state,mergeCommit` must say `MERGED`.
4. **Leave the branch and update `master`.** `git switch master`, then `git pull --ff-only`.
5. **Delete the local branch.** `git branch -d <branch>`. Use `-d`, not `-D`: if git refuses, the
   branch has commits that are not in `master`. Stop and say so.
6. **Delete the remote branch.** `git push origin --delete <branch>`. If GitHub already
   deleted it, this fails with "remote ref does not exist"; that is fine. Then `git fetch --prune`.

## Report

Give the PR URL, the merge commit, and which branches you deleted (local and remote). Say if a
step did not run.
