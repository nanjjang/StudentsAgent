"""
StudyAgent — Gemini-powered agent that generates study content.
Uses the official Google GenAI SDK and optional Google Search grounding.
"""

import logging
import re

from google import genai
from google.genai import types

from app.config import get_settings
from app.models.study import SchoolLevel, StudySessionCreate, Subject, StudyPurpose

logger = logging.getLogger(__name__)

_STOP_WORDS = {
    "그리고", "하지만", "에서", "으로", "한다", "대한", "위한", "학습", "주제", "내용",
    "문제", "정리", "설명", "이다", "있는", "있는지", "the", "and", "for", "with",
}

_SUBJECT_LABEL = {
    Subject.korean: "국어",
    Subject.english: "영어",
    Subject.math: "수학",
    Subject.science: "과학",
    Subject.social: "사회",
    Subject.history: "역사",
    Subject.japanese: "일본어",
    Subject.chinese: "중국어",
    Subject.cs: "정보과학",
    Subject.data_science: "데이터과학",
    Subject.data_structure: "자료구조",
    Subject.computer_system: "컴퓨터시스템일반",
    Subject.networking: "정보통신",
    Subject.music: "음악",
    Subject.other: "기타",
}

_PURPOSE_LABEL = {
    StudyPurpose.exam_prep: "시험 대비",
    StudyPurpose.certification: "자격증 취득",
    StudyPurpose.background: "배경지식 넓히기",
    StudyPurpose.general: "일반 학습",
}

_SCHOOL_LEVEL_LABEL = {
    SchoolLevel.elementary: "초등",
    SchoolLevel.middle: "중등",
    SchoolLevel.high: "고등",
}

_SCHOOL_LEVEL_STYLE = {
    SchoolLevel.elementary: "초등학생이 이해할 수 있는 쉬운 문장과 친근한 예시를 사용하세요.",
    SchoolLevel.middle: "중학생이 학교 수업과 내신에 바로 연결할 수 있게 개념과 근거를 함께 설명하세요.",
    SchoolLevel.high: "고등학생이 시험과 실전 적용에 바로 쓸 수 있게 핵심 개념, 함정, 복습 포인트를 압축해서 설명하세요.",
}


def _extract_keywords(text: str, limit: int = 6) -> list[str]:
    keywords: list[str] = []
    for token in re.findall(r"[A-Za-z가-힣0-9]{2,}", text):
        lowered = token.lower()
        if lowered in _STOP_WORDS:
            continue
        if token in keywords:
            continue
        keywords.append(token)
        if len(keywords) >= limit:
            break
    return keywords


def _response_text(response: object) -> str:
    text = getattr(response, "text", None)
    if isinstance(text, str) and text.strip():
        return text

    candidates = getattr(response, "candidates", None) or []
    parts: list[str] = []
    for candidate in candidates:
        content = getattr(candidate, "content", None)
        for part in getattr(content, "parts", None) or []:
            part_text = getattr(part, "text", None)
            if isinstance(part_text, str) and part_text:
                parts.append(part_text)
    return "\n".join(parts).strip()


