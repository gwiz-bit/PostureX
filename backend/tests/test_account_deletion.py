"""Xoá tài khoản: nút trong app (DELETE /users/me) và trang web /delete-account.

Chốt các cam kết đã nói công khai trong chính sách bảo mật:
- xoá THẬT (dòng DB biến mất, file video bị xoá khỏi ổ đĩa);
- hoá đơn đã thanh toán được giữ lại nhưng ẩn danh, đơn chưa/không thanh toán thì bị xoá;
- luồng web chỉ xoá được khi có đúng mã gửi tới email, chống đoán mò và dò email.
"""

from datetime import date, datetime
from decimal import Decimal

import pytest
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.core.security import hash_password
from app.crud import account_deletion as crud
from app.models.account_deletion import AccountDeletionRequest, PaymentArchive
from app.models.role import ADMIN_ROLE_NAME, Role
from app.models.subscription import Payment, UserSubscription
from app.models.user import User
from app.models.video import Video
from app.models.workout import Workout

pytestmark = pytest.mark.asyncio


@pytest.fixture
def sent_codes(monkeypatch) -> list[tuple[str, str]]:
    """Chặn gửi email thật, ghi lại (email, mã) để test đọc được mã."""
    sent: list[tuple[str, str]] = []

    async def fake_send(to_email: str, code: str, expire_minutes: int) -> None:
        sent.append((to_email, code))

    monkeypatch.setattr("app.api.v1.routes.account_deletion.send_account_deletion_email", fake_send)
    return sent


async def _give_data(db: AsyncSession, seeded: dict, tmp_path, monkeypatch) -> dict:
    """User có: 1 video (kèm file thật), 1 workout, 1 hoá đơn Completed, 1 hoá đơn Failed."""
    monkeypatch.setattr(settings, "VIDEO_STORAGE_PATH", str(tmp_path))
    user = seeded["user"]
    video_file = tmp_path / "abc.mp4"
    video_file.write_bytes(b"video-bytes")
    db.add(Video(user_id=user.id, exercise="squat", file_path=str(video_file)))
    db.add(Workout(user_id=user.id, exercise="squat", total_reps=5, accuracy_score=90.0,
                      started_at=datetime(2026, 9, 1, 8, 0)))
    sub = UserSubscription(
        user_id=user.id, plan_id=seeded["premium"].id, start_date=date.today(),
        status="Active", auto_renew=False,
    )
    db.add(sub)
    await db.flush()
    db.add(Payment(
        user_subscription_id=sub.id, transaction_no="MOMO123", amount=Decimal("99000"),
        currency="VND", payment_method="MoMo", status="Completed", paid_at=datetime(2026, 9, 1),
        gateway_log='{"email": "tester@posturex.com"}',
    ))
    db.add(Payment(
        user_subscription_id=sub.id, transaction_no="MOMO999", amount=Decimal("99000"),
        currency="VND", payment_method="MoMo", status="Failed",
    ))
    await db.commit()
    return {"video_file": video_file, "user_id": user.id}


async def _count(db: AsyncSession, model) -> int:
    return len((await db.execute(select(model))).scalars().all())


# ── Xoá trong app ──────────────────────────────────────────────────────────

async def test_delete_me_xoa_that_va_giu_hoa_don_an_danh(client, db_session, seeded, auth, tmp_path, monkeypatch):
    info = await _give_data(db_session, seeded, tmp_path, monkeypatch)

    resp = await client.delete("/api/v1/users/me", headers=auth)
    assert resp.status_code == 204

    assert await _count(db_session, User) == 0
    assert await _count(db_session, Video) == 0
    assert await _count(db_session, Workout) == 0
    assert await _count(db_session, UserSubscription) == 0
    assert await _count(db_session, Payment) == 0
    assert not info["video_file"].exists(), "file video phải bị xoá khỏi ổ đĩa"

    archived = (await db_session.execute(select(PaymentArchive))).scalars().all()
    assert len(archived) == 1, "chỉ hoá đơn đã thanh toán được giữ lại"
    row = archived[0]
    assert (row.transaction_no, row.plan_name, row.amount, row.status) == (
        "MOMO123", "Premium", Decimal("99000"), "Completed",
    )
    # Ẩn danh: bảng không có cột nào dẫn tới người dùng.
    assert {c.name for c in PaymentArchive.__table__.columns}.isdisjoint(
        {"user_id", "UserId", "email", "gateway_log", "PaymentGatewayLog"}
    )


async def test_delete_me_can_dang_nhap(client):
    assert (await client.delete("/api/v1/users/me")).status_code in (401, 403)


async def test_delete_me_khong_xoa_file_ngoai_thu_muc_luu_video(
    client, db_session, seeded, auth, tmp_path, monkeypatch
):
    storage = tmp_path / "storage"
    storage.mkdir()
    outside = tmp_path / "keep.txt"
    outside.write_text("khong duoc xoa")
    monkeypatch.setattr(settings, "VIDEO_STORAGE_PATH", str(storage))
    db_session.add(Video(user_id=seeded["user"].id, exercise="squat", file_path=str(outside)))
    await db_session.commit()

    assert (await client.delete("/api/v1/users/me", headers=auth)).status_code == 204
    assert outside.exists()


