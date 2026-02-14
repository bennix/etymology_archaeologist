# OpenAI TTS 配置指南

本应用使用 OpenAI TTS API 进行文本转语音。

## 步骤 1: 获取 OpenAI API Key

1. 访问 [OpenAI API Keys](https://platform.openai.com/api-keys)
2. 登录您的 OpenAI 账号（如没有账号需先注册）
3. 点击 "Create new secret key"
4. 复制生成的 API Key（格式：`sk-...`）

## 步骤 2: 配置 API Key

### 方法 1: 环境变量（推荐）

```bash
export OPENAI_API_KEY="sk-your-api-key-here"
```

或者在 `.env` 文件中添加：
```
OPENAI_API_KEY=sk-your-api-key-here
```

### 方法 2: 直接修改配置文件

编辑 `config.py`，找到：
```python
OPENAI_API_KEY = os.environ.get('OPENAI_API_KEY') or "your-openai-api-key-here"
```

替换为：
```python
OPENAI_API_KEY = "sk-your-actual-api-key-here"
```

## 步骤 3: 重启应用

```bash
./start.sh
```

## 💰 费用说明

- **TTS-1-HD** (高质量): ~$0.030 / 1,000 字符
- **TTS-1** (标准质量): ~$0.015 / 1,000 字符

中考英语练习平均每次生成约 100-200 字符，费用约 **$0.002-0.006** / 次。

## 🎵 音色选择

在 `models.py` 中可修改：
```python
self.tts_voice = "alloy"  # 可选: alloy, echo, fable, onyx, nova, shimmer
```

- **alloy**: 中性，清晰
- **echo**: 男性，专业
- **fable**: 英式，优雅
- **onyx**: 深沉，权威
- **nova**: 女性，友好
- **shimmer**: 温暖，柔和

## ⚠️ 注意事项

1. **保护 API Key**: 不要将 API Key 提交到 Git
2. **监控用量**: 在 [OpenAI Dashboard](https://platform.openai.com/usage) 查看用量
3. **设置限额**: 建议在 OpenAI 账户设置月度限额

## 🔧 故障排除

### 错误: "OpenAI TTS 初始化失败"
- 检查 API Key 是否正确配置
- 确认 OpenAI 账户有余额

### 错误: "Rate limit exceeded"
- OpenAI 有 API 调用频率限制
- 等待几秒后重试
- 升级到付费计划可提高限额

## 📚 更多信息

- [OpenAI TTS 文档](https://platform.openai.com/docs/guides/text-to-speech)
- [定价详情](https://openai.com/pricing)
