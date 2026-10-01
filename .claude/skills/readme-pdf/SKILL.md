---
name: readme-pdf
description: Render README.md (the index) and each machine directory's README.md to a sibling README.pdf, the way the altairsim repository does it. Use after editing any README.md, after adding or changing a machine directory, or when asked to build, rebuild or check the README PDFs.
---

# README.md → README.pdf

Every directory here has a `README.md` and a `README.pdf` beside it, and so does the top level.
A file manager has no Markdown viewer, so the PDF is what a person opens. **The PDF is generated;
edit the Markdown, never the PDF.**

## Build

```sh
tools/readme-pdf/build.sh              # every README.pdf in the repository
tools/readme-pdf/build.sh fdcplus      # one directory
tools/readme-pdf/build.sh . acr uio    # the top-level README, then two directories
```

It needs `pandoc`, a Chromium-based browser (Chrome, Chromium or Edge), `python3`, and — for the
two checks below — poppler's `pdffonts` and `pdftotext`. There is no LaTeX. The script says what
is missing and how to get it.

## What it does

pandoc turns the Markdown (GitHub flavour) into one self-contained HTML page with the fonts
inlined; Paged.js is spliced in; `chrome-print.py` drives the browser over the DevTools protocol,
waits for Paged.js to finish, and prints. The first `# ` heading becomes the title block
(`altairsim — <heading>`) and is dropped from the body. There is no contents page. The subtitle
is `<date> · <short git hash>`.

Everything it needs is in `tools/readme-pdf/` (`build.sh`, `chrome-print.py`, `print.css`, `fonts/`,
`pagedjs/`). It began as a copy of the altairsim tooling and is now maintained here. To change the
look of the PDFs, edit `print.css`.

## The two checks — do not bypass them

The PDF is printed into a temp directory and only moved next to its README if it passes:

1. **Every font in it is one we ship** (XCharter, DejaVu Sans Mono). A character neither font has
   makes the browser quietly borrow a face from this machine, which another machine will not have.
   If the build fails here, find the character — usually a symbol or arrow in bold or italic —
   and write it differently, or extend the fallback chain in `tools/readme-pdf/print.css`.
2. **A running page number is present.** If not, Paged.js did not run and the browser printed an
   unpaginated document.

A failed check leaves the old PDF in place. Fix the cause; do not copy the temp file.

## When to run it

- After any README edit: rebuild that directory, then the top-level one if its table row changed.
- Commit the `.md` and the `.pdf` together. A PDF whose text does not match its Markdown is a bug.
- Comparing PDFs as bytes is useless: the subtitle stamp and Chrome's `/CreationDate` differ every
  build. To ask whether the content moved, compare `pdftotext` output with the stamp line removed.
- Every machine directory needs a README.md; a directory without one gets no PDF. The build-all
  run skips `tests/`, `tools/` and `tests-from-altairsim/` (not machines) and any directory with no README.md.
- Machine files and README text must agree: launch commands name the `.toml` in that directory,
  run from inside it.
