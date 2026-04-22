"""
PlanService — Generates structured study plans using Gemini.
Outputs calendar/table format based on remaining days and available hours.
"""

import json
import logging
from datetime import datetime, timedelta

from google import genai
from google.genai import types

from app.config import get_settings
from app.models.study import SchoolLevel, StudySessionCreate, StudyPlan, StudyPlanItem, StudyPurpose

logger = logging.getLogger(__name__)

_DAY_NAMES = ["월", "화", "수", "목", "금", "토", "일"]
_DAY_EN = {
    "월": "Monday", "화": "Tuesday", "수": "Wednesday", "목": "Thursday",
    "금": "Friday", "토": "Saturday", "일": "Sunday",
}

_SCHOOL_LEVEL_LABEL = {
    SchoolLevel.elementary: "초등",
    SchoolLevel.middle: "중등",
    SchoolLevel.high: "고등",
}


def _get_day_of_week(date: datetime) -> str:
    return _DAY_NAMES[date.weekday()]


def _response_json_text(response: object) -> str:
    text = getattr(response, "text", None)
    if isinstance(text, str) and text.strip():
        return text

    parsed = getattr(response, "parsed", None)
    if parsed is not None:
        return json.dumps(parsed, ensure_ascii=False)

    return "[]"


class PlanService:
    def __init__(self):
        settings = get_settings()
        self.client = (
            genai.Client(api_key=settings.gemini_api_key)
            if settings.gemini_api_key
            else None
        )
        self.model = settings.gemini_text_model

    def _json_config(self, system_instruction: str) -> types.GenerateContentConfig:
        return types.GenerateContentConfig(
            system_instruction=system_instruction,
            response_mime_type="application/json",
            thinking_config=types.ThinkingConfig(thinking_budget=0),
        )

    def generate_plan(
        self,
        session_id: str,
        session: StudySessionCreate,
        content_summary: str,
        topic: str,
    ) -> StudyPlan:
        """Generate a structured study plan."""
        is_exam = session.purpose in (StudyPurpose.exam_prep, StudyPurpose.certification)

        if is_exam and session.days_remaining:
            plan_items = self._generate_exam_plan(session, content_summary, topic)
        else:
            plan_items = self._generate_general_plan(session, content_summary, topic)

        calendar_view = self._build_calendar_table(plan_items)

        return StudyPlan(
            session_id=session_id,
            purpose=session.purpose,
            total_days=len(plan_items),
            plan_items=plan_items,
            calendar_view=calendar_view,
        )

    def _generate_exam_plan(
        self,
        session: StudySessionCreate,
        content_summary: str,
        topic: str,
    ) -> list[StudyPlanItem]:
        days = session.days_remaining or 14
        hours_per_day = session.study_hours_per_day or {}
        if not self.client:
            return self._fallback_plan(days, hours_per_day, topic, exam_mode=True, school_level=session.school_level)

        prompt = f"""당신은 한국 학생을 위한 학습 플래너입니다.
다음 조건에 맞는 시험 대비 학습 계획표를 JSON 형식으로 생성해주세요.

학습 주제: {topic}
학교급: {_SCHOOL_LEVEL_LABEL[session.school_level]}
남은 기간: {days}일
요일별 공부 가능 시간: {json.dumps(hours_per_day, ensure_ascii=False)}

학습 내용 요약:
{content_summary[:2000]}

반드시 아래 JSON 배열 형식으로만 응답하세요 (마크다운 없이 순수 JSON):
[
  {{
    "day_index": 1,
    "day_of_week": "월",
    "topics": ["학습할 주제1", "학습할 주제2"],
    "study_hours": 2.0,
    "tasks": ["구체적인 할일1", "구체적인 할일2", "구체적인 할일3"]
  }}
]

총 {days}일치 계획을 생성해주세요. 후반부에는 복습과 문제풀이를 배치해주세요."""

        try:
            response = self.client.models.generate_content(
                model=self.model,
                contents=prompt,
                config=self._json_config(
                    "당신은 한국 학생을 위한 학습 플래너입니다. "
                    "응답은 반드시 JSON 배열만 반환하고, 각 날짜별 실천 가능한 학습 계획을 균형 있게 배치하세요."
                ),
            )
            text = _response_json_text(response)
            return self._parse_plan_json(
                text, days, hours_per_day, topic, exam_mode=True, school_level=session.school_level
            )
        except Exception:
            logger.exception("Falling back to local exam plan for topic: %s", topic)
            return self._fallback_plan(days, hours_per_day, topic, exam_mode=True, school_level=session.school_level)

    def _generate_general_plan(
        self,
        session: StudySessionCreate,
        content_summary: str,
        topic: str,
    ) -> list[StudyPlanItem]:
        days = session.days_remaining or 7
        if not self.client:
            return self._fallback_plan(days, {}, topic, exam_mode=False, school_level=session.school_level)

        prompt = f"""당신은 학습 플래너입니다.
다음 주제를 {days}일 동안 공부할 수 있는 학습 계획표를 JSON으로 생성해주세요.

학습 주제: {topic}
학교급: {_SCHOOL_LEVEL_LABEL[session.school_level]}
기간: {days}일

학습 내용:
{content_summary[:2000]}

JSON 배열 형식으로만 응답하세요:
[
  {{
    "day_index": 1,
    "day_of_week": "월",
    "topics": ["주제"],
    "study_hours": 1.5,
    "tasks": ["할일1", "할일2"]
  }}
]"""

        try:
            response = self.client.models.generate_content(
                model=self.model,
                contents=prompt,
                config=self._json_config(
                    "당신은 학습 플래너입니다. "
                    "응답은 반드시 JSON 배열만 반환하고, 개념 이해와 복습이 자연스럽게 이어지도록 일정을 구성하세요."
                ),
            )
            text = _response_json_text(response)
            return self._parse_plan_json(text, days, {}, topic, exam_mode=False, school_level=session.school_level)
        except Exception:
            logger.exception("Falling back to local general plan for topic: %s", topic)
            return self._fallback_plan(days, {}, topic, exam_mode=False, school_level=session.school_level)

    def _parse_plan_json(
        self,
        text: str,
        days: int,
        hours_map: dict,
        topic: str,
        exam_mode: bool,
        school_level: SchoolLevel,
    ) -> list[StudyPlanItem]:
        # Extract JSON array from text
        start = text.find("[")
        end = text.rfind("]") + 1
        if start == -1 or end == 0:
            return self._fallback_plan(days, hours_map, topic, exam_mode, school_level)

        try:
            raw_items = json.loads(text[start:end])
        except json.JSONDecodeError:
            return self._fallback_plan(days, hours_map, topic, exam_mode, school_level)

        today = datetime.now()
        items = []
        for i, raw in enumerate(raw_items[:days]):
            date = today + timedelta(days=i)
            dow = raw.get("day_of_week", _get_day_of_week(date))
            study_hours = raw.get("study_hours") or hours_map.get(dow, 1.5)
            items.append(StudyPlanItem(
                date=date.strftime("%Y-%m-%d"),
                day_of_week=dow,
                topics=raw.get("topics", []),
                study_hours=float(study_hours),
                tasks=raw.get("tasks", []),
            ))
        return items

    def _fallback_plan(
        self,
        days: int,
        hours_map: dict,
        topic: str,
        exam_mode: bool,
        school_level: SchoolLevel,
    ) -> list[StudyPlanItem]:
        today = datetime.now()
        items = []
        for i in range(days):
            date = today + timedelta(days=i)
            dow = _get_day_of_week(date)
            phase = i / max(days, 1)
            if exam_mode:
                if phase < 0.5:
                    topics = [f"{topic} 핵심 개념 정리", "기초 유형 확인"]
                    tasks = self._phase_tasks(school_level, "foundation")
                elif phase < 0.8:
                    topics = [f"{topic} 유형 적용", "문제 풀이"]
                    tasks = self._phase_tasks(school_level, "practice")
                else:
                    topics = [f"{topic} 실전 점검", "최종 복습"]
                    tasks = self._phase_tasks(school_level, "review")
            else:
                if phase < 0.5:
                    topics = [f"{topic} 개념 이해", "기본 정리"]
                    tasks = self._phase_tasks(school_level, "general_start")
                else:
                    topics = [f"{topic} 응용 학습", "복습"]
                    tasks = self._phase_tasks(school_level, "general_review")

            items.append(StudyPlanItem(
                date=date.strftime("%Y-%m-%d"),
                day_of_week=dow,
                topics=topics,
                study_hours=float(hours_map.get(dow, 1.5)),
                tasks=tasks,
            ))
        return items

    def _phase_tasks(self, school_level: SchoolLevel, phase: str) -> list[str]:
        if school_level == SchoolLevel.elementary:
            mapping = {
                "foundation": ["교과서 읽기", "핵심 말 바꾸기", "쉬운 확인 문제 풀기"],
                "practice": ["대표 문제 풀기", "틀린 이유 말하기", "헷갈린 개념 다시 보기"],
                "review": ["짧은 실전 문제 풀기", "오답 다시 보기", "오늘 배운 것 말하기"],
                "general_start": ["개념 읽기", "중요한 말 표시", "짧은 확인 문제 풀기"],
                "general_review": ["예시 다시 보기", "헷갈린 내용 정리", "셀프 테스트"],
            }
        elif school_level == SchoolLevel.high:
            mapping = {
                "foundation": ["교과서/개념서 정리", "출제 포인트 요약", "대표 예제 풀이"],
                "practice": ["유형별 문제 풀이", "오답 원인 분류", "약점 개념 압축 복습"],
                "review": ["실전 문제 세트 풀이", "오답 회수 복습", "시험 직전 체크리스트 정리"],
                "general_start": ["개념 읽기", "핵심 정의 정리", "기본 문제 풀이"],
                "general_review": ["예제 적용", "함정 포인트 재정리", "셀프 테스트"],
            }
        else:
            mapping = {
                "foundation": ["교과서/노트 정리", "핵심 개념 요약", "대표 예제 풀이"],
                "practice": ["유형별 문제 풀이", "오답 원인 분류", "약점 개념 복습"],
                "review": ["실전 문제 세트 풀이", "오답 회수 복습", "시험 직전 체크리스트 정리"],
                "general_start": ["개념 읽기", "핵심 용어 정리", "짧은 확인 문제 풀이"],
                "general_review": ["예제 적용", "헷갈린 내용 재정리", "셀프 테스트"],
            }
        return mapping[phase]

    def _build_calendar_table(self, items: list[StudyPlanItem]) -> str:
        if not items:
            return ""

        lines = [
            "| 날짜 | 요일 | 학습 주제 | 학습 시간 | 할 일 |",
            "|------|------|-----------|-----------|-------|",
        ]
        for item in items:
            topics = ", ".join(item.topics)
            tasks = " / ".join(item.tasks[:3])  # Max 3 tasks in table
            lines.append(
                f"| {item.date} | {item.day_of_week} | {topics} "
                f"| {item.study_hours}h | {tasks} |"
            )
        return "\n".join(lines)
