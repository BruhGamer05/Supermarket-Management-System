# app/config.py
# Reads settings from the .env file.
# Why: never hardcode secrets in source code. .env is gitignored.

from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    db_host: str = "localhost"
    db_port: int = 3306
    db_name: str = "supermarket_db"
    db_user: str = "root"
    db_password: str = "rootpass"

    jwt_secret: str = "change_this"
    jwt_algorithm: str = "HS256"
    jwt_expire_minutes: int = 480

    class Config:
        env_file = ".env"


settings = Settings()
