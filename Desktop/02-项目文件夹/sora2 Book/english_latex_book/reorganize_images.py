#!/usr/bin/env python3
"""
Script to reorganize images in the LaTeX book project.
Renames images to FigX-y format and updates all references in chapter files.
"""

import os
import re
import shutil
from pathlib import Path
from collections import defaultdict

# Base directory
BASE_DIR = Path("/Users/nellertcai/Desktop/sora2 Book/english_latex_book")
IMAGES_DIR = BASE_DIR / "images"
CHAPTERS_DIR = BASE_DIR / "chapters"

# Chapter files mapping
CHAPTERS = {
    1: "chapter01.tex",
    2: "chapter02.tex",
    3: "chapter03.tex",
    4: "chapter04.tex",
    5: "chapter05.tex",
    6: "chapter06.tex",
    7: "chapter07.tex",
    8: "chapter08.tex",
    9: "chapter09.tex",
}

def extract_images_from_chapter(chapter_file):
    """Extract all image filenames from a chapter file in order."""
    images = []
    with open(chapter_file, 'r', encoding='utf-8') as f:
        content = f.read()
        # Find all \includegraphics commands
        pattern = r'\\includegraphics\[.*?\]\{([^}]+)\}'
        matches = re.findall(pattern, content)
        images = [m for m in matches if m.endswith('.png')]
    return images

def create_image_mapping():
    """Create mapping from old image names to new FigX-y names."""
    mapping = {}
    chapter_images = defaultdict(list)

    # Extract images from each chapter
    for chapter_num, chapter_file in sorted(CHAPTERS.items()):
        chapter_path = CHAPTERS_DIR / chapter_file
        if chapter_path.exists():
            images = extract_images_from_chapter(chapter_path)
            chapter_images[chapter_num] = images
            print(f"Chapter {chapter_num}: {len(images)} images found")

            # Create mapping for this chapter
            for idx, img in enumerate(images, start=1):
                new_name = f"Fig{chapter_num}-{idx}.png"
                mapping[img] = new_name

    return mapping, chapter_images

def copy_and_rename_images(mapping):
    """Copy images with new names."""
    copied = []
    missing = []

    for old_name, new_name in mapping.items():
        old_path = IMAGES_DIR / old_name
        new_path = IMAGES_DIR / new_name

        if old_path.exists():
            shutil.copy2(old_path, new_path)
            copied.append((old_name, new_name))
            print(f"Copied: {old_name} -> {new_name}")
        else:
            missing.append(old_name)
            print(f"WARNING: Missing file: {old_name}")

    return copied, missing

def update_chapter_files(mapping):
    """Update all chapter files with new image names."""
    updated_files = []

    for chapter_num, chapter_file in sorted(CHAPTERS.items()):
        chapter_path = CHAPTERS_DIR / chapter_file
        if not chapter_path.exists():
            continue

        with open(chapter_path, 'r', encoding='utf-8') as f:
            content = f.read()

        original_content = content

        # Replace each image reference
        for old_name, new_name in mapping.items():
            if old_name in content:
                # Replace in \includegraphics commands
                content = content.replace(f'{{{old_name}}}', f'{{{new_name}}}')

        if content != original_content:
            # Backup original file
            backup_path = chapter_path.with_suffix('.tex.backup')
            shutil.copy2(chapter_path, backup_path)
            print(f"Backed up: {chapter_file} -> {backup_path.name}")

            # Write updated content
            with open(chapter_path, 'w', encoding='utf-8') as f:
                f.write(content)

            updated_files.append(chapter_file)
            print(f"Updated: {chapter_file}")

    return updated_files

def delete_old_images(mapping, copied):
    """Delete old image files after successful copy."""
    deleted = []

    for old_name, new_name in mapping.items():
        old_path = IMAGES_DIR / old_name

        # Only delete if it was successfully copied
        if any(c[0] == old_name for c in copied):
            if old_path.exists():
                old_path.unlink()
                deleted.append(old_name)
                print(f"Deleted: {old_name}")

    return deleted

def generate_report(mapping, chapter_images, copied, missing, updated_files, deleted):
    """Generate a detailed report."""
    report = []
    report.append("=" * 80)
    report.append("IMAGE REORGANIZATION REPORT")
    report.append("=" * 80)
    report.append("")

    # Summary statistics
    report.append("SUMMARY:")
    report.append(f"  Total images processed: {len(mapping)}")
    report.append(f"  Successfully copied: {len(copied)}")
    report.append(f"  Missing files: {len(missing)}")
    report.append(f"  Chapter files updated: {len(updated_files)}")
    report.append(f"  Old images deleted: {len(deleted)}")
    report.append("")

    # Images per chapter
    report.append("IMAGES PER CHAPTER:")
    for chapter_num in sorted(chapter_images.keys()):
        count = len(chapter_images[chapter_num])
        report.append(f"  Chapter {chapter_num}: {count} images")
    report.append("")

    # Detailed mapping
    report.append("DETAILED MAPPING (Old Name -> New Name):")
    report.append("-" * 80)
    for chapter_num in sorted(chapter_images.keys()):
        if chapter_images[chapter_num]:
            report.append(f"\nChapter {chapter_num}:")
            for img in chapter_images[chapter_num]:
                if img in mapping:
                    report.append(f"  {img:50s} -> {mapping[img]}")
    report.append("")

    # Missing files
    if missing:
        report.append("WARNING - MISSING FILES:")
        for f in missing:
            report.append(f"  - {f}")
        report.append("")

    # Updated chapter files
    report.append("UPDATED CHAPTER FILES:")
    for f in updated_files:
        report.append(f"  - {f}")
    report.append("")

    report.append("=" * 80)
    report.append("REORGANIZATION COMPLETE")
    report.append("=" * 80)

    return "\n".join(report)

def main():
    """Main execution function."""
    print("Starting image reorganization...\n")

    # Step 1: Create mapping
    print("Step 1: Creating image mapping...")
    mapping, chapter_images = create_image_mapping()
    print(f"Created mapping for {len(mapping)} images\n")

    # Step 2: Copy and rename images
    print("Step 2: Copying and renaming images...")
    copied, missing = copy_and_rename_images(mapping)
    print(f"Copied {len(copied)} images\n")

    # Step 3: Update chapter files
    print("Step 3: Updating chapter files...")
    updated_files = update_chapter_files(mapping)
    print(f"Updated {len(updated_files)} chapter files\n")

    # Step 4: Delete old images
    print("Step 4: Deleting old image files...")
    deleted = delete_old_images(mapping, copied)
    print(f"Deleted {len(deleted)} old images\n")

    # Step 5: Generate report
    print("Step 5: Generating report...")
    report = generate_report(mapping, chapter_images, copied, missing, updated_files, deleted)

    # Save report
    report_path = BASE_DIR / "image_reorganization_report.txt"
    with open(report_path, 'w', encoding='utf-8') as f:
        f.write(report)

    print(f"\nReport saved to: {report_path}")
    print("\n" + report)

if __name__ == "__main__":
    main()
