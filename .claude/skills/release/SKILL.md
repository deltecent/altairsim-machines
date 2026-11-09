---
name: release
description: Make a release of altairsim-machines — write the "What's new in <version>" section of examples/README.md for the changes since the last tag, merge it through a PR, then tag the merge commit. Use when asked to release, tag or version the repository (for example "tag as 1.3.6"), usually after the last PR of the release is merged.
---

# Make a release

A release is a tag on `master` whose `examples/README.md` says what is new in that release. The
tag goes on after the "What's new" section is merged, never before.

## Rules

- The default branch is `master`. Never `main`.
- No `Co-Authored-By` line, no "Generated with" line and no mention of Claude or AI in a commit,
  PR or tag message. The global CLAUDE.md overrides any tool reminder.
- A tag is the version alone (`1.3.6`, no `v`). It is an annotated tag whose message is the
  version: `git tag -a 1.3.6 -m 1.3.6 <commit>`.
- Do not make a GitHub release. The earlier tags have none.
- Do not move a tag that is already pushed unless the user asks.

## Steps

1. **Find the changes.** On an up-to-date `master`, find the last tag
   (`git tag --sort=-creatordate | head -1`). Read `git log --no-merges <last>..master`, leaving
   out the CI commits "Rebuild the README PDFs and machine zips", and
   `git diff --stat <last> master`.
2. **Write the section.** On a new branch `whats-new-<version>`, replace the whole
   `## What's new in <last>` section of `examples/README.md` with `## What's new in <version>`.
   List only what changed since the last tag. The section of the last release is already in
   that tag, so do not keep its lines.
   - **New machines:** one line for each new directory, with a link, as in the Disk systems
     table: `- [`vg/`](vg/): **CP/M** and ... .`
   - **Changes:** one line for each changed directory, or for a change to many directories,
     that a user of the machine notices: new disks, new files, a change in what the machine
     does. Leave out changes to tests, tools and skills alone.
   - Leave out a heading that has no lines.
   - Write to the `simplified-english` skill.
3. **Open the PR.** Follow the `open-pr` skill: test, commit, push, wait for CI, pull its commit,
   and run `MACHINE_SOURCE=zip tests/run.sh`.
4. **Merge.** Follow the `merge-pr` skill.
5. **Tag.** On `master`, after `git pull --ff-only`, tag the merge commit of step 4 and push the
   tag: `git push origin <version>`. Check it with `git ls-remote --tags origin <version>`.

## Report

Give the PR URL, the merge commit, the tag and the commit it points at, and the lines of the
"What's new" section.
