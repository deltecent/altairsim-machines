# altairsim machines

Example machines for [**altairsim**](https://github.com/deltecent/altairsim), a simulator of the
MITS Altair 8800 and the S-100 boards and computers around it. Every machine here is written for
that simulator and runs on it; install altairsim first, and `altairsim` must be on your `PATH`.

Each machine is a directory under [`examples/`](examples/) holding a `.toml` machine file, the disk,
tape or ROM images it boots, and a README that says what you will see. Copy a directory anywhere
and it still runs. [`examples/README.md`](examples/README.md) lists every machine and what it is.

```
cd examples/hdsk
altairsim hdsk.toml
```

## What is here

| | |
|---|---|
| [`examples/`](examples/) | The machines, one directory each, with a `README.md` and `README.pdf`. Each directory also holds a `<dir>.zip` of all its files: download that one file, or the individual files, not both. |
| [`tests/`](tests/) | One test per machine. Each boots the machine in a scratch copy and checks what reaches the console. Run them with `tests/run.sh`. |
| [`tools/`](tools/) | The scripts that build the README PDFs and the machine zips. |
| [`.claude/skills/`](.claude/skills/) | Instructions for Claude Code: `open-pr` (open a PR, watch CI, test the zips), `readme-pdf` (build the README PDFs) and `simplified-english` (the writing style for the READMEs). |
| `.github/workflows/` | CI. It rebuilds the PDFs and zips for what changed and commits them to the pull request. |

The PDFs and zips are generated; edit the Markdown and the machine files, never those.
