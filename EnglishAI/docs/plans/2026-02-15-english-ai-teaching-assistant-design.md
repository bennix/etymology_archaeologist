# 中考英语教学助手 - 系统设计文档

**日期**: 2026-02-15
**作者**: AI Assistant & User
**版本**: 1.0

## 项目概述

面向中国初中三年级学生的中考英语教学助手 Web 应用，覆盖听、说、读、写四项核心技能，基于多大模型协同工作，提供个性化练习和智能批改。

## 技术栈

### 后端
- **框架**: Flask + Flask-WTF
- **Python 版本**: 3.11+
- **AI 模型集成**:
  - API: zenmux.ai (OpenAI-compatible)
  - 本地 TTS: Chatterbox Turbo (350M)
  - 本地 STT: OpenAI Whisper (base model)

### 前端
- **UI 框架**: Bootstrap 5
- **脚本**: 原生 JavaScript (ES6+)
- **音频**: HTML5 Audio API + MediaRecorder API

### 硬件环境
- **开发机器**: M3 Max (Apple Silicon)
- **加速**: Metal Performance Shaders (MPS)
- **内存需求**: 4-6GB (预加载模式)

## 系统架构

### 1. 项目结构

```
EnglishAI/
├── app.py                 # Flask 主应用
├── config.py              # API 配置和密钥
├── agents.py              # 三个 AI Agent 类
├── models.py              # Chatterbox/Whisper 管理器
├── requirements.txt
├── docs/
│   └── plans/            # 设计文档
├── data/
│   ├── vocab_parser.py   # 词汇解析工具
│   ├── 3500.txt          # 高考词汇源文件
│   └── gaokao_vocab.json # 解析后的词汇库
├── static/
│   ├── css/
│   │   └── style.css
│   ├── js/
│   │   └── main.js       # 录音/播放逻辑
│   └── audio/            # 生成的听力音频
└── templates/
    ├── base.html
    ├── index.html
    ├── listening.html
    ├── speaking.html
    ├── reading.html
    ├── writing.html
    └── history.html
```

### 2. 核心组件

#### 2.1 Agent 分工（agents.py）

**ContentGenerator** (使用 Kimi K2 Thinking Turbo)
- `generate_listening_material()` - 生成听力对话 + 问题
- `generate_reading_passage()` - 生成阅读文章 + 4-5 题
- `generate_vocabulary_exercise()` - 基于高考词汇生成练习
- **特点**: 长上下文，教学内容质量高

**Evaluator** (使用 Claude Opus 4.5)
- `evaluate_writing(essay)` - 批改作文，返回分数 + 详细反馈
- `evaluate_speaking(transcript)` - 评估流利度/语法/内容
- `check_answers(questions, answers)` - 批改混合题型
- **特点**: 推理能力强，适合主观题批改

**QuestionGenerator** (使用 MiniMax M2.1)
- `generate_multiple_choice(passage, count)` - 生成单选题
- `generate_cloze_test()` - 生成完形填空
- **特点**: 逻辑严密，结构化出题

#### 2.2 模型管理器（models.py）

**ModelManager** (单例模式)
- **初始化**: 启动时加载 Chatterbox + Whisper 到 MPS
- `text_to_speech(text)` - 合成音频，返回文件路径
- `speech_to_text(audio_file)` - 转录音频为文本
- **设备适配**: 自动检测 MPS/CPU

### 3. 数据流设计

#### 3.1 听力模块流程

```
用户访问 /listening (GET)
    ↓
ContentGenerator.generate_listening_material()
    ↓ (返回对话文本 + 问题JSON)
ModelManager.text_to_speech(dialogue)
    ↓ (保存到 static/audio/xxx.wav)
渲染模板 (传入 audio_url, questions)
    ↓
用户播放音频 → 回答问题 → 提交 (POST)
    ↓
Evaluator.check_answers()
    ↓
返回结果 + 保存分数到 session
```

#### 3.2 口语模块流程

```
用户访问 /speaking (GET)
    ↓
ContentGenerator 生成口语题目
    ↓
渲染页面 (显示题目 + 录音按钮)
    ↓
用户录音 (MediaRecorder API) → 上传 (POST)
    ↓
ModelManager.speech_to_text()
    ↓ (返回转录文本)
Evaluator.evaluate_speaking(transcript)
    ↓
返回评分 + 改进建议
```

#### 3.3 阅读模块流程

```
用户访问 /reading (GET)
    ↓
ContentGenerator.generate_reading_passage()
    ↓
QuestionGenerator.generate_multiple_choice() (3题)
    ↓
渲染页面 (文章 + 5题: 3单选 + 2主观)
    ↓
用户提交答案 (POST)
    ↓
Evaluator.check_answers()
    ↓
返回详解 + 分数
```

#### 3.4 写作模块流程

```
用户访问 /writing (GET)
    ↓
显示作文题目 (书信/议论文/记叙文)
    ↓
用户输入作文 → 提交 (POST)
    ↓
Evaluator.evaluate_writing(essay)
    ↓
返回 4 维度评分 (内容/结构/语法/词汇) + 逐段点评
```

## 4. 一词多义处理

### 4.1 词汇数据源

