"""
AI Agent 类 - 封装三个不同功能的大模型
通过 Zenmux API 调用不同的模型
"""
import requests
import json
from config import Config

class BaseAgent:
    """AI Agent 基类"""

    def __init__(self, model_id):
        self.model_id = model_id
        self.api_key = Config.ZENMUX_API_KEY
        self.base_url = Config.ZENMUX_BASE_URL
        self.headers = {
            'Authorization': f'Bearer {self.api_key}',
            'Content-Type': 'application/json'
        }

    def _call_api(self, messages, temperature=0.7, max_tokens=2000):
        """
        调用 Zenmux API

        Args:
            messages: 消息列表 [{"role": "user", "content": "..."}]
            temperature: 温度参数
            max_tokens: 最大 token 数

        Returns:
            str: 模型响应内容
        """
        try:
            payload = {
                'model': self.model_id,
                'messages': messages,
                'temperature': temperature,
                'max_tokens': max_tokens
            }

            response = requests.post(
                f"{self.base_url}/chat/completions",
                headers=self.headers,
                json=payload,
                timeout=60
            )

            response.raise_for_status()
            data = response.json()

            return data['choices'][0]['message']['content']

        except requests.Timeout:
            return {"error": "模型响应超时，请重试"}
        except requests.RequestException as e:
            return {"error": f"API 调用失败: {str(e)}"}
        except (KeyError, IndexError) as e:
            return {"error": f"响应解析失败: {str(e)}"}

class ContentGenerator(BaseAgent):
    """
    内容生成 Agent
    使用 Kimi K2 Thinking Turbo (长上下文，高质量教学内容)
    """

    def __init__(self):
        super().__init__(Config.MODELS['content_generator'])
        print(f"   ✓ ContentGenerator ready ({self.model_id})")

    def generate_listening_material(self, topic=None):
        """
        生成听力材料

        Returns:
            dict: {
                'dialogue': "对话文本",
                'questions': [
                    {'question': '问题1', 'options': ['A', 'B', 'C', 'D'], 'answer': 'B'},
                    ...
                ]
            }
        """
        topics = ['日常生活', '学校活动', '旅行计划', '购物', '健康饮食', '天气谈论']
        topic = topic or f"主题：{topics[hash(str(hash)) % len(topics)]}"

        prompt = f"""
        生成一段适合中国初三学生的中考英语听力材料。

        要求：
        1. 两人对话，8-10句话
        2. {topic}
        3. 难度适中，包含常见高考词汇
        4. 生成3道听力理解题（单选题）

        请以 JSON 格式返回：
        {{
            "dialogue": "对话全文（每句话用换行分隔）",
            "questions": [
                {{
                    "question": "问题内容",
                    "options": ["A. 选项A", "B. 选项B", "C. 选项C", "D. 选项D"],
                    "answer": "B"
                }}
            ]
        }}
        """

        messages = [{"role": "user", "content": prompt}]
        response = self._call_api(messages, temperature=0.8)

        if isinstance(response, dict) and 'error' in response:
            return response

        try:
            # 尝试解析 JSON
            # 有时模型会在 JSON 外包裹 markdown 代码块
            if '```json' in response:
                response = response.split('```json')[1].split('```')[0].strip()
            elif '```' in response:
                response = response.split('```')[1].split('```')[0].strip()

            return json.loads(response)
        except json.JSONDecodeError:
            return {
                'dialogue': response,
                'questions': []
            }

    def generate_reading_passage(self, topic=None):
        """
        生成阅读理解文章

        Returns:
            dict: {
                'passage': "文章内容",
                'title': "文章标题",
                'questions': [...]
            }
        """
        topics = ['科技发展', '环境保护', '文化交流', '教育改革', '健康生活']
        topic = topic or topics[hash(str(hash)) % len(topics)]

        prompt = f"""
        生成一篇适合中国中考的英语阅读理解文章。

        主题：{topic}
        字数：200-250词
        难度：初三水平

        要求：
        1. 文章结构清晰（引入-展开-总结）
        2. 使用高考词汇，注意一词多义的体现
        3. 生成 5 道题目：3道单选 + 2道简答

        返回 JSON 格式：
        {{
            "title": "文章标题",
            "passage": "文章正文",
            "questions": [
                {{"type": "choice", "question": "...", "options": [...], "answer": "C"}},
                {{"type": "short_answer", "question": "...", "sample_answer": "..."}}
            ]
        }}
        """

        messages = [{"role": "user", "content": prompt}]
        response = self._call_api(messages, temperature=0.7, max_tokens=3000)

        if isinstance(response, dict) and 'error' in response:
            return response

        try:
            if '```json' in response:
                response = response.split('```json')[1].split('```')[0].strip()
            elif '```' in response:
                response = response.split('```')[1].split('```')[0].strip()

            return json.loads(response)
        except json.JSONDecodeError:
            return {
                'title': topic,
                'passage': response,
                'questions': []
            }

