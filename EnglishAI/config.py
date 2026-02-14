"""
配置文件 - API密钥和应用设置
"""
import os
from datetime import timedelta

class Config:
    # Flask 基础配置
    SECRET_KEY = os.environ.get('SECRET_KEY') or 'dev-secret-key-change-in-production'

    # Session 配置
    SESSION_TYPE = 'filesystem'
    SESSION_PERMANENT = True
    PERMANENT_SESSION_LIFETIME = timedelta(days=7)
    SESSION_FILE_DIR = os.path.join(os.path.dirname(__file__), 'flask_session')

    # 文件上传配置
    MAX_CONTENT_LENGTH = 10 * 1024 * 1024  # 10MB
    UPLOAD_FOLDER = os.path.join(os.path.dirname(__file__), 'static', 'audio')

    # Zenmux API 配置
    ZENMUX_API_KEY = "sk-ss-v1-b7ae6ebbc63886d9624802371f77eb170e135be724207a7a0e538c768fd197cc"
    ZENMUX_BASE_URL = "https://zenmux.ai/api/v1"

    # OpenAI API 配置 (可选，现已使用免费的 Edge TTS)
    # 如需使用 OpenAI API，获取方法: https://platform.openai.com/api-keys
    OPENAI_API_KEY = os.environ.get('OPENAI_API_KEY') or None

    # AI 模型配置
    MODELS = {
        'content_generator': 'moonshotai/kimi-k2-thinking-turbo',
        'evaluator': 'anthropic/claude-opus-4.5',
        'question_generator': 'minimax/minimax-m2.1'
    }

    # Whisper 配置
    WHISPER_MODEL_SIZE = 'base'  # tiny, base, small, medium, large

    # 音频文件清理配置
    MAX_AUDIO_FILES = 50  # 超过此数量自动清理最旧的

    # 高考词汇配置
    VOCAB_SOURCE_URL = 'https://raw.githubusercontent.com/pluto0x0/word3500/master/3500.txt'
    VOCAB_FILE = os.path.join(os.path.dirname(__file__), 'data', '3500.txt')
    VOCAB_JSON = os.path.join(os.path.dirname(__file__), 'data', 'gaokao_vocab.json')
