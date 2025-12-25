#!/usr/bin/env python3
import os
import re

def check_environments(file_path):
    """Check if LaTeX environments are properly closed"""
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Find all begin and end statements
    begin_pattern = r'\\begin\{([^}]+)\}'
    end_pattern = r'\\end\{([^}]+)\}'
    
    begins = [(m.group(1), m.start()) for m in re.finditer(begin_pattern, content)]
    ends = [(m.group(1), m.start()) for m in re.finditer(end_pattern, content)]
    
    print(f"\n=== {file_path} ===")
    print(f"Begin environments: {len(begins)}")
    print(f"End environments: {len(ends)}")
    
    # Check for unmatched environments
    env_stack = []
    all_positions = []
    
    for env, pos in begins:
        all_positions.append(('begin', env, pos))
    for env, pos in ends:
        all_positions.append(('end', env, pos))
    
    all_positions.sort(key=lambda x: x[2])
    
    unmatched = []
    for action, env, pos in all_positions:
        if action == 'begin':
            env_stack.append((env, pos))
        elif action == 'end':
            if env_stack and env_stack[-1][0] == env:
                env_stack.pop()
            else:
                unmatched.append(f"Unmatched \\end{{{env}}} at position {pos}")
    
    for env, pos in env_stack:
        unmatched.append(f"Unmatched \\begin{{{env}}} at position {pos}")
    
    if unmatched:
        print("ERRORS FOUND:")
        for error in unmatched:
            print(f"  {error}")
    else:
        print("All environments properly matched!")
    
    return len(unmatched) == 0

# Check all tex files
tex_files = []
for root, dirs, files in os.walk('.'):
    for file in files:
        if file.endswith('.tex') and not file.startswith('test'):
            tex_files.append(os.path.join(root, file))

all_good = True
for tex_file in tex_files:
    if not check_environments(tex_file):
        all_good = False

print(f"\n{'='*50}")
if all_good:
    print("ALL FILES: No environment errors found!")
else:
    print("SOME FILES: Have environment errors!")