class Evaluator(BaseAgent):
    """
    评估批改 Agent
    使用 Claude Opus 4.5 (强大推理能力，适合主观题批改)
    """

    def __init__(self):
        super().__init__(Config.MODELS['evaluator'])
        print(f"   ✓ Evaluator ready ({self.model_id})")

    def evaluate_writing(self, essay, prompt_text):
        """
        批改作文

        Returns:
            dict: {
                'score': 18,  # 总分 20
                'content': {'score': 5, 'feedback': '...'},
                'structure': {'score': 4, 'feedback': '...'},
                'grammar': {'score': 5, 'feedback': '...'},
                'vocabulary': {'score': 4, 'feedback': '...'},
                'suggestions': [...]
            }
        """
        prompt = f"""
        你是一位资深的英语教师，正在批改中考英语作文。

        作文题目：{prompt_text}

        学生作文：
        {essay}

        请按照中考评分标准（满分20分）进行批改：
        1. 内容 (5分)：是否切题，内容是否充实
        2. 结构 (5分)：段落组织，逻辑连贯性
        3. 语法 (5分)：语法准确性，句式多样性
        4. 词汇 (5分)：词汇丰富度，用词准确性

        返回 JSON 格式：
        {{
            "total_score": 18,
            "content": {{"score": 5, "feedback": "..."}},
            "structure": {{"score": 4, "feedback": "..."}},
            "grammar": {{"score": 5, "feedback": "..."}},
            "vocabulary": {{"score": 4, "feedback": "..."}},
            "suggestions": ["建议1", "建议2", "建议3"],
            "corrected_errors": [
                {{"original": "错误句子", "corrected": "正确句子", "explanation": "说明"}}
            ]
        }}
        """

        messages = [{"role": "user", "content": prompt}]
        response = self._call_api(messages, temperature=0.3, max_tokens=2000)

        if isinstance(response, dict) and 'error' in response:
            return response

        try:
            if '```json' in response:
                response = response.split('```json')[1].split('```')[0].strip()
            elif '```' in response:
                response = response.split('```')[1].split('```')[0].strip()

            return json.loads(response)
        except json.JSONDecodeError:
            return {
                'total_score': 0,
                'error': '评分解析失败',
                'raw_feedback': response
            }

    def evaluate_speaking(self, transcript, topic):
        """
        评估口语转录文本

        Returns:
            dict: {
                'fluency': 7,  # 流利度 /10
                'grammar': 6,  # 语法 /10
                'vocabulary': 7,  # 词汇 /10
                'content': 8,  # 内容 /10
                'total_score': 28,  # 总分 /40
                'feedback': '...'
            }
        """
        prompt = f"""
        你是英语口语测评专家，正在评估初三学生的口语表现。

        题目：{topic}

        学生转录文本：
        {transcript}

        请评估以下四个维度（每项10分）：
        1. 流利度：语言流畅性，停顿次数
        2. 语法：语法准确性，时态使用
        3. 词汇：词汇丰富度和准确性
        4. 内容：内容完整性，切题程度

        返回 JSON：
        {{
            "fluency": 7,
            "grammar": 6,
            "vocabulary": 7,
            "content": 8,
            "total_score": 28,
            "feedback": "整体评价...",
            "suggestions": ["改进建议1", "建议2"]
        }}
        """

        messages = [{"role": "user", "content": prompt}]
        response = self._call_api(messages, temperature=0.3)

        if isinstance(response, dict) and 'error' in response:
            return response

        try:
            if '```json' in response:
                response = response.split('```json')[1].split('```')[0].strip()
            elif '```' in response:
                response = response.split('```')[1].split('```')[0].strip()

            return json.loads(response)
        except json.JSONDecodeError:
            return {'error': '评分解析失败', 'raw': response}

    def check_answers(self, questions, user_answers):
        """
        批改客观题和主观题

        Args:
            questions: 题目列表
            user_answers: 用户答案列表

        Returns:
            dict: {
                'score': 15,
                'total': 20,
                'details': [...]
            }
        """
        prompt = f"""
        批改以下题目：

        {json.dumps(questions, ensure_ascii=False, indent=2)}

        学生答案：
        {json.dumps(user_answers, ensure_ascii=False, indent=2)}

        请逐题批改，返回 JSON：
        {{
            "score": 15,
            "total": 20,
            "details": [
                {{
                    "question_index": 0,
                    "correct": true,
                    "user_answer": "B",
                    "correct_answer": "B",
                    "explanation": "解析..."
                }}
            ]
        }}
        """

        messages = [{"role": "user", "content": prompt}]
        response = self._call_api(messages, temperature=0.2)

        if isinstance(response, dict) and 'error' in response:
            return response

        try:
            if '```json' in response:
                response = response.split('```json')[1].split('```')[0].strip()
            elif '```' in response:
                response = response.split('```')[1].split('```')[0].strip()

            return json.loads(response)
        except json.JSONDecodeError:
            return {'error': '批改结果解析失败', 'raw': response}