# ── Xoá qua web ────────────────────────────────────────────────────────────

async def test_trang_delete_account_phuc_vu_cong_khai(client):
    resp = await client.get("/delete-account")
    assert resp.status_code == 200
    assert "text/html" in resp.headers["content-type"]
    assert "Dữ liệu nào được giữ lại" in resp.text


async def test_request_email_la_khong_lo_thong_tin(client, seeded, sent_codes):
    known = await client.post("/api/v1/account-deletion/request", json={"email": "tester@posturex.com"})
    unknown = await client.post("/api/v1/account-deletion/request", json={"email": "ghost@posturex.com"})
    assert known.status_code == unknown.status_code == 200
    assert known.json() == unknown.json()
    assert [e for e, _ in sent_codes] == ["tester@posturex.com"]


async def test_luong_web_day_du_xoa_ngay(client, db_session, seeded, sent_codes, tmp_path, monkeypatch):
    info = await _give_data(db_session, seeded, tmp_path, monkeypatch)
    await client.post("/api/v1/account-deletion/request", json={"email": "tester@posturex.com"})
    code = sent_codes[0][1]

    resp = await client.post(
        "/api/v1/account-deletion/confirm", json={"email": "tester@posturex.com", "code": code}
    )
    assert resp.status_code == 200
    assert await _count(db_session, User) == 0
    assert await _count(db_session, AccountDeletionRequest) == 0
    assert not info["video_file"].exists()
    assert await _count(db_session, PaymentArchive) == 1


async def test_ma_sai_bi_tu_choi_va_khong_xoa(client, db_session, seeded, sent_codes):
    await client.post("/api/v1/account-deletion/request", json={"email": "tester@posturex.com"})
    wrong = "000000" if sent_codes[0][1] != "000000" else "111111"

    resp = await client.post(
        "/api/v1/account-deletion/confirm", json={"email": "tester@posturex.com", "code": wrong}
    )
    assert resp.status_code == 400
    assert await _count(db_session, User) == 1


async def test_email_khong_ton_tai_cung_bao_ma_sai(client, seeded):
    resp = await client.post(
        "/api/v1/account-deletion/confirm", json={"email": "ghost@posturex.com", "code": "123456"}
    )
    assert resp.status_code == 400


async def test_thu_qua_so_lan_thi_ma_dung_cung_bi_huy(client, db_session, seeded, sent_codes):
    await client.post("/api/v1/account-deletion/request", json={"email": "tester@posturex.com"})
    real = sent_codes[0][1]
    wrong = "000000" if real != "000000" else "111111"

    for _ in range(crud.MAX_ATTEMPTS):
        r = await client.post(
            "/api/v1/account-deletion/confirm", json={"email": "tester@posturex.com", "code": wrong}
        )
        assert r.status_code == 400

    r = await client.post(
        "/api/v1/account-deletion/confirm", json={"email": "tester@posturex.com", "code": real}
    )
    assert r.status_code == 400, "đã hết lượt thử thì mã đúng cũng không dùng được"
    assert await _count(db_session, User) == 1


async def test_ma_het_han_bi_tu_choi(client, db_session, seeded, sent_codes):
    await client.post("/api/v1/account-deletion/request", json={"email": "tester@posturex.com"})
    req = (await db_session.execute(select(AccountDeletionRequest))).scalar_one()
    req.expires_at = datetime(2020, 1, 1)
    await db_session.commit()

    r = await client.post(
        "/api/v1/account-deletion/confirm",
        json={"email": "tester@posturex.com", "code": sent_codes[0][1]},
    )
    assert r.status_code == 400
    assert await _count(db_session, User) == 1


async def test_gui_lien_tuc_chi_gui_mot_ma(client, seeded, sent_codes):
    for _ in range(3):
        await client.post("/api/v1/account-deletion/request", json={"email": "tester@posturex.com"})
    assert len(sent_codes) == 1


async def test_ma_luu_dang_bam_khong_luu_ma_goc(client, db_session, seeded, sent_codes):
    await client.post("/api/v1/account-deletion/request", json={"email": "tester@posturex.com"})
    req = (await db_session.execute(select(AccountDeletionRequest))).scalar_one()
    assert sent_codes[0][1] not in req.code_hash
    assert len(req.code_hash) == 64


async def test_admin_khong_xoa_duoc_qua_web(client, db_session, seeded, sent_codes):
    db_session.add(Role(id=1, name=ADMIN_ROLE_NAME))
    await db_session.flush()
    db_session.add(User(
        role_id=1, username="boss", email="boss@posturex.com",
        hashed_password=hash_password("Test123"), is_email_verified=True, is_active=True,
    ))
    await db_session.commit()

    await client.post("/api/v1/account-deletion/request", json={"email": "boss@posturex.com"})
    assert sent_codes == []
