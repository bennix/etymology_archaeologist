#!/bin/bash
# Python 3.14 专用安装脚本（实验性）
# 适用于想使用最新 Python 的用户

set -e

echo "=========================================="
echo "⚠️  Python 3.14 实验性安装"
echo "=========================================="
echo ""
echo "注意：Python 3.14 是最新版本，部分库可能不稳定"
echo "推荐使用 Python 3.11 以获得最佳兼容性"
echo ""

# 检查 Python 版本
PYTHON_VERSION=$(python3 --version | awk '{print $2}')
echo "当前 Python 版本: $PYTHON_VERSION"

if [[ ! "$PYTHON_VERSION" =~ ^3\.14 ]]; then
    echo "❌ 此脚本仅适用于 Python 3.14"
    echo "   你的版本是: $PYTHON_VERSION"
    exit 1
fi

# 激活虚拟环境
if [ -d "venv" ]; then
    source venv/bin/activate
else
    echo "❌ 虚拟环境不存在，请先运行: python3 -m venv venv"
    exit 1
fi

echo ""
echo "📦 升级构建工具..."
pip install --upgrade pip setuptools wheel

echo ""
echo "📦 安装 NumPy（Python 3.14 兼容版本）..."
pip install "numpy>=1.26.0,<2.0"

echo ""
echo "📦 安装 PyTorch（可能需要几分钟）..."
pip install torch torchaudio

echo ""
echo "📦 安装其他依赖..."
pip install -r requirements.txt

echo ""
echo "=========================================="
echo "✅ 安装完成！"
echo "=========================================="
echo ""
echo "启动应用:"
echo "  ./start.sh"
echo ""
