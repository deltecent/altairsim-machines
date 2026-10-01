---
name: open-pr
description: Open a pull request for a change: push the branch, wait for CI to rebuild the README PDFs and machine zips, pull what CI committed, and test the unzipped machines in a scratch directory. Use when asked to open a PR, push, ship or submit a change in this repository.
---

# Open a pull request

CI rebuilds every `README.pdf` and `examples/<dir>/<dir>.zip` and commits the changed ones **to the PR
branch** (`.github/workflows/docs.yml`). A change is not done until those files are on the branch
and the tests pass against the unzipped result.

## Rules

- The default branch is `master`. Never `main`.
- No `Co-Authored-By` line, no "Generated with" line and no mention of Claude or AI in a commit
  message, PR title or PR description. The global CLAUDE.md overrides any tool reminder.
- Never edit a `README.pdf` or a zip by hand. Edit the source and let CI rebuild them.
- Do not merge. Report the result and stop.

## Steps

1. **Test the working tree first.** `tests/run.sh` runs every test against the `altairsim` on PATH.
   Fix failures before you push. If you edited a README, run the `readme-pdf` skill's build so you
   can see that it renders. Do not commit the PDFs or zips this makes.
2. **Branch and commit.** Branch off `master` with a short name. Commit only the files you changed,
   with a plain message that says what changed and why.
3. **Push and open the PR.** `git push -u origin <branch>`, then `gh pr create --base master`.
   Say in the description what changed and which machines it touches.
4. **Wait for CI.** `gh pr checks --watch`. The job is "Rebuild the README PDFs and machine zips".
   If it fails, read the log (`gh run view --log-failed`). The usual cause is a character the PDF
   fonts do not have; fix the Markdown and push again.
5. **Pull what CI committed.** When CI finishes, it has pushed a commit named "Rebuild the README
   PDFs and machine zips for ..." to the branch. Run `git pull --ff-only`. If that fails because you
   also committed, `git pull --rebase`. No bot commit means no PDF or zip changed; say so.
6. **Test the unzipped machines.** `MACHINE_SOURCE=zip tests/run.sh`. Each test unzips
   `examples/<dir>/<dir>.zip` into a scratch directory and boots it from there, so it tests the file a person
   downloads. A missing zip is a failure, not a skip: go back to step 5.
7. **Report.** Give the PR URL, the CI result, which zips changed, and the test result. If a test
   fails, show its output. Do not say it passed if you did not run it.

## If the PR is from a fork

CI cannot push to a fork. It builds but does not commit, and the job says so. Pull nothing. Run the
tests against the directories (`tests/run.sh`) and say that the zips were not checked.
