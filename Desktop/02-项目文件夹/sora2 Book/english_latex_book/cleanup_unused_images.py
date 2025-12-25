#!/usr/bin/env python3
"""
Script to clean up unused image files.
Creates a backup archive before deletion.
"""

import os
import shutil
from pathlib import Path
from datetime import datetime

# Base directory
BASE_DIR = Path("/Users/nellertcai/Desktop/sora2 Book/english_latex_book")
IMAGES_DIR = BASE_DIR / "images"
BACKUP_DIR = BASE_DIR / "old_images_backup"

def get_unused_images():
    """Get list of image files that don't follow the FigX-y.png pattern."""
    unused = []

    for img_file in IMAGES_DIR.glob("*.png"):
        # Keep only files that match FigX-y.png pattern
        if not img_file.name.startswith("Fig") or not "-" in img_file.stem:
            unused.append(img_file)

    return sorted(unused)

def backup_and_delete_unused():
    """Backup unused images to a separate directory, then delete from images/."""
    unused = get_unused_images()

    if not unused:
        print("No unused images found.")
        return 0

    # Create backup directory
    BACKUP_DIR.mkdir(exist_ok=True)
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    backup_subdir = BACKUP_DIR / f"backup_{timestamp}"
    backup_subdir.mkdir(exist_ok=True)

    print(f"Backing up {len(unused)} unused images to: {backup_subdir}")

    backed_up = []
    deleted = []

    for img_file in unused:
        try:
            # Copy to backup
            backup_path = backup_subdir / img_file.name
            shutil.copy2(img_file, backup_path)
            backed_up.append(img_file.name)

            # Delete original
            img_file.unlink()
            deleted.append(img_file.name)

        except Exception as e:
            print(f"Error processing {img_file.name}: {e}")

    print(f"\nBackup complete: {len(backed_up)} files")
    print(f"Deleted from images/: {len(deleted)} files")

    # Create inventory file
    inventory_path = backup_subdir / "inventory.txt"
    with open(inventory_path, 'w') as f:
        f.write(f"Unused Images Backup - {timestamp}\n")
        f.write("=" * 80 + "\n\n")
        f.write(f"Total files backed up: {len(backed_up)}\n\n")
        f.write("Files:\n")
        for fname in sorted(backed_up):
            f.write(f"  {fname}\n")

    print(f"\nInventory saved to: {inventory_path}")

    return len(deleted)

def main():
    print("Unused Image Cleanup Script")
    print("=" * 80)

    unused = get_unused_images()
    print(f"\nFound {len(unused)} unused image files")

    if unused:
        print("\nSample of files to be removed:")
        for img in unused[:10]:
            print(f"  - {img.name}")
        if len(unused) > 10:
            print(f"  ... and {len(unused) - 10} more")

        response = input("\nProceed with backup and deletion? (yes/no): ").strip().lower()

        if response == 'yes':
            deleted_count = backup_and_delete_unused()
            print(f"\n✓ Successfully processed {deleted_count} files")
            print(f"✓ All files backed up to: {BACKUP_DIR}")
        else:
            print("\nOperation cancelled.")
    else:
        print("\n✓ No cleanup needed - all images are properly named!")

if __name__ == "__main__":
    main()
