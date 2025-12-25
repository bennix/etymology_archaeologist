import os
import shutil
import re
import subprocess
import zipfile

def repackage_chapters():
    root_dir = "/Users/nellertcai/Desktop/02-项目文件夹/sora2 Book/english_latex_book"
    chapters_dir = os.path.join(root_dir, "chapters")
    images_dir = os.path.join(root_dir, "images")
    output_root = os.path.join(root_dir, "chapter_packages")
    build_script_src = os.path.join(output_root, "chapter_build.sh")
    readme_src = os.path.join(output_root, "chapter_README.md")
    
    if not os.path.exists(output_root):
        os.makedirs(output_root)

    # Find all chapter and appendix files
    chapter_files = [f for f in os.listdir(chapters_dir) if f.endswith(".tex") and not f.endswith(".backup") and not f.startswith(".")]
    
    appendices_dir = os.path.join(root_dir, "appendices")
    appendix_files = [f for f in os.listdir(appendices_dir) if f.endswith(".tex") and not f.endswith(".backup") and not f.startswith(".")]

    # Sort chapters: chapter01, chapter02... chapter10, then comparison
    def chap_sort_key(filename):
        if "comparison" in filename:
            return 999
        match = re.search(r"chapter(\d+)", filename)
        if match:
            return int(match.group(1))
        return 0

    chapter_files.sort(key=chap_sort_key)
    appendix_files.sort()

    # Combined list for processing
    all_files = [(tex, chapters_dir) for tex in chapter_files] + [(tex, appendices_dir) for tex in appendix_files]

    for tex_filename, src_dir in all_files:
        print(f"\nProcessing {tex_filename}...")
        
        # Determine base name for directory and files
        if "comparison" in tex_filename:
            chapter_id = "comparison"
            chapter_name = "chapter-sora2-vs-veo3-comparison"
        elif "chapter" in tex_filename:
            match = re.search(r"chapter(\d+)", tex_filename)
            if match:
                chapter_id = match.group(0) # e.g. chapter01
                chapter_name = chapter_id
            else:
                continue
        elif "appendix" in tex_filename:
            chapter_id = tex_filename.replace(".tex", "")
            chapter_name = chapter_id
        else:
            continue

        chapter_output_dir = os.path.join(output_root, chapter_id)
        if os.path.exists(chapter_output_dir):
            shutil.rmtree(chapter_output_dir)
        os.makedirs(chapter_output_dir)

        # Read content and find images
        tex_path = os.path.join(src_dir, tex_filename)
        with open(tex_path, 'r', encoding='utf-8') as f:
            content = f.read()

        # Find images: \includegraphics[...]{images/FigX-Y.png} or \includegraphics{FigX-Y.png}
        image_refs = re.findall(r'\\includegraphics(?:\[.*?\])?\{(?:images/)?(.*?)\}', content)
        
        # Modify content to remove images/ prefix
        modified_content = content.replace("images/", "")
        
        # Save modified tex to the chapter directory
        target_tex_path = os.path.join(chapter_output_dir, f"{chapter_name}.tex")
        with open(target_tex_path, 'w', encoding='utf-8') as f:
            f.write(modified_content)

        # Copy images
        for img in image_refs:
            # Handle potential missing extension
            img_filename = img if "." in img else img + ".png"
            src_img = os.path.join(images_dir, img_filename)
            if os.path.exists(src_img):
                shutil.copy(src_img, chapter_output_dir)
                print(f"  Copied image: {img_filename}")
            else:
                print(f"  Warning: Image not found: {src_img}")

        # Copy build script as build.sh
        shutil.copy(build_script_src, os.path.join(chapter_output_dir, "build.sh"))
        os.chmod(os.path.join(chapter_output_dir, "build.sh"), 0o755)

        # Copy README.md
        shutil.copy(readme_src, os.path.join(chapter_output_dir, "README.md"))

        # Compile PDF
        print(f"  Compiling PDF for {chapter_id}...")
        try:
            # We run the build.sh inside the directory
            result = subprocess.run(["./build.sh"], cwd=chapter_output_dir, capture_output=True, text=True)
            if result.returncode != 0:
                print(f"  Error compiling PDF for {chapter_id}:")
                # print(result.stdout)
                # print(result.stderr)
            else:
                print(f"  PDF compiled successfully.")
        except Exception as e:
            print(f"  Exception during compilation: {e}")

        # Create zip
        zip_filename = f"{chapter_id}.zip"
        zip_path = os.path.join(output_root, zip_filename)
        
        with zipfile.ZipFile(zip_path, 'w', zipfile.ZIP_DEFLATED) as zipf:
            for root, dirs, files in os.walk(chapter_output_dir):
                for file in files:
                    if file.endswith((".aux", ".log", ".out", ".toc", ".idx", ".ind", ".ilg")):
                        continue
                    abs_path = os.path.join(root, file)
                    rel_path = os.path.relpath(abs_path, chapter_output_dir)
                    zipf.write(abs_path, rel_path)
        
        print(f"  Created zip: {zip_filename}")

        # Clean up directory to save space (keep only zip and pdf in the root if needed)
        pdf_path = os.path.join(chapter_output_dir, f"{chapter_name}.pdf")
        if os.path.exists(pdf_path):
            shutil.move(pdf_path, os.path.join(output_root, f"{chapter_name}.pdf"))
        else:
            print(f"  Warning: PDF not found after compilation: {pdf_path}")

    print("\nAll chapters processed!")

if __name__ == "__main__":
    repackage_chapters()
