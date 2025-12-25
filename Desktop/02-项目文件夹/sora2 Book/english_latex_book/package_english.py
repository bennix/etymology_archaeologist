import os
import zipfile
import shutil

def package_english_version():
    root_dir = "/Users/nellertcai/Desktop/02-项目文件夹/sora2 Book/english_latex_book"
    package_name = "sora2_book_english_source.zip"
    
    # Files and directories to include
    include_files = [
        "main.tex",
        "glossary.tex",
        "references.bib",
        "build.sh",
        "compile_all.sh",
        "chapter_template.tex",
        "check_environments.py",
        "reorganize_images.py",
        "README.md",
        "PROJECT_SUMMARY.md",
        "QUICK_START.md"
    ]
    
    include_dirs = [
        "chapters",
        "appendices",
        "images"
    ]
    
    # Exclude patterns
    exclude_extensions = [".aux", ".log", ".backup", ".swp", ".out", ".toc", ".idx", ".ind", ".ilg", ".lof", ".lot", ".bbl", ".blg", ".acn", ".acr", ".alg", ".glg", ".glo", ".gls", ".ist"]
    
    zip_path = os.path.join(root_dir, package_name)
    
    with zipfile.ZipFile(zip_path, 'w', zipfile.ZIP_DEFLATED) as zipf:
        # Add root files
        for filename in include_files:
            file_path = os.path.join(root_dir, filename)
            if os.path.exists(file_path):
                zipf.write(file_path, filename)
                print(f"Added: {filename}")
            else:
                print(f"Warning: {filename} not found")
                
        # Add directories
        for dirname in include_dirs:
            dir_path = os.path.join(root_dir, dirname)
            if os.path.exists(dir_path):
                for root, dirs, files in os.walk(dir_path):
                    for file in files:
                        if any(file.endswith(ext) for ext in exclude_extensions):
                            continue
                        if file.startswith("."): # Skip hidden files like .DS_Store
                            continue
                        
                        abs_path = os.path.join(root, file)
                        rel_path = os.path.relpath(abs_path, root_dir)
                        zipf.write(abs_path, rel_path)
                        # print(f"Added: {rel_path}")
                print(f"Added directory: {dirname}")
            else:
                print(f"Warning: directory {dirname} not found")
                
    print(f"\nSuccessfully created: {zip_path}")
    print(f"Size: {os.path.getsize(zip_path) / (1024*1024):.2f} MB")

if __name__ == "__main__":
    package_english_version()
