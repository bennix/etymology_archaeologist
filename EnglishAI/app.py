"""
Flask 主应用 - 中考英语教学助手
"""
import os
import json
import requests
from datetime import datetime
from flask import Flask, render_template, request, session, redirect, url_for, jsonify
from flask_session import Session
from werkzeug.utils import secure_filename
from config import Config
from models import model_manager
from agents import init_agents, ContentGenerator, Evaluator, QuestionGenerator

# 初始化 Flask 应用
app = Flask(__name__)
app.config.from_object(Config)

# 配置 Session
Session(app)

# 全局 Agents（预加载）
content_generator = None
evaluator = None
question_generator = None

def init_vocab():
    """初始化高考词汇库"""
    print("\n📚 正在准备高考词汇库...")

    # 1. 下载词汇文件（如果不存在）
    if not os.path.exists(Config.VOCAB_FILE):
        print("   ⬇️  下载 3500.txt...")
        try:
            os.makedirs(os.path.dirname(Config.VOCAB_FILE), exist_ok=True)
            response = requests.get(Config.VOCAB_SOURCE_URL, timeout=30)
            response.raise_for_status()
            with open(Config.VOCAB_FILE, 'wb') as f:
                f.write(response.content)
            print("   ✓ 下载完成")
        except Exception as e:
            print(f"   ❌ 下载失败: {e}")
            print(f"   → 请手动下载到 {Config.VOCAB_FILE}")
            return False

    # 2. 解析为 JSON（如果不存在）
    if not os.path.exists(Config.VOCAB_JSON):
        print("   🔄 解析词汇文件...")
        try:
            from data.vocab_parser import parse_word3500, save_vocab_json
            vocab = parse_word3500(Config.VOCAB_FILE)
            save_vocab_json(vocab, Config.VOCAB_JSON)
        except Exception as e:
            print(f"   ❌ 解析失败: {e}")
            return False

    # 3. 加载到内存
    try:
        with open(Config.VOCAB_JSON, 'r', encoding='utf-8') as f:
            vocab_data = json.load(f)
        polysemous_count = sum(1 for v in vocab_data.values() if v.get('is_polysemous'))
        print(f"   ✓ 词汇库加载完成: {len(vocab_data)} 词，{polysemous_count} 个多义词\n")
        return True
    except Exception as e:
        print(f"   ❌ 加载失败: {e}")
        return False

@app.before_request
def before_first_request():
    """应用启动时的初始化（只执行一次）"""
    global content_generator, evaluator, question_generator

    # 检查是否已初始化
    if content_generator is not None:
        return

    print("\n" + "="*60)
    print("🎓 中考英语教学助手启动中...")
    print("="*60)

    # 1. 初始化词汇库
    init_vocab()

    # 2. 模型已在 models.py 中自动加载（导入时）

    # 3. 初始化 AI Agents
    content_generator, evaluator, question_generator = init_agents()

    print("="*60)
    print("✅ 系统就绪！访问 http://127.0.0.1:5000")
    print("="*60 + "\n")

@app.route('/')
def index():
    """首页 - 四个模块入口"""
    # 初始化 session
    if 'scores' not in session:
        session['scores'] = []

    return render_template('index.html')

@app.route('/listening', methods=['GET', 'POST'])
def listening():
    """听力模块"""
    if request.method == 'GET':
        # 生成听力材料
        print("🎧 生成听力材料...")
        material = content_generator.generate_listening_material()

        if 'error' in material:
            return render_template('listening.html', error=material['error'])

        # 生成音频
        dialogue = material.get('dialogue', '')
        audio_path = model_manager.text_to_speech(dialogue)

        if not audio_path:
            # TTS 失败，提供文本备份
            return render_template(
                'listening.html',
                dialogue=dialogue,
                questions=material.get('questions', []),
                error='音频生成失败，请查看文本'
            )

        # 保存到 session
        session['listening_data'] = {
            'dialogue': dialogue,
            'questions': material.get('questions', []),
            'audio_path': audio_path
        }

        return render_template(
            'listening.html',
            dialogue=dialogue,
            questions=material.get('questions', []),
            audio_path=audio_path
        )

    else:  # POST - 提交答案
        user_answers = request.form.getlist('answers')
        listening_data = session.get('listening_data', {})
        questions = listening_data.get('questions', [])

        # 批改
        result = evaluator.check_answers(questions, user_answers)

        # 保存成绩
        score_entry = {
            'type': 'listening',
            'score': result.get('score', 0),
            'total': result.get('total', len(questions)),
            'timestamp': datetime.now().strftime('%Y-%m-%d %H:%M')
        }
        session['scores'] = session.get('scores', [])[-9:] + [score_entry]
        session.modified = True

        return render_template(
            'listening.html',
            result=result,
            dialogue=listening_data.get('dialogue'),
            questions=questions,
            user_answers=user_answers
        )

