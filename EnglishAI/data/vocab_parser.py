"""
高考词汇解析工具
解析 word3500 项目的 3500.txt 文件为结构化 JSON
"""
import re
import json
import os

def parse_word3500(file_path):
    """
    解析高考词汇文件

    格式: word [phonetic] pos. definition
    示例: run [rʌn] v. 跑步；经营；运转

    Returns:
        dict: {word: {phonetic, pos, meanings, is_polysemous}}
    """
    vocab = {}
    polysemous_count = 0

    if not os.path.exists(file_path):
        print(f"❌ 词汇文件不存在: {file_path}")
        return vocab

    with open(file_path, 'r', encoding='utf-8') as f:
        for line_num, line in enumerate(f, 1):
            line = line.strip()
            if not line:
                continue

            # 正则匹配: word [phonetic] pos. definition
            # 支持多个单词组成的短语，如 "bus stop"
            match = re.match(r'(.+?)\s+\[(.+?)\]\s+(\w+\.)\s+(.+)', line)

            if match:
                word, phonetic, pos, definition = match.groups()
                word = word.strip()

                # 分号分隔表示多义项
                meanings = [d.strip() for d in definition.split('；') if d.strip()]

                # 如果只有一个意思但包含分号，可能是其他分隔符
                if len(meanings) == 1 and ';' in definition:
                    meanings = [d.strip() for d in definition.split(';') if d.strip()]

                is_polysemous = len(meanings) > 1
                if is_polysemous:
                    polysemous_count += 1

                vocab[word] = {
                    'phonetic': phonetic,
                    'pos': pos,
                    'meanings': meanings,
                    'is_polysemous': is_polysemous,
                    'meaning_count': len(meanings)
                }
            else:
                # 处理特殊格式或跳过
                print(f"⚠️  行 {line_num} 格式不匹配: {line[:50]}...")

    print(f"✓ 解析完成: {len(vocab)} 个词汇")
    print(f"✓ 多义词数量: {polysemous_count}")

    return vocab

def save_vocab_json(vocab, output_path):
    """保存为 JSON 文件"""
    os.makedirs(os.path.dirname(output_path), exist_ok=True)

    with open(output_path, 'w', encoding='utf-8') as f:
        json.dump(vocab, f, ensure_ascii=False, indent=2)

    print(f"✓ 词汇库已保存: {output_path}")

def get_polysemous_words(vocab_dict, min_meanings=2):
    """获取多义词列表"""
    return {
        word: data
        for word, data in vocab_dict.items()
        if data.get('meaning_count', 0) >= min_meanings
    }

if __name__ == '__main__':
    # 测试解析
    from config import Config

    vocab = parse_word3500(Config.VOCAB_FILE)
    save_vocab_json(vocab, Config.VOCAB_JSON)

    # 显示多义词示例
    polysemous = get_polysemous_words(vocab)
    print(f"\n多义词示例 (前10个):")
    for i, (word, data) in enumerate(list(polysemous.items())[:10], 1):
        print(f"{i}. {word}: {', '.join(data['meanings'])}")
