---
name: add-example
description: Add a new machine directory under examples/: the machine files, the README, the index entries, a test, and the checks before a pull request. Use when asked to add, import or commit an example or machine, including a directory that is already in the working tree but untracked.
---

# Add an example

A new example is not done when its files are in `examples/<dir>/`. It is done when the machine
boots under a test, the README follows the writing standard, and the indexes list it. Do the steps
in order. Do not commit before step 4.

## Rules

- The default branch is `master`. Branch off it with a short name. Never commit to `master`.
- No `Co-Authored-By` line, no "Generated with" line and no mention of Claude or AI in a commit
  message, PR title or PR description. The global CLAUDE.md overrides any tool reminder.
- Never edit a `README.pdf` or a `<dir>.zip` by hand. CI builds both (`open-pr` skill).
- Run the `altairsim` on PATH. Never the binary in the altairsim build tree.
- Do not change `~/src/altairsim`. A simulator bug goes in `BUGS.md`.
- Do not report a step as done if you did not run it.

## Steps

1. **Look at what exists.** The directory may already be in the working tree, untracked. Run
   `git status --short examples/<dir>` and read every file in it: each `.toml`, the README and
   the file list. Check that `examples/README.md` and the top-level `README.md` do not list it yet,
   or already list it.
2. **Check the directory is self-contained.** Every file a machine file names must be in the
   directory, and each path in a machine file names no directory (paths resolve against the file).
   `.altairsim_history` is ignored by `.gitignore`; do not add it. A machine that needs hardware
   or a program that the repository does not ship (a serial drive server, for example) says so
   in its README and in the top comment of its machine file.
3. **Boot every machine.** Copy the directory to a scratch directory, run each machine file from
   inside the copy, and read what reaches the console. Run `altairsim <file>.toml < keys`, as
   `tests/lib.sh` does. A machine that cannot run here is listed in the report, not skipped
   without a word.
4. **Write the test.** Add `tests/test-<dir>.sh` in the style of `tests/test-hdsk.sh`, and a
   keystroke file `tests/keys/<dir>-<what>.keys` if no existing one fits.
   - Check text that can only come from the guest: its banner, its prompt, and one directory
     entry or output line that the disk alone holds.
   - Run it twice: from inside the directory, and by path from the parent.
   - One `expect_contains` for each machine file that can run unattended.
   - Run `tests/run.sh <dir>`. It must pass before you go on.
5. **Check the README against `simplified-english`.** Run that skill on `examples/<dir>/README.md`.
   Apply the findings, then check the result again. The top comment of each machine file is also
   text a reader reads: apply the same standard to it.
6. **Add the index entries.** This step is part of the work: an example with no row in
   `examples/README.md` is not done, and a directory that was untracked often has none. Add a row
   to the right table in `examples/README.md`, in alphabetical order by directory name. Keep each
   table sorted. Use the style of
   the rows around it: a link, the system in bold, what boots, and the machine file names. Check
   the top-level `README.md` for a list that also needs the row.
7. **Build the PDFs to look at them.** Run the `readme-pdf` skill so that you can see the new
   README and the index render. Do not commit what this builds. If a `README.pdf` is already
   in the directory, CI replaces it when the README changes.
8. **Run the whole suite.** `tests/run.sh`. A failure in a machine you did not touch is
   a finding to report, not something to fix in this change.
9. **Commit.** `git add` the directory, the test, the keystroke file and the index rows. Leave out
   other untracked directories. Use a plain message that says what the example is.
   Then follow the `open-pr` skill: push, open the PR, wait for CI, pull what CI committed, and
   run `MACHINE_SOURCE=zip tests/run.sh`.

## Report

Give: the machines you booted and what each printed, the test file and its result, the
`simplified-english` result, the index rows you added, and anything you could not test. Say if a
step did not run.
