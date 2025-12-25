# Chapter Package - The Handbook of Sora 2 Prompting

This package contains a single chapter from "The Handbook of Sora 2 Prompting".

---

## English Guide

### Contents

- `chapterXX.tex` - Chapter LaTeX source file
- `Fig*.png` - Figure images used in this chapter
- `build.sh` - Build script for compiling to PDF
- `README.md` - This file

### Requirements

- **TeX Distribution**: TeX Live 2020+ or MiKTeX 2.9+
- **Required Packages**: `graphicx`, `float`, `hyperref`, `tcolorbox`, `geometry`, `makeidx`

### Quick Build

```bash
# Make script executable (first time only)
chmod +x build.sh

# Run build
./build.sh
```

Output: `chapterXX.pdf`

### Manual Build

```bash
# Create standalone.tex wrapper (see build.sh for template)
pdflatex standalone.tex
pdflatex standalone.tex
mv standalone.pdf chapterXX.pdf
```

### Troubleshooting

- **Missing packages**: Install via `tlmgr install <package>` (TeX Live) or MiKTeX Console
- **Image not found**: Ensure all `Fig*.png` files are in the same directory as the .tex file

---

## 中文指南

### 包含内容

- `chapterXX.tex` - 章节 LaTeX 源文件
- `Fig*.png` - 本章使用的图片
- `build.sh` - 编译脚本
- `README.md` - 本说明文件

### 系统要求

- **TeX 发行版**：TeX Live 2020+ 或 MiKTeX 2.9+
- **必需宏包**：`graphicx`, `float`, `hyperref`, `tcolorbox`, `geometry`, `makeidx`

### 快速编译

```bash
# 首次使用需添加执行权限
chmod +x build.sh

# 运行编译
./build.sh
```

输出：`chapterXX.pdf`

### 手动编译

```bash
# 创建 standalone.tex 包装文件（参见 build.sh 中的模板）
pdflatex standalone.tex
pdflatex standalone.tex
mv standalone.pdf chapterXX.pdf
```

### 常见问题

- **缺少宏包**：使用 `tlmgr install <宏包名>`（TeX Live）或 MiKTeX Console 安装
- **找不到图片**：确保所有 `Fig*.png` 文件与 .tex 文件在同一目录

---

© 2024. All rights reserved. / 保留所有权利。