class QuestionGenerator(BaseAgent):
    """
    题目生成 Agent
    使用 MiniMax M2.1 (逻辑严密，结构化出题)
    """

    def __init__(self):
        super().__init__(Config.MODELS['question_generator'])
        print(f"   ✓ QuestionGenerator ready ({self.model_id})")

    def generate_multiple_choice(self, passage, count=3):
        """
        基于文章生成单选题

        Returns:
            list: [
                {'question': '...', 'options': [...], 'answer': 'C', 'explanation': '...'},
                ...
            ]
        """
        prompt = f"""
        基于以下文章生成 {count} 道中考难度的单选题。

        文章：
        {passage}

        要求：
        1. 题目类型多样（细节题、推理题、词义题）
        2. 干扰项设计合理
        3. 每题都有详细解析

        返回 JSON 数组：
        [
            {{
                "question": "问题内容",
                "options": ["A. 选项A", "B. 选项B", "C. 选项C", "D. 选项D"],
                "answer": "C",
                "explanation": "解析..."
            }}
        ]
        """

        messages = [{"role": "user", "content": prompt}]
        response = self._call_api(messages, temperature=0.6)

        if isinstance(response, dict) and 'error' in response:
            return []

        try:
            if '```json' in response:
                response = response.split('```json')[1].split('```')[0].strip()
            elif '```' in response:
                response = response.split('```')[1].split('```')[0].strip()

            return json.loads(response)
        except json.JSONDecodeError:
            return []

# 初始化全局 Agents
def init_agents():
    """初始化所有 Agents"""
    print("\n🔗 正在初始化 AI Agents...")
    try:
        content_gen = ContentGenerator()
        evaluator = Evaluator()
        question_gen = QuestionGenerator()
        print("✅ 所有 Agents 已就绪\n")
        return content_gen, evaluator, question_gen
    except Exception as e:
        print(f"❌ Agents 初始化失败: {e}")
        return None, None, None
