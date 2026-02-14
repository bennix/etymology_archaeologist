"""
本地模型管理器 - OpenAI TTS + Whisper STT
单例模式，应用启动时预加载所有模型
"""
import os
import uuid
import time
import torch
import whisper
from pathlib import Path
from config import Config

# 初始化 OpenAI TTS 客户端
try:
    from openai import OpenAI
    TTS_AVAILABLE = True
except ImportError:
    print("⚠️  OpenAI 未安装，TTS 功能将不可用")
    print("   安装方法: pip install openai")
    TTS_AVAILABLE = False

class ModelManager:
    """
    统一管理 OpenAI TTS 和 Whisper 模型
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

        # 2. 初始化 OpenAI TTS 客户端
        self.openai_client = None
        if TTS_AVAILABLE:
            self._init_openai_tts()

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

    def _init_openai_tts(self):
        """初始化 OpenAI TTS 客户端"""
        try:
            print("🎙️  正在初始化 OpenAI TTS...")
            load_start = time.time()

            # 初始化 OpenAI 客户端
            self.openai_client = OpenAI(api_key=Config.OPENAI_API_KEY)

            # TTS 配置
            self.tts_model = "tts-1-hd"  # 高质量模型 (或用 tts-1 更快)
            self.tts_voice = "alloy"     # 可选: alloy, echo, fable, onyx, nova, shimmer

            elapsed = time.time() - load_start
            print(f"   ✓ OpenAI TTS 初始化完成 ({elapsed:.3f}s)")
            print(f"   → 模型: {self.tts_model}, 音色: {self.tts_voice}")

        except Exception as e:
            print(f"   ❌ OpenAI TTS 初始化失败: {e}")
            if "api_key" in str(e).lower():
                print(f"   💡 提示: 需要配置 OpenAI API Key")
                print(f"   → 在 config.py 中设置 OPENAI_API_KEY")
            print(f"   → TTS 功能暂时不可用，将使用文本模式")
            self.openai_client = None

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

    def text_to_speech(self, text, language='en'):
        """
        文本转语音 (使用 OpenAI TTS API)

        Args:
            text: 要合成的文本
            language: 语言代码 (en, zh 等) - 暂未使用，OpenAI 会自动检测

        Returns:
            str: 音频文件路径（相对于 static/）
        """
        if not self.openai_client:
            return None

        try:
            # 生成唯一文件名
            filename = f"audio_{uuid.uuid4().hex[:12]}.mp3"
            filepath = os.path.join(self.audio_dir, filename)

            # 调用 OpenAI TTS API
            print(f"🎵 正在合成音频: {text[:50]}...")

            response = self.openai_client.audio.speech.create(
                model=self.tts_model,
                voice=self.tts_voice,
                input=text,
                response_format="mp3"  # 或 "wav", "opus", "aac", "flac"
            )

            # 保存音频文件
            response.stream_to_file(filepath)

            # 清理旧文件
            self._cleanup_old_audio_files()

            # 返回相对路径（供前端访问）
            return f"audio/{filename}"

        except Exception as e:
            print(f"❌ TTS 合成失败: {e}")
            return None

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
            'tts': self.openai_client is not None,
            'whisper': self.whisper is not None,
            'audio_count': len(list(Path(self.audio_dir).glob('audio_*.*')))
        }

# 全局单例
model_manager = ModelManager()
