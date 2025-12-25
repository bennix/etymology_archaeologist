#!/bin/bash
# Verification script for image reorganization

echo "=========================================="
echo "Image Reorganization Verification"
echo "=========================================="
echo ""

echo "1. Checking images directory..."
IMG_COUNT=$(ls -1 images/Fig*.png 2>/dev/null | wc -l)
echo "   ✓ Found $IMG_COUNT FigX-y.png files"

OLD_COUNT=$(ls -1 images/image-*.png 2>/dev/null | wc -l)
if [ "$OLD_COUNT" -eq 0 ]; then
    echo "   ✓ No old image-*.png files remaining"
else
    echo "   ⚠ WARNING: $OLD_COUNT old image files still exist"
fi
echo ""

echo "2. Checking chapter files..."
for i in {1..9}; do
    CHAPTER="chapters/chapter0$i.tex"
    if [ -f "$CHAPTER" ]; then
        REF_COUNT=$(grep -c "includegraphics.*Fig$i-" "$CHAPTER" 2>/dev/null || echo 0)
        if [ "$REF_COUNT" -gt 0 ]; then
            echo "   ✓ Chapter $i: $REF_COUNT FigX-y references"
        fi
    fi
done
echo ""

echo "3. Checking for broken references..."
BROKEN=$(grep -r "includegraphics.*image-2025" chapters/*.tex 2>/dev/null | wc -l)
if [ "$BROKEN" -eq 0 ]; then
    echo "   ✓ No broken image references found"
else
    echo "   ⚠ WARNING: $BROKEN broken references found"
fi
echo ""

echo "4. Checking backups..."
if [ -d "old_images_backup" ]; then
    BACKUP_COUNT=$(find old_images_backup -name "*.png" | wc -l)
    echo "   ✓ Backup directory exists with $BACKUP_COUNT files"
else
    echo "   ⚠ No backup directory found"
fi

if ls chapters/*.backup 1> /dev/null 2>&1; then
    BACKUP_TEX=$(ls -1 chapters/*.backup 2>/dev/null | wc -l)
    echo "   ✓ $BACKUP_TEX chapter backup files found"
else
    echo "   ⚠ No chapter backup files found"
fi
echo ""

echo "=========================================="
echo "Verification Complete"
echo "=========================================="
