# 🚀 快速启动指南

## 首次使用

### 1. 一键安装
```bash
chmod +x setup.sh
./setup.sh
```

这会自动完成：
- ✅ 检查 Python 版本
- ✅ 创建虚拟环境
- ✅ 安装所有依赖（Flask, PyTorch, Chatterbox, Whisper 等）
- ✅ 创建必要目录
- ✅ 测试模块导入

### 2. 配置 API 密钥
编辑 `config.py`，确认 zenmux.ai 的 API 密钥已填写：
```python
ZENMUX_API_KEY = "sk-ss-v1-your-key-here"  # 已配置
```

### 3. 一键启动
```bash
./start.sh
```

访问：**http://127.0.0.1:5000**

---

## 日常使用

### 前台启动（推荐）
```bash
./start.sh
```
- 可以看到实时日志
- 按 `Ctrl+C` 停止

### 后台启动
```bash
./start-background.sh
```
- 在后台运行，不占用终端
- 日志保存在 `logs/` 目录

### 停止后台应用
```bash
./stop.sh
```

### 查看后台日志
```bash
tail -f logs/app_*.log  # 查看最新日志
```

---

## 脚本说明

| 脚本 | 用途 | 使用场景 |
|------|------|----------|
| `setup.sh` | 首次安装 | 第一次使用或重装依赖 |
| `start.sh` | 前台启动 | 日常使用、调试 |
| `start-background.sh` | 后台启动 | 长时间运行、演示 |
| `stop.sh` | 停止应用 | 停止后台运行的应用 |

---

## 故障排除

### 问题 1: Permission denied
```bash
chmod +x *.sh  # 给所有脚本添加执行权限
```

### 问题 2: Python 版本太低
安装 Python 3.11+：https://www.python.org/downloads/

### 问题 3: 依赖安装失败
```bash
# 手动激活虚拟环境并安装
source venv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt
```

### 问题 4: 端口已被占用
```bash
# 查看 5000 端口占用
lsof -i :5000

# 停止占用进程（替换 <PID> 为实际进程 ID）
kill <PID>
```

### 问题 5: 模型加载失败
检查日志输出，常见原因：
- MPS 不可用 → 自动降级到 CPU（速度较慢）
- Chatterbox 未安装 → `pip install chatterbox-tts`
- 内存不足 → 将 Whisper 改为 `tiny` 模型（编辑 config.py）

---

## 更新依赖

```bash
source venv/bin/activate
pip install --upgrade -r requirements.txt
```

---

## 完全重装

```bash
# 1. 删除虚拟环境
rm -rf venv

# 2. 重新安装
./setup.sh
```

---

## 性能提示

### M3 Max 优化
- ✅ 自动使用 MPS 加速（比 CPU 快 5-10 倍）
- ✅ 首次启动约 30-60 秒（加载模型）
- ✅ 后续请求响应快（<2 秒）

### 内存占用
- Chatterbox Turbo: ~1.5 GB
- Whisper base: ~1 GB
- Flask + Agents: ~1 GB
- **总计**: 约 3.5-4 GB

### 加速启动
如果只需要某些功能，可以注释掉不需要的模型加载（编辑 `models.py`）

---

有问题？查看完整文档：[README.md](README.md)