@app.route('/speaking', methods=['GET', 'POST'])
def speaking():
    """口语模块"""
    if request.method == 'GET':
        # 生成口语题目
        topics = [
            "描述你最喜欢的季节并说明原因",
            "谈谈你的周末计划",
            "介绍你最好的朋友",
            "描述一次难忘的旅行经历",
            "说说你对未来职业的想法"
        ]
        import random
        topic = random.choice(topics)

        session['speaking_topic'] = topic
        return render_template('speaking.html', topic=topic)

    else:  # POST - 上传录音
        if 'audio' not in request.files:
            return jsonify({'error': '没有音频文件'}), 400

        audio_file = request.files['audio']
        if audio_file.filename == '':
            return jsonify({'error': '文件名为空'}), 400

        # 保存上传的音频
        filename = secure_filename(f"recording_{datetime.now().strftime('%Y%m%d_%H%M%S')}.wav")
        filepath = os.path.join(Config.UPLOAD_FOLDER, filename)
        audio_file.save(filepath)

        # Whisper 转录
        transcript = model_manager.speech_to_text(filepath)

        if not transcript:
            return jsonify({'error': 'STT 转录失败'}), 500

        # 评估
        topic = session.get('speaking_topic', '口语练习')
        evaluation = evaluator.evaluate_speaking(transcript, topic)

        # 保存成绩
        score_entry = {
            'type': 'speaking',
            'score': evaluation.get('total_score', 0),
            'total': 40,
            'timestamp': datetime.now().strftime('%Y-%m-%d %H:%M')
        }
        session['scores'] = session.get('scores', [])[-9:] + [score_entry]
        session.modified = True

        # 删除临时音频文件
        try:
            os.remove(filepath)
        except:
            pass

        return jsonify({
            'transcript': transcript,
            'evaluation': evaluation
        })

@app.route('/reading', methods=['GET', 'POST'])
def reading():
    """阅读模块"""
    if request.method == 'GET':
        # 生成阅读文章
        print("📖 生成阅读材料...")
        material = content_generator.generate_reading_passage()

        if 'error' in material:
            return render_template('reading.html', error=material['error'])

        # 额外生成一些单选题
        passage = material.get('passage', '')
        extra_questions = question_generator.generate_multiple_choice(passage, count=2)

        all_questions = material.get('questions', []) + extra_questions

        # 保存到 session
        session['reading_data'] = {
            'title': material.get('title', '阅读理解'),
            'passage': passage,
            'questions': all_questions
        }

        return render_template(
            'reading.html',
            title=material.get('title'),
            passage=passage,
            questions=all_questions
        )

    else:  # POST - 提交答案
        reading_data = session.get('reading_data', {})
        questions = reading_data.get('questions', [])

        # 收集用户答案
        user_answers = []
        for i in range(len(questions)):
            answer = request.form.get(f'answer_{i}', '').strip()
            user_answers.append(answer)

        # 批改
        result = evaluator.check_answers(questions, user_answers)

        # 保存成绩
        score_entry = {
            'type': 'reading',
            'score': result.get('score', 0),
            'total': result.get('total', len(questions)),
            'timestamp': datetime.now().strftime('%Y-%m-%d %H:%M')
        }
        session['scores'] = session.get('scores', [])[-9:] + [score_entry]
        session.modified = True

        return render_template(
            'reading.html',
            title=reading_data.get('title'),
            passage=reading_data.get('passage'),
            questions=questions,
            result=result,
            user_answers=user_answers
        )

@app.route('/writing', methods=['GET', 'POST'])
def writing():
    """写作模块"""
    if request.method == 'GET':
        # 写作题目
        prompts = [
            {
                'title': '给朋友的一封信',
                'instruction': '假设你是李华，你的英国朋友Tom对中国传统节日很感兴趣。请你给他写一封信，介绍中国的春节。要求：1. 介绍春节的时间和意义 2. 描述主要庆祝活动 3. 邀请他来中国过春节。字数：80-100词。'
            },
            {
                'title': '我的梦想',
                'instruction': '请以"My Dream"为题，写一篇短文。内容包括：1. 你的梦想是什么 2. 为什么有这个梦想 3. 你将如何实现它。字数：80-100词。'
            },
            {
                'title': '环境保护',
                'instruction': '随着环境污染日益严重，环保已成为热门话题。请以"Protect Our Environment"为题写一篇短文。要求：1. 说明环境问题的现状 2. 提出2-3条保护环境的建议。字数：80-100词。'
            }
        ]

        import random
        prompt = random.choice(prompts)
        session['writing_prompt'] = prompt

        return render_template('writing.html', prompt=prompt)

    else:  # POST - 提交作文
        essay = request.form.get('essay', '').strip()

        if not essay:
            prompt = session.get('writing_prompt', {})
            return render_template('writing.html', prompt=prompt, error='作文不能为空')

        # 批改
        prompt = session.get('writing_prompt', {})
        evaluation = evaluator.evaluate_writing(essay, prompt.get('instruction', ''))

        # 保存成绩
        score_entry = {
            'type': 'writing',
            'score': evaluation.get('total_score', 0),
            'total': 20,
            'timestamp': datetime.now().strftime('%Y-%m-%d %H:%M')
        }
        session['scores'] = session.get('scores', [])[-9:] + [score_entry]
        session.modified = True

        return render_template(
            'writing.html',
            prompt=prompt,
            essay=essay,
            evaluation=evaluation
        )

@app.route('/history')
def history():
    """历史成绩"""
    scores = session.get('scores', [])

    # 按模块统计平均分
    stats = {}
    for score in scores:
        module = score['type']
        if module not in stats:
            stats[module] = {'total': 0, 'count': 0, 'scores': []}

        stats[module]['total'] += score['score']
        stats[module]['count'] += 1
        stats[module]['scores'].append(score['score'])

    # 计算平均分
    for module in stats:
        stats[module]['average'] = stats[module]['total'] / stats[module]['count']

    return render_template('history.html', scores=scores, stats=stats)

@app.route('/status')
def status():
    """系统状态（调试用）"""
    model_status = model_manager.get_status()

    return jsonify({
        'models': model_status,
        'agents': {
            'content_generator': content_generator is not None,
            'evaluator': evaluator is not None,
            'question_generator': question_generator is not None
        },
        'vocab_loaded': os.path.exists(Config.VOCAB_JSON),
        'session_scores_count': len(session.get('scores', []))
    })

if __name__ == '__main__':
    app.run(debug=True, host='127.0.0.1', port=5000)
