from datetime import datetime
from enum import Enum
from typing import Literal, Optional

from pydantic import BaseModel, Field, field_validator, model_validator


_VALID_DAYS = ("월", "화", "수", "목", "금", "토", "일")


def _clean_text(value: str) -> str:
    return " ".join(value.strip().split())


def _clean_optional_text(value: Optional[str]) -> Optional[str]:
    if value is None:
        return None
    cleaned = " ".join(value.strip().split())
    return cleaned or None


def _normalize_day_map(value: Optional[dict[str, float]]) -> Optional[dict[str, float]]:
    if value is None:
        return None

    normalized: dict[str, float] = {}
    for day in _VALID_DAYS:
        if day not in value:
            continue
        hours = float(value[day])
        if hours < 0 or hours > 12:
            raise ValueError("요일별 공부 시간은 0시간 이상 12시간 이하여야 합니다.")
        normalized[day] = hours

    if not normalized:
        raise ValueError("최소 한 요일의 공부 시간을 입력해주세요.")

    return normalized


def _dedupe_preserve_order(items: list[str]) -> list[str]:
    deduped: list[str] = []
    seen: set[str] = set()
    for item in items:
        if item in seen:
            continue
        deduped.append(item)
        seen.add(item)
    return deduped


class StudyPurpose(str, Enum):
    exam_prep = "exam_prep"
    certification = "certification"
    background = "background"
    general = "general"


class SchoolLevel(str, Enum):
    elementary = "elementary"
    middle = "middle"
    high = "high"


class Subject(str, Enum):
    korean = "korean"
    english = "english"
    math = "math"
    science = "science"
    social = "social"
    history = "history"
    japanese = "japanese"
    chinese = "chinese"
    cs = "cs"
    data_science = "data_science"
    data_structure = "data_structure"
    computer_system = "computer_system"
    networking = "networking"
    music = "music"
    other = "other"


class KoreanInput(BaseModel):
    text_name: str
    concepts: list[str] = Field(default_factory=list)

    @field_validator("text_name")
    @classmethod
    def validate_text_name(cls, value: str) -> str:
        cleaned = _clean_text(value)
        if not cleaned:
            raise ValueError("작품 또는 지문 이름을 입력해주세요.")
        return cleaned

    @field_validator("concepts", mode="before")
    @classmethod
    def normalize_concepts(cls, value: object) -> list[str]:
        if value is None:
            return []
        if not isinstance(value, list):
            raise ValueError("개념 목록 형식이 올바르지 않습니다.")

        cleaned = [_clean_text(str(item)) for item in value if str(item).strip()]
        return _dedupe_preserve_order(cleaned)


class EnglishMockExamInput(BaseModel):
    grade: int = Field(ge=1, le=6)
    year: int = Field(ge=2010, le=2035)
    month: int = Field(ge=1, le=12)
    question_numbers: list[int] = Field(default_factory=list)

    @field_validator("question_numbers", mode="before")
    @classmethod
    def normalize_question_numbers(cls, value: object) -> list[int]:
        if value is None:
            return []
        if not isinstance(value, list):
            raise ValueError("지문 번호 형식이 올바르지 않습니다.")

        numbers: list[int] = []
        seen: set[int] = set()
        for raw in value:
            num = int(raw)
            if num <= 0:
                raise ValueError("지문 번호는 1 이상이어야 합니다.")
            if num in seen:
                continue
            numbers.append(num)
            seen.add(num)
        return numbers


class EnglishTextbookInput(BaseModel):
    publisher: str
    author: str
    grade: int = Field(ge=1, le=6)
    semester: int = Field(ge=1, le=2)
    chapter: str
    section: str

    @field_validator("publisher", "author", "chapter", "section")
    @classmethod
    def validate_required_text(cls, value: str) -> str:
        cleaned = _clean_text(value)
        if not cleaned:
            raise ValueError("필수 교과서 정보를 모두 입력해주세요.")
        return cleaned


class EnglishInput(BaseModel):
    input_type: Literal["mock_exam", "textbook"]
    mock_exam: Optional[EnglishMockExamInput] = None
    textbook: Optional[EnglishTextbookInput] = None

    @model_validator(mode="after")
    def validate_selected_input(self) -> "EnglishInput":
        if self.input_type == "mock_exam" and not self.mock_exam:
            raise ValueError("영어 모의고사 정보를 입력해주세요.")
        if self.input_type == "textbook" and not self.textbook:
            raise ValueError("영어 교과서 정보를 입력해주세요.")
        return self


class TextbookInput(BaseModel):
    publisher: str
    author: str
    grade: int = Field(ge=1, le=6)
    semester: Optional[int] = Field(default=None, ge=1, le=2)
    chapter: str

    @field_validator("publisher", "author", "chapter")
    @classmethod
    def validate_required_text(cls, value: str) -> str:
        cleaned = _clean_text(value)
        if not cleaned:
            raise ValueError("교과서 정보를 모두 입력해주세요.")
        return cleaned


