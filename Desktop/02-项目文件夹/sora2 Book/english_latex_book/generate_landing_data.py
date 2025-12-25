import os
import re
import glob
import json
import shutil
import sys

# Ensure we're using UTF-8
sys.stdout.reconfigure(encoding='utf-8')

def clean_latex(text):
    text = re.sub(r'\\index\{[^}]+\}', '', text)
    text = re.sub(r'\\label\{[^}]+\}', '', text)
    text = re.sub(r'\\textbf\{([^}]+)\}', r'**\1**', text)
    text = re.sub(r'\\textit\{([^}]+)\}', r'*\1*', text)
    text = re.sub(r'\\cite[p]?\{[^}]+\}', '', text)
    text = text.replace(r'\begin{enumerate}', '').replace(r'\end{enumerate}', '')
    text = text.replace(r'\begin{itemize}', '').replace(r'\end{itemize}', '')
    text = text.replace(r'\item', '- ')
    text = text.replace('``', '"').replace("''", '"')
    lines = [line.strip() for line in text.split('\n')]
    text = '\n'.join(line for line in lines if line)
    return text.strip()

def extract_prompts_and_images(chapter_path):
    with open(chapter_path, 'r', encoding='utf-8') as f:
        content = f.read()

    prompt_pattern = re.compile(r'\\begin\{Prompt\}(.*?)\\end\{Prompt\}', re.DOTALL)
    
    matches = []
    for match in prompt_pattern.finditer(content):
        prompt_content = match.group(1)
        prompt_end_pos = match.end()
        search_window = content[prompt_end_pos:prompt_end_pos+1500]
        
        img_match = re.search(r'\\includegraphics.*?\{([^}]+)\}', search_window)
        image_file = None
        if img_match:
            image_file = img_match.group(1)
            image_file = os.path.basename(image_file)

        cleaned_content = clean_latex(prompt_content)
        if cleaned_content.lower().startswith("**note**") or cleaned_content.lower().startswith("**tip**"):
            continue
        if "waitlist" in cleaned_content.lower() or "invite only" in cleaned_content.lower():
             continue
        if "chrome/safari settings" in cleaned_content.lower():
             continue

        if image_file: # Only adding if image is found, per user request "all prompts with images"
            matches.append({
                "prompt": cleaned_content,
                "image": image_file,
                "chapter": os.path.basename(chapter_path).replace('.tex', '')
            })
        
    return matches

def main():
    base_dir = os.path.dirname(os.path.abspath(__file__))
    chapters_dir = os.path.join(base_dir, 'chapters')
    images_source_dir = os.path.join(base_dir, 'images')
    
    output_dir = os.path.join(base_dir, 'custom_landing')
    assets_dir = os.path.join(output_dir, 'assets')
    
    if not os.path.exists(assets_dir):
        os.makedirs(assets_dir)
    
    chapter_files = sorted(glob.glob(os.path.join(chapters_dir, 'chapter*.tex')))
    
    all_data = []
    print(f"Scanning {len(chapter_files)} chapters...", flush=True)
    
    for chapter_file in chapter_files:
        items = extract_prompts_and_images(chapter_file)
        for item in items:
            src_path = os.path.join(images_source_dir, item['image'])
            if os.path.exists(src_path):
                shutil.copy2(src_path, os.path.join(assets_dir, item['image']))
            else:
                print(f"Warning: Image {item['image']} missing", flush=True)
        
        all_data.extend(items)
        if items:
            print(f" - {os.path.basename(chapter_file)}: {len(items)} items", flush=True)

    json_path = os.path.join(output_dir, 'data.json')
    with open(json_path, 'w', encoding='utf-8') as f:
        json.dump(all_data, f, indent=2, ensure_ascii=False)
        
    print(f"Extraction complete. {len(all_data)} pairs saved to {json_path}")

if __name__ == "__main__":
    main()
