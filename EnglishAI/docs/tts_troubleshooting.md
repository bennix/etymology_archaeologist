# TTS 对话格式问题排查指南

## 🔍 问题：仍然听到朗读者的名字

如果您在听力内容中仍然听到类似 "Li Ming:" 这样的名字被朗读出来，请按以下步骤排查：

---

## 步骤 1: 运行测试脚本

```bash
source venv/bin/activate
python test_tts.py
```

**预期输出：**
```
🧪 测试 TTS 对话格式自动识别

原文本: Li Ming: How are you today?
  → 识别说话人: Li Ming
  → 实际内容: How are you today?
  → 性别检测: male
🎵 正在合成音频 (Li Ming): How are you today?...
  → 分配音色: Li Ming 👨 → en-US-GuyNeural
  → 音频文件: audio/xxx.mp3
```

**关键检查点：**
- ✅ "实际内容" 应该是 "How are you today?"（**不包含** "Li Ming:"）
- ✅ 音频文件应该只朗读 "How are you today?"

---

## 步骤 2: 检查代码调用方式

### ❌ 错误用法（会朗读名字）

```python
# 错误 1: 禁用了自动检测
audio = model_manager.text_to_speech(
    "Li Ming: How are you?",
    auto_detect_speaker=False  # ❌ 这会导致朗读完整文本
)

# 错误 2: 手动指定了 speaker 但文本包含标记
audio = model_manager.text_to_speech(
    "Li Ming: How are you?",  # ❌ 文本中仍包含 "Li Ming:"
    speaker="Li Ming"
)
```

### ✅ 正确用法

```python
# 正确 1: 使用自动检测（推荐）
audio = model_manager.text_to_speech(
    "Li Ming: How are you?"  # ✅ 自动移除 "Li Ming:"
)

# 正确 2: 手动指定 speaker 时，文本不要包含标记
audio = model_manager.text_to_speech(
    "How are you?",  # ✅ 不包含名字
    speaker="Li Ming"
)

# 正确 3: 显式启用自动检测（默认已启用）
audio = model_manager.text_to_speech(
    "Li Ming: How are you?",
    auto_detect_speaker=True  # ✅ 明确启用
)
```

---

## 步骤 3: 检查 agents.py 中的代码

### 在 ContentGenerator 类中

查看生成对话的代码是否正确：

```python
# 检查这部分代码
def generate_listening_dialogue(self, topic):
    # AI 生成的对话格式
    dialogue = [
        {"speaker": "Li Ming", "text": "How are you?"},
        {"speaker": "Mary", "text": "I'm fine!"},
    ]

    # ❌ 错误：手动拼接了标记
    for item in dialogue:
        text_with_label = f"{item['speaker']}: {item['text']}"  # ❌
        audio = model_manager.text_to_speech(text_with_label, speaker=item['speaker'])
        # 这会导致 speaker 参数覆盖自动检测，且文本包含标记

    # ✅ 正确方式 1：只传递纯文本
    for item in dialogue:
        audio = model_manager.text_to_speech(
            item['text'],              # ✅ 纯文本
            speaker=item['speaker']    # ✅ 单独指定说话人
        )

    # ✅ 正确方式 2：传递带标记的完整文本，依赖自动检测
    for item in dialogue:
        text_with_label = f"{item['speaker']}: {item['text']}"
        audio = model_manager.text_to_speech(text_with_label)  # ✅ 自动检测
```

---

## 步骤 4: 检查 app.py 路由

### 在听力练习路由中

```python
@app.route('/listening')
def listening():
    # 重置音色
    model_manager.reset_speaker_voices()

    # 生成对话
    dialogue = generate_listening_material()
    # dialogue 格式：[{"speaker": "A", "text": "..."}, ...]

    # ❌ 错误：没有处理文本格式
    for item in dialogue:
        item['audio'] = model_manager.text_to_speech(
            f"{item['speaker']}: {item['text']}",  # 拼接了标记
            speaker=item['speaker']                # 但又指定了 speaker
        )
        # 这会导致 speaker 参数优先，auto_detect 被跳过

    # ✅ 正确方式 1：让自动检测处理
    for item in dialogue:
        full_text = f"{item['speaker']}: {item['text']}"
        item['audio'] = model_manager.text_to_speech(full_text)  # ✅

    # ✅ 正确方式 2：分开传递
    for item in dialogue:
        item['audio'] = model_manager.text_to_speech(
            item['text'],           # 纯文本
            speaker=item['speaker']  # 说话人
        )
```

---

