#!/bin/sh
#
# Render README.md (the index) and every examples/<dir>/README.md to a sibling README.pdf.
#
#   usage: tools/readme-pdf/build.sh [dir ...]
#
#   no arguments   rebuild every README.pdf in the repository
#   dir ...        rebuild only those directories' (names under examples/; use . for the top-level README)
#
# Adapted from tools/build-docs.sh in the altairsim repository. Same pipeline, so the PDFs look
# like the rest of altairsim's documents: pandoc turns the Markdown into one self-contained HTML
# page (fonts inlined), a Chromium browser prints it, and Paged.js -- running inside the browser --
# supplies the running page numbers. There is no LaTeX on purpose.
#
# Each PDF is printed into a temp directory and only moved beside its README once it has passed
# two checks: every font in it is one we ship, and the running page number is present.

set -eu

here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../.." && pwd)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

have() { command -v "$1" > /dev/null 2>&1; }

if ! have pandoc; then
  echo "build: pandoc is not installed -- it turns the Markdown into a page." >&2
  echo "       brew install pandoc   (or your platform's equivalent)" >&2
  exit 1
fi

chrome=""
for c in \
  "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" \
  "/Applications/Chromium.app/Contents/MacOS/Chromium" \
  "/Applications/Microsoft Edge.app/Contents/MacOS/Microsoft Edge" \
  google-chrome chromium chromium-browser microsoft-edge; do
  if [ -x "$c" ] || have "$c"; then chrome=$c; break; fi
done
if [ -z "$chrome" ]; then
  echo "build: no Chromium-based browser found -- one is the PDF engine." >&2
  exit 1
fi

have python3 || { echo "build: python3 is not installed -- chrome-print.py needs it." >&2; exit 1; }
pagedjs="$here/pagedjs/paged.polyfill.js"
[ -f "$pagedjs" ] || { echo "build: $pagedjs is missing -- it is the paginator." >&2; exit 1; }

# Every face in the finished PDF must be one we shipped. Embedding the fonts only guarantees they
# were OFFERED to the browser; a character neither font has is answered silently from the local
# machine's fonts, and renders differently on any other machine.
check_fonts() {  # check_fonts <pdf> <label>
  if have pdffonts; then
    faces=$(pdffonts "$1" | awk 'NR > 2 { print $1 }' | sed 's/^[A-Z]*+//' |
            sort -u | grep -v '^$' || true)
    strangers=$(echo "$faces" | grep -vxE 'XCharter-(Roman|Bold|Italic|BoldItalic)|DejaVuSansMono(-Bold)?' || true)
    if [ -n "$strangers" ]; then
      echo "build: $2 is set in fonts WE DID NOT SHIP:" >&2
      echo "$strangers" | sed 's/^/         /' >&2
      echo "       Some character is not in XCharter or DejaVu Sans Mono, so the browser borrowed a" >&2
      echo "       face from THIS machine. Find it (usually a symbol or arrow in bold/italic) and" >&2
      echo "       write it differently, or extend the fallback chain in print.css." >&2
      exit 1
    fi
  else
    echo "build: (no pdffonts -- skipping the font check; install poppler)" >&2
  fi
}

# Splice Paged.js into the page, print it with chrome-print.py (which waits for Paged.js), then
# read the PDF back: no bare page-number line means Paged.js did not run and the browser printed
# the un-paginated document.
paginate() {  # paginate <html> <pdf> <label>
  {
    printf '<script>window.PagedConfig={after:function(f){document.title="PAGES_"+f.total;}};</script>\n'
    printf '<script>\n'
    cat "$pagedjs"
    printf '\n</script>\n'
  } > "$work/inject.html"

  # pandoc emits the closing tag alone on its own line; </body> in prose is escaped.
  awk -v injf="$work/inject.html" '
    $0=="</body>" { while((getline l < injf) > 0) print l }
    { print }
  ' "$1" > "$1.paged" && mv "$1.paged" "$1"

  python3 "$here/chrome-print.py" "$chrome" "$1" "$2" || {
    echo "build: $3 -- the browser/Paged.js print failed (see above)." >&2; exit 1; }
  [ -s "$2" ] || { echo "build: $3 came out empty." >&2; exit 1; }

  if have pdftotext; then
    if ! pdftotext "$2" - 2>/dev/null | grep -qE '^[[:space:]]*[0-9]+[[:space:]]*$'; then
      echo "build: $3 has NO running page numbers -- Paged.js did not paginate it." >&2
      exit 1
    fi
  fi
}

build_readme() {  # build_readme <src.md relative to root>
  rel=$1
  src=$root/$rel
  dst=$root/${rel%.md}.pdf
  [ -f "$src" ] || { echo "build: $rel does not exist." >&2; exit 1; }

  # The H1 IS the title. Promote it out of the body so it renders once, as the title block.
  # awk, not `sed '0,/re/'`: that address is a GNU extension BSD/macOS sed silently ignores.
  title="altairsim — $(sed -n 's/^# *//p' "$src" | head -1)"
  awk 'dropped || !/^# /{print; next} {dropped=1}' "$src" > "$work/readme.md"

  stamp="$(git -C "$root" rev-parse --short HEAD 2>/dev/null || echo '?')"
  date="$(date -u '+%Y-%m-%d')"

  pandoc "$work/readme.md" \
    --standalone --embed-resources \
    --from=gfm --to=html5 \
    --metadata title="$title" \
    --css "$here/print.css" \
    --metadata subtitle="$date · $stamp" \
    -o "$work/readme.html"

  paginate "$work/readme.html" "$work/readme.pdf" "$rel -> pdf"
  check_fonts "$work/readme.pdf" "$rel -> pdf"

  mv "$work/readme.pdf" "$dst"
  echo "build: ${dst#"$root"/}"
}

if [ "$#" -eq 0 ]; then
  for abs in "$root"/README.md "$root"/examples/*/README.md; do
    [ -f "$abs" ] || continue
        build_readme "${abs#"$root"/}"
  done
else
  for d in "$@"; do
    d=${d%/}
    if [ "$d" = . ]; then build_readme README.md; else build_readme "examples/${d#examples/}/README.md"; fi
  done
fi
