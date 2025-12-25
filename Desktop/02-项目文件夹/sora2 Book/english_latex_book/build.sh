#!/bin/bash
# Build script for "The Handbook of Sora 2 Prompting"
# This script compiles the LaTeX source with proper index generation

set -e

echo "=========================================="
echo "Building: The Handbook of Sora 2 Prompting"
echo "=========================================="

# Clean auxiliary files
echo "[1/6] Cleaning auxiliary files..."
rm -f main.out main.aux main.toc main.idx main.ind main.ilg main.lof main.lot main.bbl main.blg
rm -f chapters/*.aux

# First pass - generate auxiliary files
echo "[2/6] First LaTeX pass..."
pdflatex -interaction=nonstopmode main.tex > /dev/null 2>&1 || true

# Generate bibliography
echo "[3/6] Processing bibliography..."
bibtex main > /dev/null 2>&1 || true

# Generate index
echo "[4/6] Generating index..."
if [ -f main.idx ]; then
    makeindex main.idx > /dev/null 2>&1 || true
fi

# Second pass - incorporate references
echo "[5/6] Second LaTeX pass..."
pdflatex -interaction=nonstopmode main.tex > /dev/null 2>&1 || true

# Third pass - finalize cross-references
echo "[6/6] Final LaTeX pass..."
pdflatex -interaction=nonstopmode main.tex

# Check result
if [ -f main.pdf ]; then
    echo ""
    echo "=========================================="
    echo "Build successful!"
    echo "Output: main.pdf"
    ls -lh main.pdf
    echo "=========================================="
else
    echo ""
    echo "Build failed. Check main.log for errors."
    exit 1
fi

