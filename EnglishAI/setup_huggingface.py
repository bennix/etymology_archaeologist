#!/usr/bin/env python3
"""
Hugging Face 登录脚本
适用于 M3 Mac 或其他平台
"""
import sys

try:
    from huggingface_hub import login
    print("=" * 60)
    print("🤗 Hugging Face 登录")
    print("=" * 60)
    print()
    print("请按照以下步骤操作：")
    print()
    print("1. 访问: https://huggingface.co/settings/tokens")
    print("2. 点击 'New token' 创建新 token")
    print("3. 选择 'Read' 权限")
    print("4. 复制生成的 token")
    print()
    print("-" * 60)

    # 获取用户输入的 token
    token = input("请粘贴你的 Hugging Face token: ").strip()

    if not token:
        print("❌ Token 不能为空")
        sys.exit(1)

    # 登录
    print()
    print("🔐 正在登录...")
    login(token=token)

    print("✅ 登录成功！")
    print()
    print("现在可以运行: ./start.sh")
    print()

except ImportError:
    print("❌ huggingface_hub 未安装")
    print("请运行: pip install huggingface_hub")
    sys.exit(1)
except Exception as e:
    print(f"❌ 登录失败: {e}")
    sys.exit(1)
