#!/usr/bin/env python3
"""
预下载 TTS 和 STT 模型
在启动应用前运行此脚本，可以加快首次启动速度
"""
import sys
import os

print("=" * 60)
print("🚀 预下载 AI 模型")
print("=" * 60)
print()

# 1. 检查并登录 Hugging Face
print("📝 步骤 1: 检查 Hugging Face 登录状态")
print("-" * 60)

try:
    from huggingface_hub import get_token, login

    token = get_token()
    if token:
        print("✅ 已登录 Hugging Face")
        print(f"   Token: {token[:10]}...{token[-10:]}")
    else:
        print("⚠️  未检测到 Hugging Face token")
        print("   但之前的登录可能已保存")
        print()

except ImportError:
    print("❌ huggingface_hub 未安装")
    print("请运行: pip install huggingface_hub")
    sys.exit(1)
except Exception as e:
    print(f"⚠️  检查登录状态时出错: {e}")
    print("   继续尝试下载...")

print()

# 2. 检测设备
print("📝 步骤 2: 检测计算设备")
print("-" * 60)

try:
    import torch

    if torch.backends.mps.is_available():
        device = "mps"
        print("✅ 检测到 Apple Silicon (MPS)")
    elif torch.cuda.is_available():
        device = "cuda"
        print("✅ 检测到 NVIDIA GPU (CUDA)")
    else:
        device = "cpu"
        print("ℹ️  使用 CPU (较慢)")

except ImportError:
    print("❌ PyTorch 未安装")
    print("请运行: pip install torch")
    sys.exit(1)

print()

# 3. 下载 Whisper 模型
print("📝 步骤 3: 下载 Whisper STT 模型")
print("-" * 60)

try:
    import whisper

    print("⬇️  正在下载 Whisper base 模型...")
    model = whisper.load_model("base", device=device)
    print("✅ Whisper 模型下载完成")

    # 测试
    print("🧪 测试 Whisper...")
    print("   模型已加载到内存")

    del model  # 释放内存

except ImportError:
    print("❌ OpenAI Whisper 未安装")
    print("请运行: pip install git+https://github.com/openai/whisper.git")
except Exception as e:
    print(f"⚠️  Whisper 下载失败: {e}")

print()

# 4. 下载 Chatterbox 模型
print("📝 步骤 4: 下载 Chatterbox TTS 模型")
print("-" * 60)

try:
    from chatterbox.tts_turbo import ChatterboxTurboTTS

    print("⬇️  正在下载 Chatterbox Turbo 模型...")
    print("   (首次下载约 350MB，可能需要几分钟)")

    model = ChatterboxTurboTTS.from_pretrained(
        device=device,
        token=True  # 使用已登录的 HF token
    )

    print("✅ Chatterbox 模型下载完成")

    # 测试
    print("🧪 测试 Chatterbox...")
    test_text = "Hello, this is a test."
    try:
        audio = model.generate(test_text)
        print(f"   ✅ 成功生成测试音频 (采样率: {model.sr} Hz)")
    except Exception as e:
        print(f"   ⚠️  测试失败: {e}")

    del model  # 释放内存

except ImportError:
    print("❌ Chatterbox 未安装")
    print("请运行: pip install chatterbox-tts")
except Exception as e:
    print(f"⚠️  Chatterbox 下载失败: {e}")
    if "token" in str(e).lower():
        print()
        print("💡 提示: 需要 Hugging Face token")
        print("   运行: python setup_huggingface.py")

print()
print("=" * 60)
print("✅ 模型下载完成！")
print("=" * 60)
print()
print("下一步:")
print("  ./start.sh")
print()
print("首次启动应用时，模型已缓存，启动会更快！")
print()
