"""
本地模型管理器 - Edge TTS + Whisper STT
单例模式，应用启动时预加载所有模型
"""
import os
import uuid
import time
import torch
import whisper
import asyncio
from pathlib import Path
from config import Config

# 初始化 Edge TTS
try:
    import edge_tts
    TTS_AVAILABLE = True
except ImportError:
    print("⚠️  Edge TTS 未安装，TTS 功能将不可用")
    print("   安装方法: pip install edge-tts")
    TTS_AVAILABLE = False

class ModelManager:
    """
    统一管理 Edge TTS 和 Whisper 模型
    单例模式确保全局只加载一次
    """
    _instance = None

    def __new__(cls):
        if cls._instance is None:
            cls._instance = super().__new__(cls)
            cls._instance._initialized = False
        return cls._instance

    def __init__(self):
        if self._initialized:
            return

        print("\n" + "="*60)
        print("🚀 正在初始化 AI 模型...")
        print("="*60)

        start_time = time.time()

        # 1. 检测设备
        self.device = self._detect_device()
        print(f"🖥️  计算设备: {self.device.upper()}")

        # 2. 初始化 Edge TTS
        self.tts_available = TTS_AVAILABLE
        if TTS_AVAILABLE:
            self._init_edge_tts()

        # 3. 加载 Whisper STT
        self.whisper = None
        self._load_whisper()

        # 4. 音频文件管理
        self.audio_dir = Config.UPLOAD_FOLDER
        os.makedirs(self.audio_dir, exist_ok=True)

        elapsed = time.time() - start_time
        print(f"\n✅ 模型加载完成！耗时: {elapsed:.1f}秒")
        print("="*60 + "\n")

        self._initialized = True

    def _detect_device(self):
        """检测最佳计算设备（M3 Max 优先使用 MPS）"""
        if torch.backends.mps.is_available():
            return "mps"  # Apple Silicon Metal Performance Shaders
        elif torch.cuda.is_available():
            return "cuda"  # NVIDIA GPU
        else:
            return "cpu"

    def _init_edge_tts(self):
        """初始化 Edge TTS"""
        try:
            print("🎙️  正在初始化 Edge TTS...")
            load_start = time.time()

            # 多音色配置（用于对话场景）
            self.available_voices = [
                "en-US-AriaNeural",     # 女声 - 清晰友好
                "en-US-GuyNeural",      # 男声 - 专业稳重
                "en-US-JennyNeural",    # 女声 - 温暖亲切
                "en-US-EricNeural",     # 男声 - 年轻活力
                "en-US-MichelleNeural", # 女声 - 成熟优雅
                "en-US-RogerNeural"     # 男声 - 沉稳有力
            ]

            self.default_voice = "en-US-AriaNeural"  # 默认音色
            self.speaker_voices = {}  # 角色-音色映射 {speaker_id: voice}
            self.voice_index = 0  # 用于自动分配音色

            elapsed = time.time() - load_start
            print(f"   ✓ Edge TTS 初始化完成 ({elapsed:.3f}s)")
            print(f"   → 默认音色: {self.default_voice}")
            print(f"   → 对话音色池: {len(self.available_voices)} 种")

        except Exception as e:
            print(f"   ❌ Edge TTS 初始化失败: {e}")
            print(f"   → TTS 功能暂时不可用，将使用文本模式")
            self.tts_available = False

    def _load_whisper(self):
        """加载 Whisper STT"""
        try:
            # Whisper 不支持 MPS 稀疏张量操作，强制使用 CPU
            whisper_device = "cpu"
            print(f"🎤 正在加载 Whisper {Config.WHISPER_MODEL_SIZE} ({whisper_device})...")
            load_start = time.time()

            self.whisper = whisper.load_model(
                Config.WHISPER_MODEL_SIZE,
                device=whisper_device
            )

            elapsed = time.time() - load_start
            print(f"   ✓ Whisper 加载完成 ({elapsed:.1f}s)")

        except Exception as e:
            print(f"   ❌ Whisper 加载失败: {e}")
            print(f"   → STT 功能将不可用")
            self.whisper = None

    def text_to_speech(self, text, language='en', speaker=None):
        """
        文本转语音 (使用 Edge TTS)

        Args:
            text: 要合成的文本
            language: 语言代码 (en, zh 等) - 暂未使用
            speaker: 说话人标识（如 "A", "B", "teacher", "student"）
                    同一对话中相同 speaker 使用相同音色

        Returns:
            str: 音频文件路径（相对于 static/）
        """
        if not self.tts_available:
            return None

        try:
            # 确定使用的音色
            voice = self._get_speaker_voice(speaker)

            # 生成唯一文件名
            filename = f"audio_{uuid.uuid4().hex[:12]}.mp3"
            filepath = os.path.join(self.audio_dir, filename)

            # 调用 Edge TTS (同步包装异步函数)
            speaker_info = f" ({speaker})" if speaker else ""
            print(f"🎵 正在合成音频{speaker_info}: {text[:50]}...")

            # 运行异步 TTS
            asyncio.run(self._async_text_to_speech(text, filepath, voice))

            # 清理旧文件
            self._cleanup_old_audio_files()

            # 返回相对路径（供前端访问）
            return f"audio/{filename}"

        except Exception as e:
            print(f"❌ TTS 合成失败: {e}")
            return None

    def _get_speaker_voice(self, speaker):
        """
        获取说话人的音色（自动分配并保持一致）

        Args:
            speaker: 说话人标识

        Returns:
            str: 音色名称
        """
        if speaker is None:
            return self.default_voice

        # 如果该说话人已有分配的音色，直接返回
        if speaker in self.speaker_voices:
            return self.speaker_voices[speaker]

        # 为新说话人分配音色
        voice = self.available_voices[self.voice_index % len(self.available_voices)]
        self.speaker_voices[speaker] = voice
        self.voice_index += 1

        print(f"   → 分配音色: {speaker} → {voice}")
        return voice

    def reset_speaker_voices(self):
        """重置说话人音色映射（开始新对话时调用）"""
        self.speaker_voices = {}
        self.voice_index = 0
        print("🔄 已重置对话音色")

    def set_speaker_voice(self, speaker, voice):
        """
        手动设置说话人音色

        Args:
            speaker: 说话人标识
            voice: 音色名称（必须在 available_voices 中）
        """
        if voice in self.available_voices:
            self.speaker_voices[speaker] = voice
            print(f"✓ 设置音色: {speaker} → {voice}")
        else:
            print(f"⚠️  音色 {voice} 不在可用列表中")

    async def _async_text_to_speech(self, text, filepath, voice):
        """异步调用 Edge TTS"""
        communicate = edge_tts.Communicate(text, voice)
        await communicate.save(filepath)

    def speech_to_text(self, audio_file_path):
        """
        语音转文本

        Args:
            audio_file_path: 音频文件路径

        Returns:
            str: 转录的文本
        """
        if not self.whisper:
            return None

        try:
            print(f"🎤 正在转录音频: {audio_file_path}...")

            # Whisper 转录（使用 CPU，不支持 fp16）
            result = self.whisper.transcribe(
                audio_file_path,
                language='en',  # 指定英语
                fp16=False  # CPU 不支持 fp16
            )

            text = result['text'].strip()
            print(f"   ✓ 转录完成: {text[:50]}...")

            return text

        except Exception as e:
            print(f"❌ STT 转录失败: {e}")
            return None

    def _cleanup_old_audio_files(self):
        """清理过多的音频文件，保留最新的 N 个"""
        try:
            # 支持多种音频格式
            audio_files = list(Path(self.audio_dir).glob('audio_*.*'))

            if len(audio_files) > Config.MAX_AUDIO_FILES:
                # 按修改时间排序
                audio_files.sort(key=lambda x: x.stat().st_mtime)

                # 删除最旧的文件
                to_delete = audio_files[:-Config.MAX_AUDIO_FILES]
                for file in to_delete:
                    file.unlink()

                print(f"🧹 清理了 {len(to_delete)} 个旧音频文件")

        except Exception as e:
            print(f"⚠️  清理音频文件时出错: {e}")

    def get_status(self):
        """获取模型状态"""
        return {
            'device': self.device,
            'tts': self.tts_available,
            'whisper': self.whisper is not None,
            'audio_count': len(list(Path(self.audio_dir).glob('audio_*.*')))
        }

# 全局单例
model_manager = ModelManager()
