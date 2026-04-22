"""
API routes for StudyAgents.
"""

import uuid
from typing import Optional

from fastapi import APIRouter, HTTPException, status
from fastapi.responses import StreamingResponse
from pydantic import BaseModel, Field, field_validator

from app.models.study import (
    StudySessionCreate, StudyContent, StudyPlan,
    StudySession, NotificationSchedule,
)
from app.services.study_agent import StudyAgent
from app.services.plan_service import PlanService
from app.services import notification_service as notif

router = APIRouter()

# In-memory session store (replace with DB for production)
_sessions: dict[str, StudySession] = {}

study_agent = StudyAgent()
plan_service = PlanService()


# ─── Session ──────────────────────────────────────────────────────────────────

@router.post(
    "/sessions",
    response_model=StudySession,
    status_code=status.HTTP_201_CREATED,
    tags=["Session"],
)
def create_session(session_in: StudySessionCreate):
    """Create a new study session and generate content via Gemini + search grounding."""
    session_id = str(uuid.uuid4())

    topic = study_agent.get_topic_description(session_in)

    # Generate content synchronously with Gemini search grounding when a key is configured.
    try:
        sections = study_agent.generate_content(session_in)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Content generation failed: {e}")

    # Analyze past exam if provided
    exam_direction = None
    if session_in.past_exam_content:
        try:
            exam_direction = study_agent.analyze_past_exam(
                topic, session_in.past_exam_content
            )
        except Exception:
            exam_direction = "기출 분석을 완료하지 못했습니다."

    content = StudyContent(
        session_id=session_id,
        topic=topic,
        concept_explanation=sections.get("concept_explanation", ""),
        concept_summary=sections.get("concept_summary", ""),
        content_outline=sections.get("content_outline", ""),
        study_start_guide=sections.get("study_start_guide", ""),
        self_check_quiz=sections.get("self_check_quiz", ""),
        recommended_problems=sections.get("recommended_problems", ""),
        study_direction=exam_direction or sections.get("study_direction", ""),
    )

    session = StudySession(
        id=session_id,
        purpose=session_in.purpose,
        school_level=session_in.school_level,
        subject=session_in.subject,
        topic_description=topic,
        content=content,
        source_input=session_in,
    )
    _sessions[session_id] = session
    return session


@router.get("/sessions/{session_id}", response_model=StudySession, tags=["Session"])
def get_session(session_id: str):
    if session_id not in _sessions:
        raise HTTPException(status_code=404, detail="Session not found")
    return _sessions[session_id]


@router.get("/sessions", response_model=list[StudySession], tags=["Session"])
def list_sessions():
    return list(_sessions.values())


# ─── Streaming content ────────────────────────────────────────────────────────

@router.post("/sessions/stream", tags=["Session"])
def stream_content(session_in: StudySessionCreate):
    """Stream content generation in real-time (SSE-compatible)."""
    def generate():
        for chunk in study_agent.generate_content_stream(session_in):
            yield chunk

    return StreamingResponse(generate(), media_type="text/plain; charset=utf-8")


# ─── Study Plan ───────────────────────────────────────────────────────────────

