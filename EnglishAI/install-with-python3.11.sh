#!/bin/bash
# 完整安装脚本 - 自动安装 Python 3.11 并配置环境

set -e  # 遇到错误立即退出

echo "=========================================="
echo "🎓 中考英语助手 - Python 3.11 完整安装"
echo "=========================================="
echo ""

# 1. 检查 Homebrew
echo "📌 检查 Homebrew..."
if ! command -v brew &> /dev/null; then
    echo "❌ 错误: 未找到 Homebrew"
    echo "   请先安装 Homebrew: https://brew.sh"
    exit 1
fi
echo "✅ Homebrew 已安装"

# 2. 安装 Python 3.11
echo ""
echo "📦 安装 Python 3.11..."
if command -v python3.11 &> /dev/null; then
    echo "✅ Python 3.11 已安装"
    python3.11 --version
else
    echo "⬇️  正在安装 Python 3.11（可能需要几分钟）..."
    brew install python@3.11
    echo "✅ Python 3.11 安装完成"
fi

# 3. 删除旧虚拟环境
echo ""
echo "🗑️  删除旧虚拟环境..."
if [ -d "venv" ]; then
    rm -rf venv
    echo "✅ 旧环境已删除"
else
    echo "ℹ️  未发现旧环境"
fi

# 4. 创建新虚拟环境
echo ""
echo "📦 创建 Python 3.11 虚拟环境..."
/opt/homebrew/bin/python3.11 -m venv venv
echo "✅ 虚拟环境创建完成"

# 5. 激活虚拟环境
echo ""
echo "🔄 激活虚拟环境..."
source venv/bin/activate

# 验证 Python 版本
PYTHON_VERSION=$(python --version)
echo "✅ 当前 Python: $PYTHON_VERSION"

# 6. 升级 pip 和构建工具
echo ""
echo "⬆️  升级 pip 和构建工具..."
pip install --upgrade pip setuptools wheel

# 安装构建依赖（修复 openai-whisper 问题）
pip install setuptools-scm

# 7. 安装 NumPy（先安装，避免依赖冲突）
echo ""
echo "📥 安装 NumPy..."
pip install "numpy>=1.26.0,<2.0"

# 8. 安装 PyTorch（针对 M3 Max）
echo ""
echo "📥 安装 PyTorch（可能需要 2-3 分钟）..."
pip install torch torchaudio

# 9. 安装 Whisper（直接从 git，避免构建问题）
echo ""
echo "📥 安装 OpenAI Whisper..."
pip install git+https://github.com/openai/whisper.git

# 10. 安装其他依赖（跳过 whisper，已单独安装）
echo ""
echo "📥 安装其他项目依赖..."
pip install Flask==3.0.0 Flask-WTF==1.2.1 Flask-Session==0.5.0
pip install chatterbox-tts==0.1.6
pip install requests==2.31.0 openai==1.10.0
pip install python-dotenv==1.0.0 Werkzeug==3.0.1

echo "✅ 所有依赖安装完成"

# 11. 创建必要目录
echo ""
echo "📁 创建项目目录..."
mkdir -p data
mkdir -p static/audio
mkdir -p flask_session
echo "✅ 目录创建完成"

# 12. 测试导入
echo ""
echo "🧪 测试关键模块..."
python -c "import flask; import torch; print('✅ Flask:', flask.__version__); print('✅ PyTorch:', torch.__version__)"

# 13. 显示系统信息
echo ""
echo "=========================================="
echo "✅ 安装完成！"
echo "=========================================="
echo ""
echo "📊 系统信息:"
python << 'EOF'
import torch
import sys

print(f"   Python: {sys.version.split()[0]}")
print(f"   PyTorch: {torch.__version__}")

device = "CPU"
if torch.backends.mps.is_available():
    device = "MPS (Apple Silicon)"
elif torch.cuda.is_available():
    device = "CUDA"

print(f"   计算设备: {device}")
EOF

echo ""
echo "🚀 下一步："
echo "   ./start.sh"
echo ""
