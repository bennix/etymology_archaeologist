#!/bin/bash

# 章节对应的图片
# Images defined inside the loop using case statement for Bash 3.2 compatibility

for ch in 01 02 03 04 05 06 07 08 09 10 comparison; do
    echo "=== 处理 Chapter $ch ==="
    
    # 创建章节目录
    dir="chapter_packages/chapter$ch"
    mkdir -p "$dir"
    
    # 读取章节内容
    if [ "$ch" == "comparison" ]; then
        chapter_content=$(cat "chapters/chapter-sora2-vs-veo3-comparison.tex")
    else
        chapter_content=$(cat "chapters/chapter$ch.tex")
    fi
    
    # 修改图片路径：从 images/FigX-Y 改为 ./FigX-Y
    modified_content=$(echo "$chapter_content" | sed 's|images/||g')
    
    # Calculate chapter counter for \setcounter{chapter}{N}
    # N should be desired_chapter_number - 1
    if [ "$ch" == "comparison" ]; then
        # Comparison is Chapter 11, so counter should be 10
        counter=10
    else
        # Force base 10 to avoid octal error for 08, 09
        # Subtract 1 because \chapter increments it
        counter=$((10#$ch - 1))
    fi
    
    # 读取模板并插入章节内容和计数器
    template=$(cat chapter_template.tex)
    # First replace content
    temp_content="${template/INSERT_CONTENT_HERE/$modified_content}"
    # Then replace counter
    final_content="${temp_content/INSERT_CHAPTER_COUNTER_HERE/$counter}"
    
    # 保存主 LaTeX 文件
    echo "$final_content" > "$dir/chapter$ch.tex"
    
    # Define images for this chapter
    case $ch in
        01) imgs="Fig1-1.png Fig1-2.png" ;;
        02) imgs="Fig2-1.png Fig2-2.png Fig2-3.png" ;;
        03) imgs="Fig3-1.png Fig3-2.png Fig3-3.png Fig3-4.png Fig3-5.png Fig3-6.png Fig3-7.png Fig3-8.png Fig3-9.png Fig3-10.png Fig3-11.png Fig3-12.png" ;;
        04) imgs="Fig4-1.png Fig4-2.png Fig4-3.png Fig4-4.png" ;;
        05) imgs="Fig5-1.png Fig5-2.png Fig5-3.png Fig5-4.png Fig5-5.png Fig5-6.png Fig5-7.png Fig5-8.png Fig5-9.png Fig5-10.png" ;;
        06) imgs="Fig6-1.png Fig6-2.png Fig6-3.png Fig6-4.png" ;;
        07) imgs="Fig7-1.png" ;;
        08) imgs="Fig8-1.png Fig8-2.png Fig8-3.png Fig8-4.png" ;;
        *) imgs="" ;;
    esac

    # 复制增强后的图片
    for fig in $imgs; do
        if [ -f "images/$fig" ]; then
            cp "images/$fig" "$dir/"
            echo "  复制图片: $fig"
        fi
    done
    
    # 编译 PDF
    cd "$dir"
    pdflatex -interaction=nonstopmode "chapter$ch.tex" > /dev/null 2>&1
    pdflatex -interaction=nonstopmode "chapter$ch.tex" > /dev/null 2>&1
    
    if [ -f "chapter$ch.pdf" ]; then
        echo "  PDF 编译成功: chapter$ch.pdf"
    else
        echo "  PDF 编译失败!"
    fi
    
    # 清理辅助文件
    rm -f *.aux *.log *.out *.toc *.lof *.lot
    
    cd ../..
    
    # 打包成 zip
    cd chapter_packages
    zip -r "chapter$ch.zip" "chapter$ch" > /dev/null 2>&1
    echo "  打包完成: chapter$ch.zip"
    cd ..
    
    echo ""
done

echo "=== 所有章节处理完成 ==="
ls -lh chapter_packages/*.zip