class CSInput(BaseModel):
    publisher: str
    author: str
    grade: int = Field(ge=1, le=6)
    semester: Optional[int] = Field(default=None, ge=1, le=2)
    chapter: str
    related_files: list[str] = Field(default_factory=list)

    @field_validator("publisher", "author", "chapter")
    @classmethod
    def validate_required_text(cls, value: str) -> str:
        cleaned = _clean_text(value)
        if not cleaned:
            raise ValueError("정보과학 학습 정보를 모두 입력해주세요.")
        return cleaned

    @field_validator("related_files", mode="before")
    @classmethod
    def normalize_related_files(cls, value: object) -> list[str]:
        if value is None:
            return []
        if not isinstance(value, list):
            raise ValueError("관련 파일 형식이 올바르지 않습니다.")
        cleaned = [_clean_text(str(item)) for item in value if str(item).strip()]
        return _dedupe_preserve_order(cleaned)


class StudySessionCreate(BaseModel):
    purpose: StudyPurpose
    school_level: SchoolLevel
    subject: Subject
    korean_input: Optional[KoreanInput] = None
    english_input: Optional[EnglishInput] = None
    textbook_input: Optional[TextbookInput] = None
    cs_input: Optional[CSInput] = None
    other_description: Optional[str] = None
    past_exam_content: Optional[str] = None
    days_remaining: Optional[int] = Field(default=None, ge=1, le=365)
    study_hours_per_day: Optional[dict[str, float]] = None

    @field_validator("other_description", "past_exam_content", mode="before")
    @classmethod
    def normalize_optional_text(cls, value: object) -> Optional[str]:
        if value is None:
            return None
        return _clean_optional_text(str(value))

    @field_validator("study_hours_per_day", mode="before")
    @classmethod
    def validate_hours_map(cls, value: object) -> Optional[dict[str, float]]:
        if value is None:
            return None
        if not isinstance(value, dict):
            raise ValueError("요일별 공부 시간 형식이 올바르지 않습니다.")
        return _normalize_day_map(value)

    @model_validator(mode="after")
    def validate_subject_inputs(self) -> "StudySessionCreate":
        textbook_subjects = {
            Subject.math,
            Subject.science,
            Subject.social,
            Subject.history,
            Subject.japanese,
            Subject.chinese,
            Subject.music,
        }
        cs_subjects = {
            Subject.cs,
            Subject.data_science,
            Subject.data_structure,
            Subject.computer_system,
            Subject.networking,
        }

        if self.subject == Subject.korean and not self.korean_input:
            raise ValueError("국어 학습 정보가 필요합니다.")
        if self.subject == Subject.english and not self.english_input:
            raise ValueError("영어 학습 정보가 필요합니다.")
        if self.subject in textbook_subjects and not self.textbook_input:
            raise ValueError("교과서 학습 정보가 필요합니다.")
        if self.subject in cs_subjects and not self.cs_input:
            raise ValueError("정보과학 학습 정보가 필요합니다.")
        if self.subject == Subject.other and not self.other_description:
            raise ValueError("학습 내용을 입력해주세요.")

        if self.study_hours_per_day and not any(hours > 0 for hours in self.study_hours_per_day.values()):
            raise ValueError("최소 하루 이상의 공부 시간을 입력해주세요.")

        return self


class StudyContent(BaseModel):
    session_id: str
    topic: str
    concept_explanation: str
    concept_summary: str
    content_outline: str
    study_start_guide: str
    self_check_quiz: str
    recommended_problems: str
    study_direction: Optional[str] = None
    created_at: datetime = Field(default_factory=datetime.now)


class StudyPlanItem(BaseModel):
    date: str
    day_of_week: str
    topics: list[str] = Field(default_factory=list)
    study_hours: float
    tasks: list[str] = Field(default_factory=list)


class StudyPlan(BaseModel):
    session_id: str
    purpose: StudyPurpose
    total_days: int
    plan_items: list[StudyPlanItem] = Field(default_factory=list)
    calendar_view: str
    created_at: datetime = Field(default_factory=datetime.now)


class StudySession(BaseModel):
    id: str
    purpose: StudyPurpose
    school_level: SchoolLevel
    subject: Subject
    topic_description: str
    content: Optional[StudyContent] = None
    plan: Optional[StudyPlan] = None
    notifications_enabled: bool = False
    created_at: datetime = Field(default_factory=datetime.now)
    source_input: Optional[StudySessionCreate] = Field(default=None, exclude=True)


class NotificationSchedule(BaseModel):
    session_id: str
    message: str
    scheduled_time: str
    days: list[str] = Field(default_factory=list)