## 步骤 5: 验证文本格式

### 检查冒号格式

```python
# ✅ 支持的格式
"Li Ming: How are you?"     # 英文冒号 + 空格
"Li Ming:How are you?"      # 英文冒号（无空格也可）
"李明： 你好吗？"           # 中文冒号 + 空格
"李明：你好吗？"            # 中文冒号

# ❌ 不支持的格式
"Li Ming - How are you?"    # 使用破折号
"Li Ming said: How are you?" # 包含其他词
"How are you? - Li Ming"    # 名字在后面
```

### 测试格式解析

```python
# 直接测试解析函数
speaker, text = model_manager._parse_speaker_label("Li Ming: How are you?")
print(f"Speaker: {speaker}")  # 应输出: Li Ming
print(f"Text: {text}")        # 应输出: How are you?
```

---

## 步骤 6: 重启应用

确保代码更改生效：

```bash
# 停止应用
按 Ctrl+C

# 重启
./start.sh
```

---

## 完整示例代码

### 示例 1: 在 agents.py 中正确使用

```python
class ContentGenerator:
    def generate_listening_dialogue(self, topic, difficulty):
        # 调用 AI 生成对话
        response = self._call_api(
            prompt=f"生成关于 {topic} 的双人对话...",
            system_prompt="以 JSON 格式返回对话..."
        )

        dialogue = response['dialogue']
        # 假设 AI 返回：
        # [
        #     {"speaker": "Li Ming", "text": "How are you?"},
        #     {"speaker": "Mary", "text": "I'm fine!"}
        # ]

        # 重置音色（新对话）
        from models import model_manager
        model_manager.reset_speaker_voices()

        # 为每句生成音频
        result = []
        for item in dialogue:
            # 方法 1: 纯文本 + speaker 参数
            audio_path = model_manager.text_to_speech(
                text=item['text'],
                speaker=item['speaker']
            )

            result.append({
                'speaker': item['speaker'],
                'text': item['text'],
                'audio': audio_path
            })

        return result
```

### 示例 2: 在 app.py 路由中正确使用

```python
@app.route('/listening', methods=['GET', 'POST'])
def listening():
    from agents import content_generator
    from models import model_manager

    if request.method == 'GET':
        # 重置音色
        model_manager.reset_speaker_voices()

        # 生成听力材料
        dialogue = content_generator.generate_listening_dialogue(
            topic="daily conversation",
            difficulty="beginner"
        )

        # dialogue 已包含 audio 字段
        return render_template('listening.html', dialogue=dialogue)
```

---

## 调试输出

如果问题仍然存在，添加调试输出：

```python
# 在生成音频前添加
print(f"DEBUG - 原始文本: {text}")
speaker, actual_text = model_manager._parse_speaker_label(text)
print(f"DEBUG - 识别说话人: {speaker}")
print(f"DEBUG - 实际内容: {actual_text}")

audio = model_manager.text_to_speech(text)
print(f"DEBUG - 音频文件: {audio}")
```

---

## 常见问题解答

### Q1: 为什么 speaker 参数会覆盖自动检测？

**A:** 这是设计行为。当您同时提供：
- 文本包含标记：`"Li Ming: How are you?"`
- speaker 参数：`speaker="Li Ming"`

系统会：
1. 优先使用 speaker 参数
2. **跳过** auto_detect（因为 speaker 不为 None）
3. 使用原始文本（包含 "Li Ming:"）

**解决方案：** 二选一
- 要么只传文本（依赖自动检测）
- 要么传纯文本 + speaker 参数

### Q2: 如何确认音频只包含对话内容？

**A:** 运行测试脚本并播放生成的音频：
```bash
python test_tts.py
# 然后播放 static/audio/ 目录下最新的 .mp3 文件
```

### Q3: 可以手动控制是否朗读名字吗？

**A:** 可以，使用 `auto_detect_speaker` 参数：

```python
# 朗读完整文本（包括名字）
audio = model_manager.text_to_speech(
    "Li Ming: How are you?",
    auto_detect_speaker=False
)

# 只朗读对话内容（移除名字）
audio = model_manager.text_to_speech(
    "Li Ming: How are you?",
    auto_detect_speaker=True  # 默认值
)
```

---

## 联系支持

如果按照以上步骤仍然无法解决，请提供：

1. **测试脚本输出**
   ```bash
   python test_tts.py > tts_test_output.txt 2>&1
   ```

2. **您的代码片段**（如何调用 text_to_speech）

3. **生成的音频文件**（以便验证）
