#!/bin/bash
# 中考英语助手 - 一键启动脚本
# 适用于 macOS (M3 Max) / Linux

set -e  # 遇到错误立即退出

echo "=========================================="
echo "🚀 中考英语助手 - 启动中..."
echo "=========================================="
echo ""

# 1. 检查虚拟环境是否存在
if [ ! -d "venv" ]; then
    echo "❌ 错误: 虚拟环境不存在"
    echo "   请先运行首次安装脚本:"
    echo "   ./setup.sh"
    exit 1
fi

# 2. 激活虚拟环境
echo "🔄 激活虚拟环境..."
source venv/bin/activate
echo "✅ 虚拟环境已激活"

# 3. 检查依赖是否安装
echo ""
echo "📦 检查依赖..."
if ! python3 -c "import flask" 2>/dev/null; then
    echo "❌ 错误: Flask 未安装"
    echo "   请先运行: ./setup.sh"
    exit 1
fi
echo "✅ 依赖检查通过"

# 4. 检查配置
echo ""
echo "⚙️  检查配置..."
if grep -q "your-api-key-here" config.py 2>/dev/null; then
    echo "⚠️  警告: API 密钥可能未配置"
    echo "   如果遇到 API 错误，请检查 config.py"
fi

# 5. 显示系统信息
echo ""
echo "💻 系统信息:"
echo "   Python: $(python3 --version)"
echo "   工作目录: $(pwd)"

# 检查 GPU/MPS 支持
python3 << EOF
import torch
device = "cpu"
if torch.backends.mps.is_available():
    device = "MPS (Apple Silicon GPU)"
elif torch.cuda.is_available():
    device = "CUDA (NVIDIA GPU)"
print(f"   计算设备: {device}")
EOF

# 6. 启动 Flask 应用
echo ""
echo "=========================================="
echo "🎓 启动 Flask 应用..."
echo "=========================================="
echo ""
echo "⏳ 首次启动可能需要 30-60 秒（加载模型）"
echo "📍 启动完成后访问: http://127.0.0.1:5000"
echo ""
echo "提示："
echo "  - 按 Ctrl+C 停止服务器"
echo "  - 如需在后台运行，使用: ./start.sh &"
echo ""
echo "=========================================="
echo ""

# 设置环境变量
export FLASK_APP=app.py
export FLASK_ENV=development

# 启动 Flask（带颜色输出）
python3 -m flask run --host=127.0.0.1 --port=5000

# 如果 Flask 退出，显示信息
echo ""
echo "=========================================="
echo "👋 服务器已停止"
echo "=========================================="
