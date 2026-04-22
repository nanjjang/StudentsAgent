from functools import lru_cache
from typing import Optional

from pydantic import AliasChoices, Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    gemini_api_key: Optional[str] = Field(
        default=None,
        validation_alias=AliasChoices(
            "GEMINI_API_KEY",
            "GOOGLE_API_KEY",
            "gemini_api_key",
            "google_api_key",
        ),
    )
    gemini_content_model: str = "gemini-2.5-flash-lite"
    gemini_text_model: str = "gemini-2.5-flash-lite"
    database_url: str = "sqlite+aiosqlite:///./study_agents.db"
    app_title: str = "StudyAgents API"
    debug: bool = False

    model_config = SettingsConfigDict(env_file=".env", extra="ignore")


@lru_cache
def get_settings() -> Settings:
    return Settings()