@router.post("/sessions/{session_id}/plan", response_model=StudyPlan, tags=["Plan"])
def generate_plan(session_id: str):
    """Generate a study plan for an existing session."""
    if session_id not in _sessions:
        raise HTTPException(status_code=404, detail="Session not found")

    session = _sessions[session_id]
    if not session.content:
        raise HTTPException(status_code=400, detail="Generate content first")

    from app.models.study import StudySessionCreate as SC
    minimal_input = session.source_input or SC.model_construct(
        purpose=session.purpose,
        school_level=session.school_level,
        subject=session.subject,
    )

    summary = (
        session.content.concept_summary
        or session.content.concept_explanation[:1000]
    )

    try:
        plan = plan_service.generate_plan(
            session_id=session_id,
            session=minimal_input,
            content_summary=summary,
            topic=session.topic_description,
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Plan generation failed: {e}")

    _sessions[session_id].plan = plan
    return plan


class PlanRequest(BaseModel):
    days_remaining: Optional[int] = Field(default=14, ge=1, le=365)
    study_hours_per_day: Optional[dict[str, float]] = None

    @field_validator("study_hours_per_day", mode="before")
    @classmethod
    def validate_hours_map(cls, value: object) -> Optional[dict[str, float]]:
        if value is None:
            return None
        if not isinstance(value, dict):
            raise ValueError("요일별 공부 시간 형식이 올바르지 않습니다.")
        normalized: dict[str, float] = {}
        for day, hours in value.items():
            hour_value = float(hours)
            if hour_value < 0 or hour_value > 12:
                raise ValueError("요일별 공부 시간은 0시간 이상 12시간 이하여야 합니다.")
            normalized[day] = hour_value
        return normalized


@router.post("/sessions/{session_id}/plan/custom", response_model=StudyPlan, tags=["Plan"])
def generate_custom_plan(session_id: str, req: PlanRequest):
    """Generate a plan with custom schedule parameters."""
    if session_id not in _sessions:
        raise HTTPException(status_code=404, detail="Session not found")

    session = _sessions[session_id]

    from app.models.study import StudySessionCreate as SC

    base_input = session.source_input or SC.model_construct(
        purpose=session.purpose,
        school_level=session.school_level,
        subject=session.subject,
    )
    minimal_input = base_input.model_copy(
        update={
            "days_remaining": req.days_remaining,
            "study_hours_per_day": req.study_hours_per_day,
        }
    )

    summary = ""
    if session.content:
        summary = session.content.concept_summary or session.content.concept_explanation[:1000]

    try:
        plan = plan_service.generate_plan(
            session_id=session_id,
            session=minimal_input,
            content_summary=summary,
            topic=session.topic_description,
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Plan generation failed: {e}")

    _sessions[session_id].plan = plan
    return plan


# ─── Mind Map ─────────────────────────────────────────────────────────────────

@router.get("/sessions/{session_id}/mindmap", tags=["Content"])
def get_mindmap(session_id: str):
    """Generate a markdown mind map for the session content."""
    if session_id not in _sessions:
        raise HTTPException(status_code=404, detail="Session not found")

    session = _sessions[session_id]
    if not session.content:
        raise HTTPException(status_code=400, detail="No content available")

    content = session.content.content_outline or session.content.concept_explanation
    try:
        mindmap = study_agent.generate_mindmap(session.topic_description, content)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Mind map generation failed: {e}")

    return {"session_id": session_id, "mindmap": mindmap}


# ─── Past Exam Analysis ───────────────────────────────────────────────────────

class ExamAnalysisRequest(BaseModel):
    exam_content: str = Field(min_length=1)

    @field_validator("exam_content")
    @classmethod
    def validate_exam_content(cls, value: str) -> str:
        cleaned = value.strip()
        if not cleaned:
            raise ValueError("분석할 기출문제를 입력해주세요.")
        return cleaned


@router.post("/sessions/{session_id}/analyze-exam", tags=["Content"])
def analyze_exam(session_id: str, req: ExamAnalysisRequest):
    """Analyze user-provided past exam papers."""
    if session_id not in _sessions:
        raise HTTPException(status_code=404, detail="Session not found")

    session = _sessions[session_id]
    try:
        analysis = study_agent.analyze_past_exam(
            session.topic_description, req.exam_content
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Exam analysis failed: {e}")

    if session.content:
        session.content.study_direction = analysis

    return {"session_id": session_id, "analysis": analysis}


# ─── Notifications ────────────────────────────────────────────────────────────

class NotificationRequest(BaseModel):
    message: str = Field(min_length=1, max_length=120)
    time: str = "09:00"
    days: list[str] = Field(default_factory=lambda: ["월", "화", "수", "목", "금"])

    @field_validator("message")
    @classmethod
    def validate_message(cls, value: str) -> str:
        cleaned = " ".join(value.strip().split())
        if not cleaned:
            raise ValueError("알림 메시지를 입력해주세요.")
        return cleaned

    @field_validator("time")
    @classmethod
    def validate_time(cls, value: str) -> str:
        parts = value.split(":")
        if len(parts) != 2:
            raise ValueError("알림 시간은 HH:MM 형식이어야 합니다.")
        hour, minute = parts
        if not (hour.isdigit() and minute.isdigit()):
            raise ValueError("알림 시간은 HH:MM 형식이어야 합니다.")
        if int(hour) not in range(24) or int(minute) not in range(60):
            raise ValueError("유효한 알림 시간을 입력해주세요.")
        return f"{int(hour):02d}:{int(minute):02d}"

    @field_validator("days", mode="before")
    @classmethod
    def validate_days(cls, value: object) -> list[str]:
        if value is None:
            raise ValueError("알림 요일을 선택해주세요.")
        if not isinstance(value, list):
            raise ValueError("알림 요일 형식이 올바르지 않습니다.")
        valid_days = {"월", "화", "수", "목", "금", "토", "일"}
        cleaned: list[str] = []
        seen: set[str] = set()
        for day in value:
            label = str(day).strip()
            if label not in valid_days:
                raise ValueError("알림 요일 형식이 올바르지 않습니다.")
            if label in seen:
                continue
            cleaned.append(label)
            seen.add(label)
        if not cleaned:
            raise ValueError("알림 요일을 하나 이상 선택해주세요.")
        return cleaned


@router.post("/sessions/{session_id}/notifications", tags=["Notifications"])
def set_notification(session_id: str, req: NotificationRequest):
    """Schedule daily study notifications."""
    if session_id not in _sessions:
        raise HTTPException(status_code=404, detail="Session not found")

    schedule = notif.schedule_notifications(
        session_id=session_id,
        message=req.message,
        time_str=req.time,
        days=req.days,
    )
    _sessions[session_id].notifications_enabled = True
    return schedule


@router.delete("/sessions/{session_id}/notifications", tags=["Notifications"])
def cancel_notification(session_id: str):
    """Cancel scheduled notifications for a session."""
    cancelled = notif.cancel_notifications(session_id)
    if not cancelled:
        raise HTTPException(status_code=404, detail="No active notification found")
    if session_id in _sessions:
        _sessions[session_id].notifications_enabled = False
    return {"cancelled": True}


@router.get("/sessions/{session_id}/notifications", tags=["Notifications"])
def get_notification_status(session_id: str):
    schedule = notif.get_schedule(session_id)
    logs = notif.get_notification_log(session_id)
    return {"schedule": schedule, "recent_logs": logs[-10:]}


@router.get("/notifications/log", tags=["Notifications"])
def get_all_notifications():
    return {"logs": notif.get_notification_log()}
