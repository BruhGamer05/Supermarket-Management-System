# app/auth.py
# Handles password hashing and JWT token creation/verification.
#
# Why bcrypt? It's slow by design — makes brute-forcing hashes very hard.
# Why JWT? Tokens are stateless — the server doesn't need to store sessions.
#   The token encodes the user's ID and role; the server just verifies the signature.

import bcrypt
import jwt as pyjwt
from datetime import datetime, timedelta, timezone
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from app.config import settings

bearer_scheme = HTTPBearer()


# ── Password helpers ──────────────────────────────────────────

def hash_password(plain: str) -> str:
    """Hash a plain-text password with bcrypt. Returns the hash string."""
    return bcrypt.hashpw(plain.encode(), bcrypt.gensalt()).decode()


def verify_password(plain: str, hashed: str) -> bool:
    """Return True if plain matches the stored bcrypt hash."""
    return bcrypt.checkpw(plain.encode(), hashed.encode())


# ── JWT helpers ───────────────────────────────────────────────

def create_token(user_id: int, username: str, role: str) -> str:
    """Create a signed JWT that expires after JWT_EXPIRE_MINUTES."""
    payload = {
        "sub": str(user_id),
        "username": username,
        "role": role,
        "exp": datetime.now(timezone.utc) + timedelta(minutes=settings.jwt_expire_minutes),
    }
    return pyjwt.encode(payload, settings.jwt_secret, algorithm=settings.jwt_algorithm)


def decode_token(token: str) -> dict:
    """Decode and verify a JWT. Raises HTTPException if invalid/expired."""
    try:
        return pyjwt.decode(token, settings.jwt_secret, algorithms=[settings.jwt_algorithm])
    except pyjwt.ExpiredSignatureError:
        raise HTTPException(status_code=401, detail="Token expired. Please log in again.")
    except pyjwt.InvalidTokenError:
        raise HTTPException(status_code=401, detail="Invalid token.")


# ── FastAPI dependencies (role guards) ────────────────────────

def get_current_user(creds: HTTPAuthorizationCredentials = Depends(bearer_scheme)) -> dict:
    """Dependency: decodes the Bearer token and returns the payload dict."""
    return decode_token(creds.credentials)


def require_role(*roles: str):
    """
    Dependency factory: enforces that the caller has one of the allowed roles.
    Usage:  Depends(require_role("Owner", "Employee"))
    """
    def check(user: dict = Depends(get_current_user)):
        if user["role"] not in roles:
            raise HTTPException(
                status_code=403,
                detail=f"Access denied. Required role: {' or '.join(roles)}."
            )
        return user
    return check
