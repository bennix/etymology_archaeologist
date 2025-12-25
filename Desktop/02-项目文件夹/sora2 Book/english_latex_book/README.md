# The Handbook of Sora 2 Prompting

LaTeX source files for the book "The Handbook of Sora 2 Prompting".

---

## English Guide

### Directory Structure

```
.
├── main.tex              # Main document (compile this)
├── apress.cls            # Document class file
├── references.bib        # Bibliography database
├── build.sh              # Build script (recommended)
├── chapters/             # Chapter source files
│   ├── chapter01.tex     # Chapter 1: Introduction
│   ├── chapter02.tex     # Chapter 2: Getting Started
│   ├── chapter03.tex     # Chapter 3: Core Prompting
│   ├── chapter04.tex     # Chapter 4: Advanced Techniques
│   ├── chapter05.tex     # Chapter 5: Time Travel Selfie
│   ├── chapter06.tex     # Chapter 6: Visual Storytelling
│   ├── chapter07.tex     # Chapter 7: Cinematic Techniques
│   ├── chapter08.tex     # Chapter 8: Commercial Applications
│   ├── chapter09.tex     # Chapter 9: Emotional Expression
│   └── chapter10.tex     # Chapter 10: Future Directions
└── images/               # All figure images (PNG format)
    ├── Fig1-1.png
    ├── Fig1-2.png
    └── ...
```

### Requirements

To compile this book, you need:

- **TeX Distribution**: TeX Live 2020+ or MiKTeX 2.9+
- **Required Packages**:
  - `graphicx`, `float`, `hyperref`
  - `tcolorbox` with `skins` and `breakable` libraries
  - `geometry`, `fancyhdr`, `titlesec`
  - `makeidx` (for index generation)
  - `natbib` (for bibliography)

### Quick Build (Recommended)

Use the provided build script:

```bash
# Make the script executable (first time only)
chmod +x build.sh

# Run the build
./build.sh
```

This will:
1. Clean auxiliary files
2. Run pdflatex (first pass)
3. Process bibliography with bibtex
4. Generate index with makeindex
5. Run pdflatex (second and third pass)
6. Output: `main.pdf`

### Manual Build

If you prefer to build manually:

```bash
# Step 1: First LaTeX pass
pdflatex main.tex

# Step 2: Generate bibliography
bibtex main

# Step 3: Generate index
makeindex main.idx

# Step 4: Second LaTeX pass (incorporate references)
pdflatex main.tex

# Step 5: Third LaTeX pass (finalize cross-references)
pdflatex main.tex
```

### Building Individual Chapters

To compile a single chapter, create a wrapper file:

```latex
\documentclass[11pt,letterpaper]{book}
\usepackage[utf8]{inputenc}
\usepackage[T1]{fontenc}
\usepackage{graphicx}
\graphicspath{{images/}}
\usepackage{float}
\usepackage{hyperref}
\usepackage{tcolorbox}
\tcbuselibrary{skins,breakable}

% Copy box definitions from main.tex...

\begin{document}
\input{chapters/chapter01.tex}
\end{document}
```

### Troubleshooting

#### Missing Packages
If you get "File not found" errors, install missing packages:
- TeX Live: `tlmgr install <package-name>`
- MiKTeX: Use MiKTeX Console to install packages

#### Index Not Appearing
Make sure to run `makeindex main.idx` after the first pdflatex pass.

#### Bibliography Issues
Ensure `references.bib` is in the same directory and run `bibtex main`.

---

## 中文指南

### 目录结构

```
.
├── main.tex              # 主文档（编译此文件）
├── apress.cls            # 文档类文件
├── references.bib        # 参考文献数据库
├── build.sh              # 编译脚本（推荐使用）
├── chapters/             # 章节源文件
│   ├── chapter01.tex     # 第1章：简介
│   ├── chapter02.tex     # 第2章：入门指南
│   ├── chapter03.tex     # 第3章：核心提示词技术
│   ├── chapter04.tex     # 第4章：高级技巧
│   ├── chapter05.tex     # 第5章：时光旅行自拍
│   ├── chapter06.tex     # 第6章：视觉叙事
│   ├── chapter07.tex     # 第7章：电影技法
│   ├── chapter08.tex     # 第8章：商业应用
│   ├── chapter09.tex     # 第9章：情感表达
│   └── chapter10.tex     # 第10章：未来展望
└── images/               # 所有图片资源（PNG格式）
    ├── Fig1-1.png
    ├── Fig1-2.png
    └── ...
```

### 系统要求

编译本书需要：

- **TeX 发行版**：TeX Live 2020+ 或 MiKTeX 2.9+
- **必需的宏包**：
  - `graphicx`, `float`, `hyperref`
  - `tcolorbox`（含 `skins` 和 `breakable` 库）
  - `geometry`, `fancyhdr`, `titlesec`
  - `makeidx`（用于生成索引）
  - `natbib`（用于参考文献）

### 快速编译（推荐）

使用提供的编译脚本：

```bash
# 首次使用需要添加执行权限
chmod +x build.sh

# 运行编译
./build.sh
```

脚本会自动执行：
1. 清理辅助文件
2. 第一次 pdflatex 编译
3. 使用 bibtex 处理参考文献
4. 使用 makeindex 生成索引
5. 第二次和第三次 pdflatex 编译
6. 输出：`main.pdf`

### 手动编译

如果您想手动编译：

```bash
# 第1步：第一次 LaTeX 编译
pdflatex main.tex

# 第2步：生成参考文献
bibtex main

# 第3步：生成索引
makeindex main.idx

# 第4步：第二次 LaTeX 编译（处理引用）
pdflatex main.tex

# 第5步：第三次 LaTeX 编译（完成交叉引用）
pdflatex main.tex
```

### 单独编译章节

如需单独编译某一章节，创建一个包装文件：

```latex
\documentclass[11pt,letterpaper]{book}
\usepackage[utf8]{inputenc}
\usepackage[T1]{fontenc}
\usepackage{graphicx}
\graphicspath{{images/}}
\usepackage{float}
\usepackage{hyperref}
\usepackage{tcolorbox}
\tcbuselibrary{skins,breakable}

% 从 main.tex 复制颜色框定义...

\begin{document}
\input{chapters/chapter01.tex}
\end{document}
```

### 常见问题

#### 缺少宏包
如果出现"File not found"错误，请安装缺少的宏包：
- TeX Live：`tlmgr install <宏包名>`
- MiKTeX：使用 MiKTeX Console 安装宏包

#### 索引未显示
请确保在第一次 pdflatex 编译后运行 `makeindex main.idx`。

#### 参考文献问题
确保 `references.bib` 在同一目录下，并运行 `bibtex main`。

---

## License / 版权声明

© 2024. All rights reserved. / 保留所有权利。

