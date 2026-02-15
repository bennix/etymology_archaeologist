# 对话格式自动识别示例

## 📝 功能说明

系统会自动：
1. **识别说话人标记**（如 "Li Ming:", "Mary:"）
2. **移除标记**（TTS 只读对话内容，不读名字）
3. **性别检测**（根据名字自动判断性别）
4. **音色分配**（男生用男声，女生用女声）
5. **一致性保证**（同一人物始终用相同音色）

---

## ✅ 支持的格式

### 格式 1: 英文冒号
```
Li Ming: How are you today?
Mary: I'm fine, thank you!
```

### 格式 2: 中文冒号
```
李明：你好吗？
玛丽：我很好，谢谢！
```

### 格式 3: 角色标记
```
Teacher: Good morning, class!
Student: Good morning, teacher!
```

---

## 🎯 使用示例

### 示例 1: 自动识别（推荐）

```python
from models import model_manager

# 重置对话
model_manager.reset_speaker_voices()

# 直接传入带标记的文本，系统自动处理
dialogue_texts = [
    "Li Ming: How are you?",           # 自动识别为 Li Ming（男声）
    "Mary: I'm fine, thanks!",         # 自动识别为 Mary（女声）
    "Li Ming: That's great to hear.",  # 使用与第一次相同的男声
]

for text in dialogue_texts:
    audio = model_manager.text_to_speech(text)
    # Li Ming: 不会被读出，只读 "How are you?"
    # 自动分配：Li Ming → 男声，Mary → 女声
```

**输出：**
```
🎵 正在合成音频 (Li Ming): How are you?...
   → 分配音色: Li Ming 👨 → en-US-GuyNeural
🎵 正在合成音频 (Mary): I'm fine, thanks!...
   → 分配音色: Mary 👩 → en-US-AriaNeural
🎵 正在合成音频 (Li Ming): That's great to hear....
   (使用已分配的 en-US-GuyNeural)
```

### 示例 2: 手动指定说话人

```python
# 如果文本没有标记，可以手动指定
model_manager.reset_speaker_voices()

audio1 = model_manager.text_to_speech(
    "How are you?",
    speaker="Li Ming"  # 手动指定
)

audio2 = model_manager.text_to_speech(
    "I'm fine!",
    speaker="Mary"
)
```

### 示例 3: 混合使用

```python
# 可以混合自动和手动
model_manager.reset_speaker_voices()

# 自动识别
audio1 = model_manager.text_to_speech("John: Hello!")

# 手动指定（覆盖自动识别）
audio2 = model_manager.text_to_speech(
    "Sarah: Hi there!",
    speaker="Sarah",
    auto_detect_speaker=False  # 关闭自动检测
)
```

---

## 👥 性别自动识别

### 已预设的名字（自动识别性别）

**男生名字：**
- 中文：Li Ming, Wang Wei, Zhang Hua, Liu Yang, Chen Jie, Zhao Lei, Li Lei
- 英文：John, Mike, Tom, Jack, Bob, Peter, David, James

**女生名字：**
- 中文：Han Meimei
- 英文：Lucy, Lily, Mary, Kate, Sarah, Emma, Anna, Lisa, Jane, Emily

**角色关键词：**
- 男性：Teacher(部分), Boy, Man, Father, Brother, Son, Mr, King, Prince
- 女性：Teacher(部分), Girl, Woman, Mother, Sister, Daughter, Ms/Mrs/Miss, Queen, Princess

### 添加自定义名字

```python
# 在 models.py 中添加
model_manager.name_gender_map['xiaoming'] = 'male'
model_manager.name_gender_map['xiaohong'] = 'female'
```

---

## 🎵 音色分配规则

### 规则 1: 性别已知
- **男生** → 从男声池分配：GuyNeural, EricNeural, RogerNeural
- **女生** → 从女声池分配：AriaNeural, JennyNeural, MichelleNeural

### 规则 2: 性别未知
- 交替分配男女声（A女, B男, C女, D男...）

### 规则 3: 一致性
- 同一角色在整个对话中始终使用相同音色

---

## 💡 实战：生成听力材料