def _build_topic_description(session: StudySessionCreate) -> str:
    school_level = _SCHOOL_LEVEL_LABEL[session.school_level]
    subject = _SUBJECT_LABEL[session.subject]
    purpose = _PURPOSE_LABEL[session.purpose]

    if session.korean_input:
        inp = session.korean_input
        concepts = ", ".join(inp.concepts) if inp.concepts else "전반적인 내용"
        return f"{school_level} {subject} - 작품: {inp.text_name}, 학습 개념: {concepts} (목적: {purpose})"

    if session.english_input:
        if session.english_input.mock_exam:
            m = session.english_input.mock_exam
            nums = ", ".join(str(n) for n in m.question_numbers)
            return (f"{school_level} {subject} 모의고사 - {m.grade}학년 {m.year}년 {m.month}월 "
                    f"지문 {nums}번 (목적: {purpose})")
        if session.english_input.textbook:
            t = session.english_input.textbook
            return (f"{school_level} {subject} 교과서 - {t.publisher} {t.author} "
                    f"{t.grade}학년 {t.semester}학기 {t.chapter} {t.section} (목적: {purpose})")

    if session.textbook_input:
        t = session.textbook_input
        sem = f"{t.semester}학기" if t.semester else ""
        return (f"{school_level} {subject} 교과서 - {t.publisher} {t.author} "
                f"{t.grade}학년 {sem} {t.chapter} (목적: {purpose})")

    if session.cs_input:
        c = session.cs_input
        sem = f"{c.semester}학기" if c.semester else ""
        return (f"{school_level} {subject} - {c.publisher} {c.author} "
                f"{c.grade}학년 {sem} {c.chapter} (목적: {purpose})")

    if session.other_description:
        return f"{school_level} {subject} - {session.other_description} (목적: {purpose})"

    return f"{school_level} {subject} (목적: {purpose})"


def _build_search_prompt(topic: str, purpose: StudyPurpose, school_level: SchoolLevel) -> str:
    base = f"""당신은 한국 초중고 학생을 위한 학습 도우미 AI입니다.
다음 주제에 대해 웹 검색을 통해 정보를 수집하고, 학습 자료를 생성해주세요.

학습 주제: {topic}
학습 대상 학교급: {_SCHOOL_LEVEL_LABEL[school_level]}
설명 스타일: {_SCHOOL_LEVEL_STYLE[school_level]}

아래 형식으로 응답해주세요:

## 개념 설명
(해당 주제의 핵심 개념들을 상세하게 설명)

## 개념 요약
(핵심 포인트를 불릿 포인트로 간결하게 정리)

## 내용 정리
(학습해야 할 주요 내용을 체계적으로 정리)

## 오늘의 공부 시작
(학생이 지금 바로 시작할 수 있는 첫 20분 루틴, 순서, 체크리스트를 제시)

## 셀프 체크
(핵심 이해를 확인할 수 있는 짧은 질문 3~5개를 제시)

## 추천 문제 및 자료
(관련 기출문제 출처, 문제집, 온라인 자료 등 구체적으로 제시)
"""
    if purpose in (StudyPurpose.exam_prep, StudyPurpose.certification):
        base += """
## 시험/자격증 준비 방향
(해당 시험 유형 분석 및 효과적인 준비 방법 제시)
"""
    else:
        base += """
## 학습 방향
(학생이 복습 순서와 공부 포인트를 바로 이해할 수 있도록 다음 공부 방향을 제시)
"""
    return base


def _build_exam_analysis_prompt(topic: str, exam_content: str, school_level: SchoolLevel) -> str:
    return f"""학습 주제: {topic}
학습 대상 학교급: {_SCHOOL_LEVEL_LABEL[school_level]}
설명 스타일: {_SCHOOL_LEVEL_STYLE[school_level]}

제공된 기출문제를 분석하여 다음을 제공해주세요:

## 기출문제 분석
제공된 기출문제:
{exam_content}

위 기출문제를 분석하여:
1. 자주 출제되는 유형 분류
2. 난이도 분포
3. 핵심 출제 포인트
4. 취약 영역 파악
5. 맞춤형 공부 방향 제시

를 상세히 작성해주세요."""


