#!/bin/bash
# 中考英语助手 - 首次安装脚本
# 适用于 macOS (M3 Max) / Linux

set -e  # 遇到错误立即退出

echo "=========================================="
echo "🎓 中考英语助手 - 首次安装"
echo "=========================================="
echo ""

# 1. 检查 Python 版本
echo "📌 检查 Python 版本..."
if ! command -v python3 &> /dev/null; then
    echo "❌ 错误: 未找到 Python 3"
    echo "   请先安装 Python 3.11 或更高版本"
    echo "   下载地址: https://www.python.org/downloads/"
    exit 1
fi

PYTHON_VERSION=$(python3 --version | awk '{print $2}')
REQUIRED_VERSION="3.11"
if [ "$(printf '%s\n' "$REQUIRED_VERSION" "$PYTHON_VERSION" | sort -V | head -n1)" != "$REQUIRED_VERSION" ]; then
    echo "⚠️  警告: Python 版本较低 ($PYTHON_VERSION)"
    echo "   建议使用 Python 3.11+，但会继续安装..."
else
    echo "✅ Python 版本: $PYTHON_VERSION"
fi

# 2. 创建虚拟环境
echo ""
echo "📦 创建虚拟环境..."
if [ -d "venv" ]; then
    echo "⚠️  虚拟环境已存在，跳过创建"
else
    python3 -m venv venv
    echo "✅ 虚拟环境创建完成"
fi

# 3. 激活虚拟环境
echo ""
echo "🔄 激活虚拟环境..."
source venv/bin/activate

# 4. 升级 pip
echo ""
echo "⬆️  升级 pip..."
pip install --upgrade pip setuptools wheel

# 5. 安装依赖
echo ""
echo "📥 安装项目依赖（这可能需要 2-5 分钟）..."
echo "   正在安装: Flask, PyTorch, Chatterbox, Whisper..."

# 先安装 PyTorch（针对 M3 Max）
pip install torch torchvision torchaudio

# 再安装其他依赖
pip install -r requirements.txt

echo "✅ 依赖安装完成"

# 6. 检查必要的目录
echo ""
echo "📁 创建必要的目录..."
mkdir -p data
mkdir -p static/audio
mkdir -p flask_session
echo "✅ 目录创建完成"

# 7. 测试导入
echo ""
echo "🧪 测试关键模块导入..."
python3 -c "import flask; import torch; print('✅ Flask 和 PyTorch 导入成功')"

# 检查 Chatterbox（可能未安装）
if python3 -c "import chatterbox" 2>/dev/null; then
    echo "✅ Chatterbox 已安装"
else
    echo "⚠️  Chatterbox 未安装，将在首次启动时提示"
    echo "   安装命令: pip install chatterbox-tts"
fi

# 检查 Whisper
if python3 -c "import whisper" 2>/dev/null; then
    echo "✅ Whisper 已安装"
else
    echo "⚠️  Whisper 未安装"
    echo "   安装命令: pip install openai-whisper"
fi

# 8. 配置检查
echo ""
echo "⚙️  检查配置文件..."
if grep -q "your-api-key-here" config.py 2>/dev/null; then
    echo "⚠️  警告: API 密钥未配置"
    echo "   请编辑 config.py 填入你的 zenmux.ai API 密钥"
else
    echo "✅ API 密钥已配置"
fi

# 9. 完成
echo ""
echo "=========================================="
echo "✅ 安装完成！"
echo "=========================================="
echo ""
echo "下一步："
echo "  1. 确保已配置 API 密钥（编辑 config.py）"
echo "  2. 运行启动脚本："
echo "     ./start.sh"
echo ""
echo "或手动启动："
echo "     source venv/bin/activate"
echo "     flask run"
echo ""
