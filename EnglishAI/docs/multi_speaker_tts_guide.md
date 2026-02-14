# 多人对话 TTS 使用指南

Edge TTS 支持多角色对话，每个角色自动分配不同音色，同一对话中保持一致。

## 🎭 功能特性

1. **自动音色分配** - 新角色自动分配不同音色
2. **一致性保证** - 同一角色在对话中始终使用相同音色
3. **6种音色池** - 支持最多6个角色同时对话
4. **手动控制** - 可手动指定角色音色

---

## 📝 使用方法

### 1. 基础用法（自动分配音色）

```python
from models import model_manager

# 开始新对话前，重置音色映射
model_manager.reset_speaker_voices()

# 不同角色说话，自动分配不同音色
audio1 = model_manager.text_to_speech("Hello, I'm the teacher.", speaker="teacher")
audio2 = model_manager.text_to_speech("Nice to meet you!", speaker="student")
audio3 = model_manager.text_to_speech("Let's begin our lesson.", speaker="teacher")

# teacher 和 student 会自动分配不同音色
# 同一角色（如两次 teacher）使用相同音色
```

### 2. 多人对话示例

```python
# A-B 对话
model_manager.reset_speaker_voices()

dialogue = [
    ("A", "Hi, how are you today?"),
    ("B", "I'm doing great, thanks!"),
    ("A", "That's wonderful to hear."),
    ("B", "How about you?"),
]

for speaker, text in dialogue:
    audio_path = model_manager.text_to_speech(text, speaker=speaker)
    print(f"{speaker}: {audio_path}")
```

### 3. 手动指定音色

```python
# 为特定角色指定音色
model_manager.reset_speaker_voices()

# 手动设置
model_manager.set_speaker_voice("teacher", "en-US-AriaNeural")  # 女老师
model_manager.set_speaker_voice("student", "en-US-EricNeural")  # 男学生

# 生成对话
audio1 = model_manager.text_to_speech("Good morning, class!", speaker="teacher")
audio2 = model_manager.text_to_speech("Good morning, teacher!", speaker="student")
```

---

## 🎵 可用音色

| 音色 | 性别 | 特点 | 适合角色 |
|------|------|------|----------|
| `en-US-AriaNeural` | 女 | 清晰友好 | 老师、主持人 |
| `en-US-GuyNeural` | 男 | 专业稳重 | 老师、专家 |
| `en-US-JennyNeural` | 女 | 温暖亲切 | 学生、朋友 |
| `en-US-EricNeural` | 男 | 年轻活力 | 学生、年轻人 |
| `en-US-MichelleNeural` | 女 | 成熟优雅 | 专业人士 |
| `en-US-RogerNeural` | 男 | 沉稳有力 | 领导、权威 |

---

## 💡 最佳实践

### 对话场景设计

```python
# 场景：师生对话
model_manager.reset_speaker_voices()
model_manager.set_speaker_voice("teacher", "en-US-AriaNeural")   # 女老师
model_manager.set_speaker_voice("student_1", "en-US-EricNeural") # 男学生1
model_manager.set_speaker_voice("student_2", "en-US-JennyNeural") # 女学生2

conversation = [
    ("teacher", "Today we'll learn about the present perfect tense."),
    ("student_1", "Could you give us an example?"),
    ("teacher", "Sure! I have lived here for 5 years."),
    ("student_2", "I have studied English since 2020."),
    ("teacher", "Excellent! That's exactly right."),
]

for speaker, text in conversation:
    audio = model_manager.text_to_speech(text, speaker=speaker)
```

### 场景：朋友对话

```python
# A和B是两个朋友，自动分配音色
model_manager.reset_speaker_voices()

# 第一次对话 - 自动分配
audio_a1 = model_manager.text_to_speech(
    "Did you watch the game last night?",
    speaker="A"
)  # 自动分配音色1

audio_b1 = model_manager.text_to_speech(
    "Yes! It was amazing!",
    speaker="B"
)  # 自动分配音色2（不同于A）

# 后续对话 - 保持一致
audio_a2 = model_manager.text_to_speech(
    "I know, right?",
    speaker="A"
)  # 使用与 audio_a1 相同的音色

audio_b2 = model_manager.text_to_speech(
    "The best game this season!",
    speaker="B"
)  # 使用与 audio_b1 相同的音色
```

---

## 🔧 在 Flask 路由中使用

```python
from flask import session
from models import model_manager

@app.route('/listening', methods=['GET', 'POST'])
def listening():
    # 检查是否是新练习（重置音色）
    if request.method == 'GET' or 'new_exercise' in request.args:
        model_manager.reset_speaker_voices()

    # 生成对话
    dialogue = [
        {
            'speaker': 'A',
            'text': 'Where are you from?',
            'audio': model_manager.text_to_speech('Where are you from?', speaker='A')
        },
        {
            'speaker': 'B',
            'text': "I'm from New York.",
            'audio': model_manager.text_to_speech("I'm from New York.", speaker='B')
        },
    ]

    return render_template('listening.html', dialogue=dialogue)
```

---

## ⚙️ API 参考

### `text_to_speech(text, language='en', speaker=None)`

生成语音文件。

**参数：**
- `text` (str): 要合成的文本
- `language` (str): 语言代码（默认 'en'）
- `speaker` (str|None): 说话人标识（如 "A", "B", "teacher"）

**返回：**
- `str`: 音频文件相对路径（如 "audio/xxx.mp3"）

### `reset_speaker_voices()`

重置所有角色的音色分配。在开始新对话时调用。

### `set_speaker_voice(speaker, voice)`

手动为角色指定音色。

**参数：**
- `speaker` (str): 角色标识
- `voice` (str): 音色名称（必须在可用列表中）

---

## 🎯 实战示例：生成听力练习

```python
def generate_listening_exercise():
    """生成双人对话听力练习"""

    # 1. 重置音色（新练习）
    model_manager.reset_speaker_voices()

    # 2. 定义对话
    conversation = [
        ("John", "Hey Sarah, have you finished the homework?"),
        ("Sarah", "Not yet. I'm having trouble with question 5."),
        ("John", "Would you like me to explain it?"),
        ("Sarah", "That would be great! Thanks!"),
    ]

    # 3. 生成音频
    exercise = []
    for speaker, text in conversation:
        audio_path = model_manager.text_to_speech(text, speaker=speaker)
        exercise.append({
            'speaker': speaker,
            'text': text,
            'audio': audio_path
        })

    return exercise

# 使用
exercise_data = generate_listening_exercise()
# John 和 Sarah 会自动分配不同音色，整个对话中保持一致
```

---

## 📚 注意事项

1. **新对话前重置** - 每次开始新对话前调用 `reset_speaker_voices()`
2. **最多6角色** - 音色池有6种，超过会循环使用
3. **角色命名** - 使用有意义的名称（如 "teacher", "A", "John"）
4. **Session管理** - 在Flask中可结合session管理音色状态

---

## 🔍 调试技巧

查看当前音色分配：
```python
print(model_manager.speaker_voices)
# 输出: {'A': 'en-US-AriaNeural', 'B': 'en-US-GuyNeural'}
```

查看可用音色列表：
```python
print(model_manager.available_voices)
```
