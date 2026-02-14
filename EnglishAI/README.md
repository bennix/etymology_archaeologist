# 中考英语教学助手 🎓

面向中国初中三年级学生的智能英语学习平台，基于多大模型协同工作，提供听、说、读、写全方位练习和 AI 智能批改。

## ✨ 主要功能

### 📻 听力练习
- AI 生成真实对话场景（日常生活、学校、旅行等）
- Chatterbox TTS 合成高质量英语音频
- 配套 3 道理解题，自动批改并给出详解

### 🎤 口语练习
- 随机生成口语话题（描述、讨论、叙述等）
- 浏览器录音 + Whisper STT 转录
- 四维度评分：流利度、语法、词汇、内容（满分 40）

### 📖 阅读理解
- 生成 200-250 词中考难度文章
- 5 道题目：3 道单选 + 2 道简答
- 基于高考 3500 词汇，特别关注一词多义

### ✍️ 写作批改
- 常见题型：书信、议论文、记叙文
- 四维度批改：内容、结构、语法、词汇（满分 20）
- 逐段点评 + 错误修正 + 改进建议

### 📊 学习追踪
- Session 自动保存最近 10 次练习成绩
- 按模块统计平均分
- 历史记录可视化

---

## 🛠️ 技术架构

### 后端
- **Flask 3.0** - Web 框架
- **PyTorch 2.1+** - 深度学习框架（MPS/CUDA/CPU 支持）
- **Chatterbox Turbo TTS** - 本地文本转语音（350M 参数）
- **OpenAI Whisper** - 本地语音识别（base 模型）

### AI 模型（通过 zenmux.ai API）
- **内容生成**: Moonshot Kimi K2 Thinking Turbo（长上下文）
- **批改评估**: Claude Opus 4.5（强推理能力）
- **题目生成**: MiniMax M2.1（逻辑严密）

### 前端
- **Bootstrap 5** - UI 框架
- **原生 JavaScript** - 交互逻辑
- **MediaRecorder API** - 录音功能
- **HTML5 Audio** - 音频播放