**来源**: [pluto0x0/word3500](https://github.com/pluto0x0/word3500)
**格式**: `单词 [音标] 词性. 中文释义1；释义2；...`
**示例**: `run [rʌn] v. 跑步；经营；运转`

### 4.2 解析策略

```python
# vocab_parser.py
def parse_word3500(file_path):
    """解析为 JSON，提取多义词"""
    for line in file:
        # 正则匹配: word [phonetic] pos. definition
        meanings = definition.split('；')  # 分号分隔
        vocab[word] = {
            'phonetic': phonetic,
            'pos': pos,
            'meanings': meanings,
            'is_polysemous': len(meanings) > 1
        }
```

### 4.3 训练策略

- **ContentGenerator**: 优先选择多义词嵌入文章
- **QuestionGenerator**: 生成上下文词义理解题
- **Prompt 设计**: 明确要求体现不同义项

示例 Prompt:
```
生成一篇短文，必须使用以下词汇并体现其特定含义：
- run (经营): 在商业场景中使用
- bank (河岸): 在自然场景中使用
```

## 5. 错误处理策略

### 5.1 API 调用失败

```python
try:
    response = requests.post(API_URL, json=payload, timeout=30)
    response.raise_for_status()
except requests.Timeout:
    return {"error": "模型响应超时，请重试"}
except requests.RequestException as e:
    return {"error": f"API调用失败: {str(e)}"}
```

### 5.2 模型加载失败

- Chatterbox/Whisper 加载失败时设为 `None`
- 前端显示降级提示："TTS 暂不可用，请查看文本"
- 自动降级到 CPU（如果 MPS 不可用）

### 5.3 前端交互错误

- 音频播放失败 → 显示对话文本备份
- 录音权限拒绝 → 提示用户授权
- 表单空提交 → Bootstrap 验证拦截

## 6. 会话管理

### 6.1 Session 结构

```python
session['scores'] = [
    {
        'type': 'listening',
        'score': 18,
        'total': 20,
        'timestamp': '2026-02-15 10:30',
        'details': {...}
    },
    # 最多保留 10 条
]
```

### 6.2 历史记录路由

`/history` 页面:
- 显示最近 10 次练习
- 按模块统计平均分
- 可选: Chart.js 可视化图表

## 7. 部署流程

### 7.1 首次启动

```bash
# 1. 创建虚拟环境
python3 -m venv venv
source venv/bin/activate

# 2. 安装依赖
pip install -r requirements.txt

# 3. 配置 config.py（填入 API Key）

# 4. 启动（预加载模式）
flask run
```

### 7.2 预期启动输出

```
📚 首次运行，正在解析高考词汇...
✓ 词汇库准备完成 (3500 words, 1247 polysemous)
🤖 正在加载 Chatterbox TTS (MPS)...
✓ Chatterbox 加载完成 (1.2s)
🎤 正在加载 Whisper base (MPS)...
✓ Whisper 加载完成 (2.8s)
🔗 测试 AI Agents 连接...
✓ ContentGenerator ready (kimi-k2-thinking-turbo)
✓ Evaluator ready (claude-opus-4.5)
✓ QuestionGenerator ready (minimax-m2.1)

✅ 所有模型就绪！访问 http://127.0.0.1:5000
总加载时间: 38.6s
内存占用: 4.2GB
```

## 8. 性能优化

### 8.1 M3 Max 特定配置

```python
# models.py
if torch.backends.mps.is_available():
    device = "mps"  # Metal Performance Shaders
else:
    device = "cpu"

# Whisper 选择 base 模型（准确度与速度平衡）
whisper.load_model("base", device=device)

# Chatterbox 使用 Turbo 版本（350M 参数）
ChatterboxTurboTTS.from_pretrained(device=device)
```

### 8.2 内存管理

- 单例模式确保模型只加载一次
- 音频文件定期清理（超过 50 个自动删除最旧的）
- Session 限制 10 条历史记录

## 9. 测试清单

启动后手动验证：

- [ ] 首页四个模块入口正常
- [ ] 听力: 音频生成 + 播放 + 批改反馈
- [ ] 口语: 录音 + 转录 + 评分
- [ ] 阅读: 文章生成 + 题目合理 + 详解
- [ ] 写作: 批改给出具体建议和分数
- [ ] `/history` 显示历史成绩
- [ ] Session 数据持久化（刷新页面不丢失）

## 10. 后续扩展方向

1. **用户系统**: Flask-Login 支持多用户
2. **错题本**: 记录错误题目，定期复习
3. **学习报告**: 导出 PDF 进度报告
4. **自定义词汇**: 支持上传个人词汇表
5. **移动端适配**: 响应式布局优化
6. **语音识别优化**: 支持发音评分（音素级别）

## 11. 关键依赖版本

```
Flask==3.0.0
Flask-WTF==1.2.1
requests==2.31.0
torch>=2.1.0  # MPS 支持
torchaudio>=2.1.0
chatterbox-tts>=1.0.0
openai-whisper>=20231117
```

## 12. 安全考虑

- API 密钥只在服务器端使用（config.py）
- 不在前端 JavaScript 暴露任何密钥
- 音频文件使用随机文件名（防止猜测）
- Session 使用 SECRET_KEY 加密
- 文件上传大小限制（音频 < 10MB）

---

**设计审核**: ✅ 通过
**准备实现**: 待用户确认