```python
def create_listening_exercise():
    """创建听力练习"""

    # 对话内容（直接使用带标记的格式）
    dialogue_script = [
        "Li Ming: Excuse me, where is the library?",
        "Mary: Go straight and turn left.",
        "Li Ming: How far is it?",
        "Mary: About 5 minutes walk.",
        "Li Ming: Thank you so much!",
        "Mary: You're welcome!"
    ]

    # 重置音色（新练习）
    model_manager.reset_speaker_voices()

    # 生成音频
    dialogue_data = []
    for line in dialogue_script:
        audio_path = model_manager.text_to_speech(line)

        # 手动提取说话人和文本用于显示
        if ':' in line or '：' in line:
            speaker, text = line.split(':', 1) if ':' in line else line.split('：', 1)
            dialogue_data.append({
                'speaker': speaker.strip(),
                'text': text.strip(),
                'audio': audio_path
            })

    return dialogue_data

# 使用
exercise = create_listening_exercise()
# Li Ming 自动用男声，Mary 自动用女声
```

---

## 🎭 完整示例：三人对话

```python
model_manager.reset_speaker_voices()

conversation = [
    "Teacher: Good morning, everyone!",      # 👩 女老师
    "John: Good morning, teacher!",          # 👨 男学生
    "Sarah: Good morning!",                  # 👩 女学生
    "Teacher: Today we'll learn about...",   # 👩 (与第一次相同)
    "John: Excuse me, I have a question.",   # 👨 (与第二次相同)
    "Sarah: Me too!",                        # 👩 (与第三次相同)
]

for line in conversation:
    audio = model_manager.text_to_speech(line)

# 输出示例：
# Teacher 👩 → en-US-AriaNeural
# John    👨 → en-US-GuyNeural
# Sarah   👩 → en-US-JennyNeural
```

---

## 📋 API 参数说明

### `text_to_speech(text, language='en', speaker=None, auto_detect_speaker=True)`

**参数：**
- `text` (str): 要合成的文本
  - 可包含说话人标记："Name: content"
  - 标记会被自动移除，不会被读出
- `speaker` (str|None): 手动指定说话人
  - 如果提供，优先使用（覆盖自动检测）
- `auto_detect_speaker` (bool): 是否自动检测标记
  - `True`: 自动检测并提取 "Name:" 格式
  - `False`: 禁用自动检测

**返回：**
- `str`: 音频文件路径

---

## ⚙️ 调试技巧

### 查看当前音色分配
```python
print(model_manager.speaker_voices)
# 输出: {'Li Ming': 'en-US-GuyNeural', 'Mary': 'en-US-AriaNeural'}
```

### 查看性别检测结果
```python
print(model_manager._detect_speaker_gender("Li Ming"))  # 'male'
print(model_manager._detect_speaker_gender("Mary"))     # 'female'
print(model_manager._detect_speaker_gender("Teacher"))  # 'female'
```

### 手动测试解析
```python
speaker, text = model_manager._parse_speaker_label("Li Ming: Hello!")
print(f"Speaker: {speaker}")  # Li Ming
print(f"Text: {text}")        # Hello!
```

---

## 🔧 常见问题

### Q1: 名字没有被识别为正确性别？
**A:** 手动添加到性别映射：
```python
model_manager.name_gender_map['新名字'] = 'male'  # 或 'female'
```

### Q2: 不想自动识别标记？
**A:** 设置 `auto_detect_speaker=False`：
```python
audio = model_manager.text_to_speech(
    "Li Ming: Hello",
    auto_detect_speaker=False
)
# 会读出完整文本："Li Ming: Hello"
```

### Q3: 如何禁用性别自动分配？
**A:** 手动为每个角色指定音色：
```python
model_manager.set_speaker_voice("Li Ming", "en-US-AriaNeural")  # 强制女声
```

---

## 🎯 最佳实践

1. **每次新对话前重置**
   ```python
   model_manager.reset_speaker_voices()
   ```

2. **使用统一格式**
   - 推荐：`"Name: content"` 格式
   - 标记与内容之间加空格
   - 名字首字母大写（便于识别）

3. **添加常用名字到映射**
   - 在应用启动时配置常用学生名字

4. **测试性别识别**
   - 新名字第一次使用前先测试性别检测是否正确