### 数据
- **高考词汇库**: [pluto0x0/word3500](https://github.com/pluto0x0/word3500)（3500 词）

---

## 🚀 快速开始

### 环境要求
- Python 3.11+
- macOS (M3 Max) / Linux / Windows
- 8GB+ RAM（推荐）

### 安装步骤

1. **克隆项目**
```bash
git clone <repository_url>
cd EnglishAI
```

2. **创建虚拟环境**
```bash
python3 -m venv venv
source venv/bin/activate  # Windows: venv\Scripts\activate
```

3. **安装依赖**
```bash
pip install -r requirements.txt
```

4. **配置 API 密钥**

编辑 `config.py`，填入你的 zenmux.ai API 密钥：
```python
ZENMUX_API_KEY = "sk-ss-v1-your-api-key-here"
```

5. **首次启动（自动下载词汇库并加载模型）**
```bash
flask run
```

预期启动输出：
```
📚 首次运行，正在解析高考词汇...
   ⬇️  下载 3500.txt...
   ✓ 下载完成
   🔄 解析词汇文件...
   ✓ 解析完成: 3500 个词汇
   ✓ 词汇库加载完成: 3500 词，1247 个多义词

🤖 正在加载 Chatterbox TTS (MPS)...
   ✓ Chatterbox 加载完成 (1.2s)
🎤 正在加载 Whisper base (MPS)...
   ✓ Whisper 加载完成 (2.8s)
🔗 正在初始化 AI Agents...
   ✓ ContentGenerator ready (moonshotai/kimi-k2-thinking-turbo)
   ✓ Evaluator ready (anthropic/claude-opus-4.5)
   ✓ QuestionGenerator ready (minimax/minimax-m2.1)

✅ 系统就绪！访问 http://127.0.0.1:5000
总加载时间: 38.6s
```

6. **访问应用**

打开浏览器访问：http://127.0.0.1:5000

---

## 📁 项目结构

```
EnglishAI/
├── app.py                 # Flask 主应用
├── config.py              # 配置文件（API 密钥）
├── agents.py              # AI Agent 类
├── models.py              # Chatterbox/Whisper 管理器
├── requirements.txt       # Python 依赖
├── data/
│   ├── vocab_parser.py    # 词汇解析工具
│   ├── 3500.txt           # 高考词汇源文件（自动下载）
│   └── gaokao_vocab.json  # 解析后的词汇库
├── static/
│   ├── css/style.css      # 自定义样式
│   ├── js/main.js         # 前端脚本
│   └── audio/             # 生成的音频文件
├── templates/             # Jinja2 模板
│   ├── base.html
│   ├── index.html
│   ├── listening.html
│   ├── speaking.html
│   ├── reading.html
│   ├── writing.html
│   └── history.html
└── docs/
    └── plans/             # 设计文档
```

---

## ⚙️ 配置说明

### 模型配置（config.py）

```python
# 可根据需要调整使用的模型
MODELS = {
    'content_generator': 'moonshotai/kimi-k2-thinking-turbo',  # 内容生成
    'evaluator': 'anthropic/claude-opus-4.5',                  # 批改评估
    'question_generator': 'minimax/minimax-m2.1'               # 题目生成
}

# Whisper 模型大小（影响准确度和速度）
WHISPER_MODEL_SIZE = 'base'  # 可选: tiny, base, small, medium, large
```

### 性能优化（M3 Max）

- 自动检测并使用 **MPS**（Metal Performance Shaders）加速
- 如果 MPS 不可用，自动降级到 CPU
- Whisper 使用 `base` 模型（准确度与速度平衡）

### 设备适配

```python
# models.py 会自动检测最佳设备
if torch.backends.mps.is_available():
    device = "mps"  # Apple Silicon
elif torch.cuda.is_available():
    device = "cuda"  # NVIDIA GPU
else:
    device = "cpu"
```

---

## 🧪 功能测试

启动后手动测试以下功能：

- [ ] 首页显示四个模块入口
- [ ] 听力：生成音频 → 播放 → 提交答案 → 查看批改结果
- [ ] 口语：录音 → 转录 → 四维度评分
- [ ] 阅读：生成文章 → 回答问题 → 查看详解
- [ ] 写作：提交作文 → 查看四维度批改 + 建议
- [ ] 历史：查看成绩统计和记录列表

---

## 🐛 常见问题

### 1. Chatterbox 加载失败

**问题**: `ModuleNotFoundError: No module named 'chatterbox'`

**解决**:
```bash
pip install chatterbox-tts
```

### 2. PyTorch MPS 不可用

**问题**: `MPS backend not available`

**解决**: 确保安装支持 MPS 的 PyTorch 版本：
```bash
pip install --upgrade torch torchvision torchaudio
```

### 3. Whisper 转录失败

**问题**: 音频格式不兼容

**解决**: 前端录音使用 WAV 格式，16kHz 采样率

### 4. API 调用超时

**问题**: `requests.Timeout`

**解决**:
- 检查网络连接
- 检查 zenmux.ai API 密钥是否有效
- 增加 timeout 参数（agents.py 中）

### 5. 内存不足

**问题**: 模型加载占用过多内存

**解决**:
- 将 Whisper 降级为 `tiny` 模型
- 关闭其他占用内存的应用

---

## 📊 系统状态

访问 `/status` 路由查看系统状态（调试用）：

```json
{
  "models": {
    "device": "mps",
    "chatterbox": true,
    "whisper": true,
    "audio_count": 5
  },
  "agents": {
    "content_generator": true,
    "evaluator": true,
    "question_generator": true
  },
  "vocab_loaded": true,
  "session_scores_count": 3
}
```

---

## 🔒 安全说明

- ✅ API 密钥仅在服务器端使用（config.py）
- ✅ 前端 JavaScript 不暴露任何密钥
- ✅ Session 使用 SECRET_KEY 加密
- ✅ 音频文件使用随机文件名
- ✅ 文件上传大小限制（< 10MB）

---

## 🚧 后续扩展

- [ ] 用户登录系统（Flask-Login）
- [ ] 错题本功能
- [ ] 导出学习报告（PDF）
- [ ] 支持自定义词汇表上传
- [ ] 移动端响应式优化
- [ ] 发音评分（音素级别）

---

## 📄 许可证

MIT License

---

## 🙏 致谢

- [word3500](https://github.com/pluto0x0/word3500) - 高考词汇数据
- [Chatterbox](https://github.com/resemble-ai/chatterbox) - 开源 TTS 模型
- [OpenAI Whisper](https://github.com/openai/whisper) - 语音识别模型
- [zenmux.ai](https://zenmux.ai) - AI 模型 API 服务

---

**开发者**: AI Assistant & User
**日期**: 2026-02-15
**版本**: 1.0.0
