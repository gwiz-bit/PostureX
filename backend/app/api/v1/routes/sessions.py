"""Route /sessions — đọc lịch sử buổi tập được ghi bởi realtime.py."""

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.crud.session import get_session_detail, list_sessions
from app.models.user import User
from app.schemas.session import SessionDetailOut, SessionListItemOut
from app.utils.deps import get_current_user

router = APIRouter(prefix="/sessions", tags=["sessions"])


@router.get("", response_model=list[SessionListItemOut])
async def get_sessions(
    limit: int = Query(20, ge=1, le=100),
    offset: int = Query(0, ge=0),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return await list_sessions(db, user_id=current_user.id, limit=limit, offset=offset)


@router.get("/{session_id}", response_model=SessionDetailOut)
async def get_session(
    session_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    session = await get_session_detail(db, session_id=session_id, user_id=current_user.id)
    if session is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Không tìm thấy phiên tập.")
    return session
