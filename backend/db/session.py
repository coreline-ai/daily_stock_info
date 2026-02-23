from __future__ import annotations

import os
from contextlib import contextmanager

from sqlalchemy import create_engine
from sqlalchemy.orm import Session, sessionmaker
from dotenv import load_dotenv

from db.models import Base

load_dotenv()
DATABASE_URL = os.getenv("DATABASE_URL", "").strip()

_engine = create_engine(DATABASE_URL, future=True, pool_pre_ping=True) if DATABASE_URL else None
_SessionLocal = sessionmaker(bind=_engine, autoflush=False, autocommit=False, expire_on_commit=False) if _engine else None


def is_db_enabled() -> bool:
    return _engine is not None and _SessionLocal is not None


def init_db() -> None:
    if not is_db_enabled():
        return
    Base.metadata.create_all(bind=_engine)


@contextmanager
def session_scope() -> Session:
    if not is_db_enabled():
        raise RuntimeError("Database is not configured. Set DATABASE_URL.")
    session = _SessionLocal()
    try:
        yield session
        session.commit()
    except Exception:
        session.rollback()
        raise
    finally:
        session.close()
