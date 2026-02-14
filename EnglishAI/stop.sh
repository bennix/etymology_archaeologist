#!/bin/bash
# 中考英语助手 - 停止脚本

echo "🛑 正在停止中考英语助手..."

if [ -f ".app.pid" ]; then
    PID=$(cat .app.pid)

    if ps -p $PID > /dev/null 2>&1; then
        echo "   正在停止进程 $PID..."
        kill $PID
        sleep 2

        # 检查是否成功停止
        if ps -p $PID > /dev/null 2>&1; then
            echo "⚠️  进程未响应，强制停止..."
            kill -9 $PID
        fi

        echo "✅ 应用已停止"
        rm .app.pid
    else
        echo "⚠️  进程 $PID 不存在"
        rm .app.pid
    fi
else
    echo "⚠️  未找到 PID 文件"
    echo "   尝试查找 Flask 进程..."

    # 查找 Flask 进程
    PIDS=$(pgrep -f "flask run" || true)

    if [ -z "$PIDS" ]; then
        echo "   未找到运行中的 Flask 进程"
    else
        echo "   找到进程: $PIDS"
        echo "$PIDS" | xargs kill
        echo "✅ 已停止所有 Flask 进程"
    fi
fi
