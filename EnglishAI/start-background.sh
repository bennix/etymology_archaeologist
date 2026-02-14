#!/bin/bash
# 中考英语助手 - 后台启动脚本
# 适用于需要在后台运行应用的场景

set -e

echo "🚀 正在后台启动中考英语助手..."

# 检查虚拟环境
if [ ! -d "venv" ]; then
    echo "❌ 错误: 虚拟环境不存在，请先运行: ./setup.sh"
    exit 1
fi

# 激活虚拟环境
source venv/bin/activate

# 创建日志目录
mkdir -p logs

# 获取时间戳
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
LOG_FILE="logs/app_${TIMESTAMP}.log"

# 后台启动
export FLASK_APP=app.py
export FLASK_ENV=development

echo "📝 日志文件: $LOG_FILE"
echo "🔍 查看日志: tail -f $LOG_FILE"
echo ""

nohup python3 -m flask run --host=127.0.0.1 --port=5000 > "$LOG_FILE" 2>&1 &
PID=$!

echo "✅ 应用已在后台启动"
echo "   进程 ID: $PID"
echo "   访问地址: http://127.0.0.1:5000"
echo ""
echo "停止应用:"
echo "   kill $PID"
echo "   或运行: ./stop.sh"
echo ""

# 保存 PID 到文件
echo $PID > .app.pid
echo "💾 PID 已保存到 .app.pid"
