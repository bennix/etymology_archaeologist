#!/usr/bin/env python3
"""
测试 TTS 对话格式自动识别功能
"""
from models import model_manager

print("=" * 60)
print("🧪 测试 TTS 对话格式自动识别")
print("=" * 60)
print()

# 重置音色
model_manager.reset_speaker_voices()

# 测试数据
test_cases = [
    "Li Ming: How are you today?",
    "Mary: I'm fine, thank you!",
    "Li Ming: That's great to hear.",
]

print("📝 测试用例:")
for i, text in enumerate(test_cases, 1):
    print(f"  {i}. {text}")
print()

print("-" * 60)
print("🎵 开始生成音频...")
print("-" * 60)
print()

# 生成音频
for text in test_cases:
    # 测试解析功能
    speaker, actual_text = model_manager._parse_speaker_label(text)
    print(f"原文本: {text}")
    print(f"  → 识别说话人: {speaker}")
    print(f"  → 实际内容: {actual_text}")

    # 检测性别
    if speaker:
        gender = model_manager._detect_speaker_gender(speaker)
        print(f"  → 性别检测: {gender}")

    # 生成音频
    audio_path = model_manager.text_to_speech(text)
    print(f"  → 音频文件: {audio_path}")
    print()

print("-" * 60)
print("✅ 测试完成！")
print("-" * 60)
print()

print("📊 当前音色分配:")
for speaker, voice in model_manager.speaker_voices.items():
    print(f"  {speaker}: {voice}")
print()

print("💡 提示:")
print("  1. 请听一下生成的音频文件")
print("  2. 检查是否只朗读了对话内容（不包括名字）")
print("  3. 检查 Li Ming 是否使用男声，Mary 是否使用女声")
print()
