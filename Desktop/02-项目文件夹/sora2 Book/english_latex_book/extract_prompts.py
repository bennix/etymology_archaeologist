import os
import re
import glob

def clean_latex(text):
    """
    Removes common LaTeX commands from the text.
    """
    # Remove \index{...}
    text = re.sub(r'\\index\{[^}]+\}', '', text)
    # Remove \label{...}
    text = re.sub(r'\\label\{[^}]+\}', '', text)
    # Replace \textbf{...} with **...**
    text = re.sub(r'\\textbf\{([^}]+)\}', r'**\1**', text)
    # Replace \textit{...} with *...*
    text = re.sub(r'\\textit\{([^}]+)\}', r'*\1*', text)
    # Replace \citep{...} or \cite{...} with nothing (or keep if desired, but usually distraction in prompts)
    text = re.sub(r'\\cite[p]?\{[^}]+\}', '', text)
    
    # Remove environment commands if they snuck in
    text = text.replace(r'\begin{enumerate}', '').replace(r'\end{enumerate}', '')
    text = text.replace(r'\begin{itemize}', '').replace(r'\end{itemize}', '')
    text = text.replace(r'\item', '- ')
    
    # Simple replacement for common chars
    text = text.replace('``', '"').replace("''", '"')
    
    # Remove extra whitespace
    lines = [line.strip() for line in text.split('\n')]
    text = '\n'.join(line for line in lines if line)
    
    return text.strip()

def extract_prompts_from_chapter(chapter_path, output_dir):
    """
    Extracts content within \begin{Prompt} ... \end{Prompt} from a tex file.
    """
    with open(chapter_path, 'r', encoding='utf-8') as f:
        content = f.read()

    # Regex to find Prompt blocks. DOTALL is needed to match across newlines.
    # We use non-greedy matching .*?
    pattern = re.compile(r'\\begin\{Prompt\}(.*?)\\end\{Prompt\}', re.DOTALL)
    matches = pattern.findall(content)

    if not matches:
        return 0

    chapter_name = os.path.splitext(os.path.basename(chapter_path))[0]
    chapter_out_dir = os.path.join(output_dir, chapter_name)
    os.makedirs(chapter_out_dir, exist_ok=True)
    
    output_file = os.path.join(chapter_out_dir, 'prompts.md')
    
    with open(output_file, 'w', encoding='utf-8') as f:
        f.write(f"# Prompts from {chapter_name}\n\n")
        for i, raw_text in enumerate(matches, 1):
            cleaned_text = clean_latex(raw_text)
            f.write(f"## Prompt {i}\n\n")
            f.write(cleaned_text)
            f.write("\n\n---\n\n")
            
    return len(matches)

def main():
    base_dir = '.'  # Use current directory
    chapters_dir = os.path.join(base_dir, 'chapters')
    output_dir = os.path.join(base_dir, 'extracted_prompts')
    
    print(f"Searching for chapters in: {os.path.abspath(chapters_dir)}", flush=True)
    
    chapter_files = sorted(glob.glob(os.path.join(chapters_dir, 'chapter*.tex')))
    
    total_prompts = 0
    if not chapter_files:
        print("No chapter files found matching 'chapter*.tex'", flush=True)

    for chapter_file in chapter_files:
        count = extract_prompts_from_chapter(chapter_file, output_dir)
        if count > 0:
            print(f"Extracted {count} prompts from {os.path.basename(chapter_file)}", flush=True)
            total_prompts += count
        else:
            print(f"No prompts found in {os.path.basename(chapter_file)}", flush=True)
            
    print(f"\nTotal extraction complete. Found {total_prompts} prompts in total.", flush=True)
    print(f"Results saved to: {output_dir}")

if __name__ == "__main__":
    main()