class StudyAgent:
    def __init__(self):
        settings = get_settings()
        self.client = (
            genai.Client(api_key=settings.gemini_api_key)
            if settings.gemini_api_key
            else None
        )
        self.content_model = settings.gemini_content_model
        self.text_model = settings.gemini_text_model

    def get_topic_description(self, session: StudySessionCreate) -> str:
        return _build_topic_description(session)

    def _base_text_config(self, system_instruction: str | None = None) -> types.GenerateContentConfig:
        config_kwargs: dict[str, object] = {
            "thinking_config": types.ThinkingConfig(thinking_budget=0),
        }
        if system_instruction:
            config_kwargs["system_instruction"] = system_instruction
        return types.GenerateContentConfig(**config_kwargs)

    def generate_content(self, session: StudySessionCreate) -> dict:
        """Search web and generate study content. Returns dict with content sections."""
        topic = _build_topic_description(session)
        prompt = _build_search_prompt(topic, session.purpose, session.school_level)
        if not self.client:
            return self._build_fallback_sections(session, topic)

        try:
            response = self.client.models.generate_content(
                model=self.content_model,
                contents=prompt,
                config=types.GenerateContentConfig(
                    system_instruction=(
                        "당신은 한국 초중고 학생을 위한 학습 도우미입니다. "
                        "필요할 때 Google Search grounding을 활용해 최신성과 사실성을 높이고, "
                        f"{_SCHOOL_LEVEL_STYLE[session.school_level]} "
                        "반드시 사용자가 요청한 마크다운 섹션 형식으로만 답변하세요."
                    ),
                    tools=[types.Tool(google_search=types.GoogleSearch())],
                    thinking_config=types.ThinkingConfig(thinking_budget=0),
                ),
            )

            full_text = _response_text(response)
            return self._parse_content_sections(full_text, topic)
        except Exception:
            logger.exception("Falling back to local study content for topic: %s", topic)
            return self._build_fallback_sections(session, topic)

    def generate_content_stream(self, session: StudySessionCreate):
        """Stream content generation. Yields text chunks."""
        topic = _build_topic_description(session)
        prompt = _build_search_prompt(topic, session.purpose, session.school_level)
        if not self.client:
            yield self._build_fallback_sections(session, topic)["full_text"]
            return

        try:
            stream = self.client.models.generate_content_stream(
                model=self.content_model,
                contents=prompt,
                config=types.GenerateContentConfig(
                    system_instruction=(
                        "당신은 한국 초중고 학생을 위한 학습 도우미입니다. "
                        "필요할 때 Google Search grounding을 활용해 최신성과 사실성을 높이고, "
                        f"{_SCHOOL_LEVEL_STYLE[session.school_level]} "
                        "반드시 사용자가 요청한 마크다운 섹션 형식으로만 답변하세요."
                    ),
                    tools=[types.Tool(google_search=types.GoogleSearch())],
                    thinking_config=types.ThinkingConfig(thinking_budget=0),
                ),
            )
            for chunk in stream:
                if chunk_text := getattr(chunk, "text", None):
                    yield chunk_text
        except Exception:
            logger.exception("Streaming content failed, using fallback for topic: %s", topic)
            yield self._build_fallback_sections(session, topic)["full_text"]

    def analyze_past_exam(self, topic: str, exam_content: str) -> str:
        """Analyze user-provided past exam papers."""
        school_level = SchoolLevel.middle
        for level, label in _SCHOOL_LEVEL_LABEL.items():
            if topic.startswith(label):
                school_level = level
                break
        prompt = _build_exam_analysis_prompt(topic, exam_content, school_level)
        if not self.client:
            return self._build_fallback_exam_analysis(topic, exam_content)

        try:
            response = self.client.models.generate_content(
                model=self.text_model,
                contents=prompt,
                config=self._base_text_config(
                    "당신은 시험 대비 분석 도우미입니다. 한국 학생이 바로 복습에 활용할 수 있는 실전형 분석을 제공하세요."
                ),
            )
            result = _response_text(response)
            return result or self._build_fallback_exam_analysis(topic, exam_content)
        except Exception:
            logger.exception("Exam analysis failed, using fallback for topic: %s", topic)
            return self._build_fallback_exam_analysis(topic, exam_content)

    def generate_mindmap(self, topic: str, content: str) -> str:
        """Generate a markdown-based mind map / concept map."""
        prompt = f"""다음 학습 내용을 바탕으로 마인드맵 형태의 개념 구조도를 생성해주세요.
마크다운 형식으로 계층 구조(헤딩, 불릿 등)를 사용하여 시각적으로 표현해주세요.

주제: {topic}

학습 내용:
{content[:3000]}

마인드맵 형식 예시:
# [핵심 주제]
## [대분류 1]
- [소분류 1-1]
  - 세부 내용
- [소분류 1-2]
## [대분류 2]
...

마인드맵을 생성해주세요:"""
        if not self.client:
            return self._build_fallback_mindmap(topic, content)

        try:
            response = self.client.models.generate_content(
                model=self.text_model,
                contents=prompt,
                config=self._base_text_config(
                    "당신은 마인드맵 생성 도우미입니다. 마크다운 계층 구조를 분명하게 유지하고, 불필요한 장식 없이 학습 구조가 잘 보이게 작성하세요."
                ),
            )
            result = _response_text(response)
            return result or self._build_fallback_mindmap(topic, content)
        except Exception:
            logger.exception("Mind map generation failed, using fallback for topic: %s", topic)
            return self._build_fallback_mindmap(topic, content)

    def _build_fallback_sections(self, session: StudySessionCreate, topic: str) -> dict:
        summary_points = self._build_summary_points(session)
        outline_items = self._build_outline_items(session)
        start_items = self._build_start_items(session)
        self_check_items = self._build_self_check_items(session)
        resource_items = self._build_resource_items(session)
        direction_items = self._build_direction_items(session)

        explanation_parts = [
            f"{topic} 학습을 바로 시작할 수 있도록 핵심 범위를 정리했습니다.",
            self._build_scope_hint(session),
            "먼저 교과서나 원문에서 큰 흐름을 확인한 뒤, 핵심 용어와 근거를 자기 말로 다시 설명해보는 방식이 가장 안정적입니다.",
            "이후에는 예제나 대표 문제를 통해 개념이 실제 문항에서 어떻게 묻히는지 확인하고, 틀린 이유를 기준으로 복습 순서를 정하는 것이 좋습니다.",
        ]

        concept_explanation = "\n\n".join(part for part in explanation_parts if part)
        concept_summary = "\n".join(f"- {item}" for item in summary_points)
        content_outline = "\n".join(f"{idx}. {item}" for idx, item in enumerate(outline_items, start=1))
        study_start_guide = "\n".join(f"{idx}. {item}" for idx, item in enumerate(start_items, start=1))
        self_check_quiz = "\n".join(f"- {item}" for item in self_check_items)
        recommended_problems = "\n".join(f"- {item}" for item in resource_items)
        study_direction = "\n".join(f"- {item}" for item in direction_items)

        full_text = "\n\n".join(
            [
                "## 개념 설명",
                concept_explanation,
                "## 개념 요약",
                concept_summary,
                "## 내용 정리",
                content_outline,
                "## 오늘의 공부 시작",
                study_start_guide,
                "## 셀프 체크",
                self_check_quiz,
                "## 추천 문제 및 자료",
                recommended_problems,
                "## 시험/자격증 준비 방향" if study_direction else "## 학습 방향",
                study_direction,
            ]
        )

        return {
            "topic": topic,
            "concept_explanation": concept_explanation,
            "concept_summary": concept_summary,
            "content_outline": content_outline,
            "study_start_guide": study_start_guide,
            "self_check_quiz": self_check_quiz,
            "recommended_problems": recommended_problems,
            "study_direction": study_direction,
            "full_text": full_text,
        }

    def _build_scope_hint(self, session: StudySessionCreate) -> str:
        if session.korean_input:
            concepts = ", ".join(session.korean_input.concepts) or "핵심 개념"
            return f"국어에서는 작품/지문 '{session.korean_input.text_name}'를 중심으로 {concepts}을(를) 연결해서 이해하는 것이 우선입니다."

        if session.english_input:
            if session.english_input.mock_exam:
                exam = session.english_input.mock_exam
                numbers = ", ".join(map(str, exam.question_numbers)) or "핵심 지문"
                return f"영어 모의고사는 {exam.year}년 {exam.month}월 {numbers}번 지문을 중심으로, 지문 구조 파악과 선지 근거 확인을 함께 연습해야 합니다."
            if session.english_input.textbook:
                book = session.english_input.textbook
                return f"영어 교과서 '{book.chapter} {book.section}' 범위에서 본문 구조, 핵심 표현, 문법 포인트를 함께 묶어 보는 것이 효율적입니다."

        if session.textbook_input:
            book = session.textbook_input
            return f"'{book.chapter}' 단원을 큰 개념, 세부 사실, 자료 해석 순서로 나누어 학습하면 기억과 적용이 훨씬 쉬워집니다."

        if session.cs_input:
            cs = session.cs_input
            return f"'{cs.chapter}' 단원은 용어 암기보다 원리 이해와 예시 적용을 함께 묶어야 실전 문제에 잘 대응할 수 있습니다."

        if session.other_description:
            return f"입력한 학습 목표는 '{session.other_description}'이며, 범위를 작은 단위로 나눠 단계적으로 정리하는 접근이 적합합니다."

        return "핵심 개념을 먼저 큰 구조로 잡고, 이후 예시와 문제에 적용하는 흐름으로 공부해보세요."

    def _build_summary_points(self, session: StudySessionCreate) -> list[str]:
        points = [
            "범위를 작은 단원으로 나누고 매 학습마다 산출물을 남긴다.",
            "핵심 용어를 외우는 데서 끝내지 말고, 근거와 예시까지 함께 정리한다.",
            "문제 풀이 후에는 맞은 문제보다 틀린 이유를 기준으로 복습한다.",
        ]

        if session.korean_input:
            concepts = ", ".join(session.korean_input.concepts[:3]) or "핵심 개념"
            points.insert(0, f"작품/지문 '{session.korean_input.text_name}'에서 {concepts}의 쓰임을 직접 표시해본다.")
        elif session.english_input and session.english_input.mock_exam:
            points.insert(0, "영어 지문은 제목-주제-문단 역할-선지 근거 순서로 읽는다.")
        elif session.subject == Subject.history:
            points.insert(0, "역사는 사건의 원인-전개-결과와 시대 흐름을 연표로 연결한다.")
        elif session.subject in {Subject.math, Subject.science, Subject.social}:
            points.insert(0, "대표 유형을 풀기 전에 정의와 공식, 자료 해석 기준을 먼저 점검한다.")
        elif session.subject in {
            Subject.cs, Subject.data_science, Subject.data_structure,
            Subject.computer_system, Subject.networking,
        }:
            points.insert(0, "정보과학 계열은 개념 정의와 예시를 한 세트로 묶어 기억한다.")

        if session.school_level == SchoolLevel.elementary:
            points.insert(0, "어려운 말은 짧게 바꾸고, 한 번 읽은 뒤 스스로 다시 말해보며 이해를 확인한다.")
        elif session.school_level == SchoolLevel.high:
            points.insert(0, "개념을 외우는 데서 멈추지 말고, 출제 포인트와 함정까지 함께 정리한다.")

        return points

    def _build_start_items(self, session: StudySessionCreate) -> list[str]:
        if session.school_level == SchoolLevel.elementary:
            items = [
                "교과서나 지문에서 오늘 공부할 부분을 5분 동안 천천히 읽고, 모르는 낱말에 표시하기.",
                "핵심 개념 2개를 골라 짧은 말로 바꿔 쓰고, 소리 내어 다시 설명해보기.",
                "가장 쉬운 확인 문제 1~2개를 먼저 풀어보며 자신감을 만들기.",
            ]
        elif session.school_level == SchoolLevel.high:
            items = [
                "오늘 범위를 3개의 소주제로 나누고, 각 소주제에서 반드시 잡아야 할 출제 포인트를 먼저 적기.",
                "개념 정리 10분 뒤 바로 대표 문제를 풀면서 실제로 어떤 방식으로 묻는지 확인하기.",
                "틀린 문제나 헷갈린 선지는 오답 사유를 한 줄로 남겨 다음 복습 때 바로 회수하기.",
            ]
        else:
            items = [
                "오늘 범위의 큰 흐름을 5분 안에 훑고, 핵심 개념 3개를 먼저 체크하기.",
                "개념을 읽은 뒤 예시나 문제에 바로 적용해보며 이해 여부를 확인하기.",
                "공부가 끝나기 전에 오늘 헷갈린 개념 2개를 따로 적어 복습 후보로 남기기.",
            ]

        if session.subject == Subject.history:
            items.insert(1, "사건 흐름을 연표 한 줄로 적어보고, 원인-전개-결과를 화살표로 연결하기.")
        elif session.subject == Subject.korean:
            items.insert(1, "작품이나 지문에서 중요한 구절에 밑줄을 긋고, 왜 중요한지 한 줄 메모를 남기기.")
        elif session.subject == Subject.english:
            items.insert(1, "영어는 제목, 주제, 문단 역할을 먼저 확인한 뒤 핵심 문장을 표시하기.")

        return items[:4]

    def _build_self_check_items(self, session: StudySessionCreate) -> list[str]:
        level_tail = {
            SchoolLevel.elementary: "내 말로 쉽게 설명할 수 있나요?",
            SchoolLevel.middle: "근거와 함께 설명할 수 있나요?",
            SchoolLevel.high: "문제에서 어떻게 응용될지까지 말할 수 있나요?",
        }[session.school_level]

        items = [
            f"오늘 공부한 핵심 개념 한 가지를 말할 수 있나요? {level_tail}",
            "헷갈렸던 부분은 무엇이었고, 왜 헷갈렸는지 한 줄로 적을 수 있나요?",
            "오늘 푼 문제나 예시에서 정답 근거를 설명할 수 있나요?",
        ]

        if session.subject == Subject.history:
            items.append("사건의 원인-전개-결과를 순서대로 말할 수 있나요?")
        elif session.subject == Subject.korean:
            items.append("작품/지문에서 핵심 구절이 어떤 역할을 하는지 설명할 수 있나요?")
        elif session.subject == Subject.english:
            items.append("지문의 주제와 문단 역할을 근거 문장과 함께 찾을 수 있나요?")
        else:
            items.append("대표 문제를 다시 볼 때 같은 실수를 반복하지 않을 자신이 있나요?")

        return items

    def _build_outline_items(self, session: StudySessionCreate) -> list[str]:
        if session.korean_input:
            return [
                "작품 배경, 화자/서술자, 갈래 등 큰 구조 파악",
                "입력한 개념이 본문 어디에서 드러나는지 근거 표시",
                "핵심 구절을 자기 말로 해석하고 비교 포인트 정리",
                "서술형 또는 선택형 문제로 개념 적용 연습",
                "오답 유형을 개념 부족/근거 누락/표현 실수로 구분",
            ]

        if session.english_input:
            if session.english_input.mock_exam:
                return [
                    "지문 주제와 문단별 역할을 먼저 파악",
                    "핵심 문장과 연결 표현을 표시하며 구조 읽기",
                    "문제 선지의 정답 근거와 오답 근거를 함께 확인",
                    "어휘, 구문, 주제 추론 포인트를 오답노트로 정리",
                    "같은 유형 문제를 2~3개 추가로 풀어 패턴 익히기",
                ]
            return [
                "교과서 본문을 문단별로 나누고 핵심 표현 체크",
                "문법, 어휘, 내용 이해 포인트를 한 장으로 요약",
                "해당 단원 기본 문제와 서술형 문제 풀이",
                "본문 재진술 또는 영작으로 표현 사용 연습",
                "틀린 문제는 문법/어휘/독해 원인으로 분류",
            ]

        if session.subject == Subject.history:
            return [
                "시대 배경과 핵심 사건을 연표로 정리",
                "원인-전개-결과를 연결해 사건 흐름 이해",
                "인물, 제도, 사료의 의미를 한 줄로 요약",
                "사료/지도/연표형 문제를 통해 자료 해석 연습",
                "시대 비교 포인트를 표로 정리하며 복습",
            ]

        if session.textbook_input:
            return [
                "교과서 단원을 큰 개념과 소주제로 나눠보기",
                "정의, 공식, 핵심 문장을 한 장 요약으로 정리",
                "대표 예제와 기본 문제로 이해도 점검",
                "헷갈린 개념은 교과서 그림·표·자료와 함께 다시 확인",
                "단원 마무리 문제로 약한 부분 선별 복습",
            ]

        if session.cs_input:
            return [
                "핵심 용어와 원리를 짧은 정의로 정리",
                "개념을 예시, 도식, 간단한 코드/사례와 연결",
                "교재 문제 또는 실습 과제로 적용 연습",
                "입력과 출력, 자료 흐름을 말로 설명해보기",
                "실수한 개념을 유형별로 분류해 재복습",
            ]

        return [
            "학습 목표를 3~5개의 작은 하위 주제로 나누기",
            "핵심 개념과 예시를 한 세트로 정리하기",
            "짧은 확인 문제나 셀프 테스트로 이해도 점검",
            "부족한 부분만 다시 읽고 간단히 재정리하기",
        ]

    def _build_resource_items(self, session: StudySessionCreate) -> list[str]:
        items = [
            "교과서 또는 원문 해당 범위를 먼저 읽고 핵심 용어에 밑줄 긋기",
            "학교 프린트, 수업 노트, 자습서의 설명 차이를 비교하며 정리하기",
            "대표 문제 5~10개를 풀고 오답 사유를 한 줄로 남기기",
            "현재는 실시간 검색 연결 없이 생성된 가이드이므로 최신 자료는 학교 수업자료나 공신력 있는 학습 사이트에서 함께 확인하기",
        ]

        if session.english_input and session.english_input.mock_exam:
            items.insert(0, "평가원·교육청 기출에서 동일 유형 문제를 2~3세트 더 찾아 풀기")
        elif session.subject == Subject.history:
            items.insert(0, "사료, 연표, 지도 자료를 같이 보며 사건 흐름을 시각화하기")
        elif session.cs_input:
            items.insert(0, "교재 예제와 관련 실습 파일을 함께 열어 흐름을 직접 따라가기")

        return items

    def _build_direction_items(self, session: StudySessionCreate) -> list[str]:
        total_hours = 0.0
        if session.study_hours_per_day:
            total_hours = sum(session.study_hours_per_day.values())

        if session.purpose in (StudyPurpose.exam_prep, StudyPurpose.certification):
            items = [
                "초반 60%는 개념과 유형 정리, 후반 40%는 실전 문제와 복습에 배분합니다.",
                "매일 학습 끝에 오늘 헷갈린 개념 3가지를 다시 적으며 회수 복습합니다.",
            ]
            if session.days_remaining:
                items.insert(
                    0,
                    f"남은 기간은 {session.days_remaining}일이며, 주당 확보 시간은 약 {total_hours:.1f}시간 기준으로 잡는 것이 안정적입니다."
                    if total_hours
                    else f"남은 기간은 {session.days_remaining}일이므로 매일 학습 후 누적 복습 시간을 따로 확보하는 것이 중요합니다.",
                )
            return items

        items = [
            "처음 2~3회차는 이해 중심으로, 이후부터는 설명 없이도 다시 말할 수 있는지 점검합니다.",
            "하루 학습이 끝날 때 핵심 개념 한 장 요약을 만들어 누적하세요.",
        ]

        if session.school_level == SchoolLevel.elementary:
            items.insert(0, "짧게 자주 공부하는 방식이 효과적이므로 한 번에 오래 하기보다 15~20분 단위로 나누어 학습하세요.")
        elif session.school_level == SchoolLevel.high:
            items.insert(0, "개념을 이해한 뒤 바로 문제에 적용하고, 함정 포인트를 분리해서 정리해야 실전 성과가 올라갑니다.")

        return items

    def _build_fallback_exam_analysis(self, topic: str, exam_content: str) -> str:
        keywords = _extract_keywords(exam_content)
        keyword_text = ", ".join(keywords) if keywords else "핵심 개념"

        return "\n".join(
            [
                "## 기출문제 분석",
                f"1. 자주 보이는 키워드: {keyword_text}",
                "2. 문제를 풀 때는 개념 암기 여부보다, 근거를 본문/자료에서 찾는 과정이 중요한 유형으로 보입니다.",
                "3. 정답 근거를 찾은 뒤 오답 선지가 왜 틀렸는지까지 설명할 수 있어야 실제 시험 대응력이 올라갑니다.",
                "4. 취약 영역은 용어 구분, 자료 해석, 서술 근거 정리 부분일 가능성이 높으니 별도로 체크하세요.",
                f"5. '{topic}' 학습에서는 기출문제를 단원별로 다시 묶어 유사 패턴을 반복 연습하는 전략이 효과적입니다.",
                "",
                "현재 분석은 로컬 가이드 기반이며, 실제 시험지 해설과 학교 수업자료를 함께 보면 더 정확합니다.",
            ]
        )

    def _build_fallback_mindmap(self, topic: str, content: str) -> str:
        keywords = _extract_keywords(content)
        if not keywords:
            keywords = ["핵심 개념", "세부 내용", "문제 적용"]

        lines = [f"# {topic}", "## 학습 구조"]
        for keyword in keywords[:5]:
            lines.extend(
                [
                    f"- {keyword}",
                    "  - 정의와 특징 정리",
                    "  - 예시 또는 자료 연결",
                    "  - 문제 적용 포인트 확인",
                ]
            )
        lines.extend(
            [
                "## 복습 포인트",
                "- 틀린 문제의 원인을 개념/자료 해석/표현 실수로 구분",
                "- 한 장 요약과 오답노트를 함께 업데이트",
            ]
        )
        return "\n".join(lines)

    def _parse_content_sections(self, text: str, topic: str) -> dict:
        sections = {
            "topic": topic,
            "concept_explanation": "",
            "concept_summary": "",
            "content_outline": "",
            "study_start_guide": "",
            "self_check_quiz": "",
            "recommended_problems": "",
            "study_direction": "",
            "full_text": text,
        }

        current_section = None
        lines = text.split("\n")

        for line in lines:
            stripped = line.strip()
            if "## 개념 설명" in stripped:
                current_section = "concept_explanation"
            elif "## 개념 요약" in stripped:
                current_section = "concept_summary"
            elif "## 내용 정리" in stripped:
                current_section = "content_outline"
            elif "## 오늘의 공부 시작" in stripped:
                current_section = "study_start_guide"
            elif "## 셀프 체크" in stripped:
                current_section = "self_check_quiz"
            elif "## 추천 문제" in stripped:
                current_section = "recommended_problems"
            elif "## 시험" in stripped or "## 자격증" in stripped or "## 학습 방향" in stripped:
                current_section = "study_direction"
            elif current_section and stripped:
                sections[current_section] += line + "\n"

        # Fallback: if parsing fails, put everything in concept_explanation
        if not any([
            sections["concept_explanation"],
            sections["concept_summary"],
            sections["content_outline"],
        ]):
            sections["concept_explanation"] = text

        return sections
