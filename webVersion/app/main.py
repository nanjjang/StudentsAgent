from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.config import get_settings
from app.api.routes import router
from app.services.notification_service import start_scheduler, stop_scheduler


@asynccontextmanager
async def lifespan(app: FastAPI):
    start_scheduler()
    yield
    stop_scheduler()


settings = get_settings()

app = FastAPI(
    title=settings.app_title,
    description=(
        "StudyAgents API — AI 기반 학습 도우미 서비스\n\n"
        "초/중/고 학생을 위한 맞춤형 학습 자료 생성, 계획 수립, 알림 서비스를 제공합니다."
    ),
    version="1.0.0",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(router, prefix="/api/v1")


@app.get("/health")
def health_check():
    return {"status": "ok", "service": "StudyAgents"}
