#!/usr/bin/env bash
#
# build-pdf.sh — assemble the SigmaLoop documentation book into a single PDF.
#
# Auto-detects an available converter and uses the best one. Run from anywhere:
#
#     docs/build-pdf.sh
#
# Output: docs/SigmaLoop-Documentation.pdf  (and the merged docs/SigmaLoop-Documentation.md)
#
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOK="$HERE/book"
META="$BOOK/metadata.yaml"
MERGED_MD="$HERE/SigmaLoop-Documentation.md"
OUT_PDF="$HERE/SigmaLoop-Documentation.pdf"

# Chapter files in reading order (numeric sort handles 00..20 then appendices).
mapfile -t CHAPTERS < <(find "$BOOK" -maxdepth 1 -name '*.md' | sort)

echo "==> Found ${#CHAPTERS[@]} chapter files."

# ---------------------------------------------------------------------------
# 1. pandoc + LaTeX  (best output: real ToC, chapter breaks, page numbers)
# ---------------------------------------------------------------------------
if command -v pandoc >/dev/null 2>&1; then
  echo "==> pandoc found. Building with pandoc."
  ENGINE=""
  for e in xelatex lualatex pdflatex tectonic wkhtmltopdf; do
    if command -v "$e" >/dev/null 2>&1; then ENGINE="$e"; break; fi
  done

  if [ -n "$ENGINE" ]; then
    echo "    Using PDF engine: $ENGINE"
    # weasyprint/wkhtmltopdf go through the HTML writer; LaTeX engines are native.
    if [ "$ENGINE" = "wkhtmltopdf" ]; then
      pandoc "${CHAPTERS[@]}" --metadata-file="$META" \
        --toc --pdf-engine=wkhtmltopdf -o "$OUT_PDF"
    else
      pandoc "${CHAPTERS[@]}" --metadata-file="$META" \
        --toc --pdf-engine="$ENGINE" \
        -V geometry:margin=1in -o "$OUT_PDF"
    fi
    echo "==> Done: $OUT_PDF"
    exit 0
  else
    echo "    pandoc has no PDF engine available; producing HTML instead."
    pandoc "${CHAPTERS[@]}" --metadata-file="$META" --toc -s \
      -o "$HERE/SigmaLoop-Documentation.html"
    echo "==> Wrote HTML: $HERE/SigmaLoop-Documentation.html (open & print to PDF)."
    exit 0
  fi
fi

# ---------------------------------------------------------------------------
# 2. Merge everything into one Markdown file (used by the remaining paths)
# ---------------------------------------------------------------------------
echo "==> pandoc not found. Merging chapters into $MERGED_MD"
: > "$MERGED_MD"
for f in "${CHAPTERS[@]}"; do
  # Skip the YAML metadata file from the body.
  case "$f" in *metadata.yaml) continue;; esac
  cat "$f" >> "$MERGED_MD"
  printf '\n\n\\newpage\n\n' >> "$MERGED_MD"
done
echo "    Merged $(wc -l < "$MERGED_MD") lines."

# ---------------------------------------------------------------------------
# 3. npx md-to-pdf  (Node-only; downloads a headless Chromium once)
# ---------------------------------------------------------------------------
if command -v npx >/dev/null 2>&1; then
  echo "==> Trying: npx md-to-pdf (first run downloads Chromium)."
  if npx --yes md-to-pdf "$MERGED_MD" >/dev/null 2>&1; then
    # md-to-pdf writes alongside the input as .pdf
    mv "$HERE/SigmaLoop-Documentation.pdf" "$OUT_PDF" 2>/dev/null || true
    echo "==> Done: $OUT_PDF"
    exit 0
  else
    echo "    md-to-pdf failed (often a sandboxed-Chromium issue). Falling through."
  fi
fi

# ---------------------------------------------------------------------------
# 4. weasyprint (HTML/CSS -> PDF) if present
# ---------------------------------------------------------------------------
if command -v weasyprint >/dev/null 2>&1 && command -v markdown >/dev/null 2>&1; then
  echo "==> Trying: markdown + weasyprint."
  markdown "$MERGED_MD" > "$HERE/_tmp.html"
  weasyprint "$HERE/_tmp.html" "$OUT_PDF"
  rm -f "$HERE/_tmp.html"
  echo "==> Done: $OUT_PDF"
  exit 0
fi

# ---------------------------------------------------------------------------
# Fallback: leave the merged Markdown and explain.
# ---------------------------------------------------------------------------
cat <<EOF

==> No PDF converter available on this machine.
    The full book has been merged into:

        $MERGED_MD

    Convert it with ONE of:

        sudo apt-get install pandoc texlive-xetex   # then re-run this script
        npm i -g md-to-pdf && md-to-pdf "$MERGED_MD"
        # or open the .md in any Markdown editor and "Export to PDF"

EOF
exit 0
