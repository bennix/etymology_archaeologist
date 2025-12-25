
import os
import re
import json
import sys

# DEBUG: Ensure we are running
with open('debug_run.log', 'w') as f:
    f.write("Script started\n")

def get_tex_files(chapters_dir):
    files = []
    if not os.path.exists(chapters_dir):
        return []
    for f in sorted(os.listdir(chapters_dir)):
        if f.endswith('.tex'):
            files.append(os.path.join(chapters_dir, f))
    return files

def clean_prompt(text):
    text = re.sub(r'\\textbf\{([^}]+)\}', r'\1', text)
    text = re.sub(r'\\textit\{([^}]+)\}', r'\1', text)
    text = text.replace('``', '"').replace("''", '"')
    return " ".join(text.split()).strip()

def analyze_chapter(file_path):
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            content = f.read()
    except Exception as e:
        return []

    prompt_pattern = re.compile(r'\\begin\{Prompt\}(.*?)\\end\{Prompt\}', re.DOTALL)
    
    results = []
    for match in prompt_pattern.finditer(content):
        prompt_content = match.group(1)
        prompt_text = clean_prompt(prompt_content)
        end_pos = match.end()
        rest_of_text = content[end_pos:]
        
        img_match = re.search(r'\\includegraphics(?:\[.*?\])?\{([^}]+)\}', rest_of_text)
        
        if img_match:
            img_filename = img_match.group(1)
            # Remove extension if present to standardized, or check if we need to replace extension
            # Usually \includegraphics{foo} works for foo.png or foo.jpg. 
            # We will use the filename exactly as found to locate the file, or assume we create it.
            
            chapter_name = os.path.basename(file_path)
            # Determine if this prompts needs special cameo handling
            # Detecting @keywords or specific names in the prompt text
            
            cameo_type = "none"
            lower_prompt = prompt_text.lower()
            
            # Heuristic for cameo mapping
            if "chapter04" in chapter_name:
                if "@leon" in lower_prompt or "@zhiping" in lower_prompt or "self" in lower_prompt or "creator" in lower_prompt:
                    cameo_type = "author"
                elif "@sama" in lower_prompt or "altman" in lower_prompt or "@someone" in lower_prompt or "@username" in lower_prompt:
                    cameo_type = "other"
            
            results.append({
                "chapter": chapter_name,
                "prompt_text": prompt_text,
                "image_filename": img_filename,
                "cameo_type": cameo_type
            })
            
    return results

def main():
    base_dir = '/Users/nellertcai/Desktop/02-项目文件夹/sora2 Book/english_latex_book'
    chapters_dir = os.path.join(base_dir, 'chapters')
    output_file = 'prompts_data.json'
    
    all_tasks = []
    files = get_tex_files(chapters_dir)
    
    for tex_file in files:
        tasks = analyze_chapter(tex_file)
        all_tasks.extend(tasks)
        
    with open(output_file, 'w', encoding='utf-8') as f:
        json.dump(all_tasks, f, indent=2)

if __name__ == "__main__":
    main()
