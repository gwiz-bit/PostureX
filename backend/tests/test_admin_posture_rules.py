"""Test route admin chỉnh ngưỡng tư thế theo từng bài tập.

Cặp route `/admin/config` cũ **không có test nào** — và đó chính là lý do 4
trong 7 ô điều khiển của màn hình cũ không có tác dụng mà không ai phát hiện:
mọi thứ vẫn trả 200, giao diện vẫn hiện "đã lưu", chỉ có hành vi phân tích là
không đổi. File này khoá lại điều mà bản cũ thiếu: **giá trị lưu xuống phải
thật sự tới được analyzer**.
"""

import pytest
import pytest_asyncio
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.security import create_access_token, hash_password
from app.ml.analyzers.thresholds import load_thresholds
from app.models.exercise import Exercise
from app.models.posture_rule import ExercisePostureRule
from app.models.role import ADMIN_ROLE_NAME, USER_ROLE_NAME, Role
from app.models.user import User

URL = "/api/v1/admin/posture-rules"


@pytest_asyncio.fixture
async def admin_setup(db_session: AsyncSession) -> dict:
    """Một admin, một user thường, và ba bài tập có analyzer khác nhau."""
    db_session.add_all([
        Role(id=1, name=ADMIN_ROLE_NAME),
        Role(id=2, name=USER_ROLE_NAME),
    ])
    await db_session.flush()

    admin = User(
        role_id=1, username="boss", email="boss@posturex.com",
        hashed_password=hash_password("Test123"),
        is_email_verified=True, is_active=True,
    )
    thuong = User(
        role_id=2, username="ai_do", email="aido@posturex.com",
        hashed_password=hash_password("Test123"),
        is_email_verified=True, is_active=True,
    )
    # "Squat" và "Barbell Squat" cùng dùng SquatAnalyzer — cặp này để chứng
    # minh ghi đè chỉ áp cho đúng một bài. "Plank" dùng analyzer khác hẳn.
    squat = Exercise(name="Squat", is_active=True)
    barbell_squat = Exercise(name="Barbell Squat", is_active=True)
    plank = Exercise(name="Plank", is_active=True)
    # Bài không có analyzer — không được xuất hiện trong danh sách.
    cardio = Exercise(name="Rowing Machine Steady State", is_active=True)
    db_session.add_all([admin, thuong, squat, barbell_squat, plank, cardio])
    await db_session.commit()

    return {
        "admin": {"Authorization": f"Bearer {create_access_token(str(admin.id))}"},
        "thuong": {"Authorization": f"Bearer {create_access_token(str(thuong.id))}"},
        "squat": squat, "barbell_squat": barbell_squat,
        "plank": plank, "cardio": cardio,
    }


# ─────────────────────────────────────────────────────────────────────
# Phân quyền
# ─────────────────────────────────────────────────────────────────────

@pytest.mark.asyncio
async def test_khong_dang_nhap_bi_tu_choi(client: AsyncClient, admin_setup: dict) -> None:
    assert (await client.get(URL)).status_code in (401, 403)


@pytest.mark.asyncio
async def test_user_thuong_bi_tu_choi(client: AsyncClient, admin_setup: dict) -> None:
    """Ngưỡng phân tích áp cho mọi người dùng — không phải thứ user tự chỉnh."""
    resp = await client.get(URL, headers=admin_setup["thuong"])

    assert resp.status_code == 403


# ─────────────────────────────────────────────────────────────────────
# Danh sách bài tập
# ─────────────────────────────────────────────────────────────────────

@pytest.mark.asyncio
async def test_chi_liet_ke_bai_co_analyzer(client: AsyncClient, admin_setup: dict) -> None:
    """Bài không phân tích được không có ngưỡng nào để chỉnh.

    Đưa vào danh sách chỉ khiến admin chỉnh xong tưởng có tác dụng — đúng loại
    lỗi im lặng mà cả màn hình này sinh ra để dẹp.
    """
    resp = await client.get(URL, headers=admin_setup["admin"])

    ten = {e["name"] for e in resp.json()}
    assert ten == {"Squat", "Barbell Squat", "Plank"}
    assert "Rowing Machine Steady State" not in ten


@pytest.mark.asyncio
async def test_danh_sach_kem_ten_analyzer(client: AsyncClient, admin_setup: dict) -> None:
    resp = await client.get(URL, headers=admin_setup["admin"])

    theo_ten = {e["name"]: e for e in resp.json()}
    assert theo_ten["Squat"]["analyzer"] == "SquatAnalyzer"
    assert theo_ten["Barbell Squat"]["analyzer"] == "SquatAnalyzer"
    assert theo_ten["Plank"]["analyzer"] == "PlankAnalyzer"


@pytest.mark.asyncio
async def test_dem_so_nguong_dang_ghi_de(client: AsyncClient, admin_setup: dict) -> None:
    """Admin cần thấy ngay bài nào đã đụng vào, bài nào còn nguyên mặc định."""
    sq = admin_setup["squat"].id
    await client.put(URL + f"/{sq}", headers=admin_setup["admin"],
                     json={"values": {"knee_depth": 88.0, "back_straight_min": 145.0}})

    resp = await client.get(URL, headers=admin_setup["admin"])

    theo_ten = {e["name"]: e for e in resp.json()}
    assert theo_ten["Squat"]["override_count"] == 2
    assert theo_ten["Barbell Squat"]["override_count"] == 0


@pytest.mark.asyncio
async def test_khong_dem_dong_ten_mo_ta(client: AsyncClient, admin_setup: dict, db_session: AsyncSession) -> None:
    """Schema gốc seed sẵn vài dòng đặt tên tiếng Việt mô tả, không phải khoá máy.

    `load_thresholds` bỏ qua chúng lúc chạy, nên đếm vào sẽ báo cho admin một
    con số cao hơn số ngưỡng thật sự có hiệu lực.
    """
    db_session.add(ExercisePostureRule(
        exercise_id=admin_setup["squat"].id,
        rule_name="Góc đầu gối (hip-knee-ankle)",
        joint_a="Hip", joint_b="Knee", joint_c="Ankle",
        min_angle=70, max_angle=100,
    ))
    await db_session.flush()

    resp = await client.get(URL, headers=admin_setup["admin"])

    theo_ten = {e["name"]: e for e in resp.json()}
    assert theo_ten["Squat"]["override_count"] == 0


@pytest.mark.asyncio
async def test_loc_theo_ten(client: AsyncClient, admin_setup: dict) -> None:
    """106 bài phân tích được là quá dài để cuộn tay."""
    resp = await client.get(URL, params={"search": "plank"}, headers=admin_setup["admin"])

    assert [e["name"] for e in resp.json()] == ["Plank"]


# ─────────────────────────────────────────────────────────────────────
# Đọc ngưỡng của một bài
# ─────────────────────────────────────────────────────────────────────

@pytest.mark.asyncio
async def test_bai_chua_ghi_de_hien_mac_dinh(client: AsyncClient, admin_setup: dict) -> None:
    """`current` rỗng nghĩa là đang chạy bằng mặc định của analyzer.

    Phân biệt "chưa đụng vào" với "đã đặt đúng bằng giá trị mặc định" là điều
    kiện để nút gỡ ghi đè có nghĩa.
    """
    resp = await client.get(f"{URL}/{admin_setup['squat'].id}", headers=admin_setup["admin"])

    body = resp.json()
    assert body["analyzer"] == "SquatAnalyzer"
    theo_khoa = {t["key"]: t for t in body["tunables"]}
    assert set(theo_khoa) == {
        "knee_depth", "stand_up_min", "back_straight_min", "knee_overshoot",
    }
    assert theo_khoa["knee_depth"]["default"] == 95.0
    assert theo_khoa["knee_depth"]["current"] is None


@pytest.mark.asyncio
async def test_nguong_ti_le_khong_bi_gan_don_vi_do(client: AsyncClient, admin_setup: dict) -> None:
    """`knee_overshoot` là khoá DUY NHẤT không phải góc.

    Nó là tỉ lệ theo chiều rộng khung hình (0.05 = 5%), nên giao diện không
    được gắn "°" vào — "0.05°" khiến admin hiểu sai hoàn toàn thứ mình chỉnh.
    Bước nhảy cũng phải nhỏ hơn nhiều so với 1° của các ngưỡng góc.
    """
    resp = await client.get(f"{URL}/{admin_setup['squat'].id}", headers=admin_setup["admin"])

    theo_khoa = {t["key"]: t for t in resp.json()["tunables"]}
    assert theo_khoa["knee_overshoot"]["unit"] == ""
    assert theo_khoa["knee_overshoot"]["step"] == 0.01
    assert theo_khoa["knee_depth"]["unit"] == "°"
    assert theo_khoa["knee_depth"]["step"] == 1.0


@pytest.mark.asyncio
async def test_nguong_ti_le_luu_va_doc_lai_dung_gia_tri(
    client: AsyncClient, admin_setup: dict, db_session: AsyncSession
) -> None:
    """Khoá này lấy giá trị từ cột `Tolerance`, không phải Min/MaxAngle.

    Nhầm cột thì giá trị vẫn lưu được nhưng `load_thresholds` đọc ra `None` và
    bỏ qua — hỏng im lặng. Và vì cột là `Numeric(5,2)`, giá trị nhỏ như 0.05
    phải sống sót qua vòng ghi/đọc chứ không được làm tròn thành 0.
    """
    sq = admin_setup["squat"].id
    await client.put(f"{URL}/{sq}", headers=admin_setup["admin"],
                     json={"values": {"knee_overshoot": 0.12}})

    assert await load_thresholds(db_session, "Squat") == {"knee_overshoot": 0.12}


@pytest.mark.asyncio
async def test_analyzer_khac_lo_bo_khoa_khac(client: AsyncClient, admin_setup: dict) -> None:
    """Đây là thứ màn hình cũ hoàn toàn không làm được — nó chỉ có squat."""
    resp = await client.get(f"{URL}/{admin_setup['plank'].id}", headers=admin_setup["admin"])

    khoa = {t["key"] for t in resp.json()["tunables"]}
    assert khoa == {"straight_body_min", "hip_sag"}


@pytest.mark.asyncio
async def test_danh_dau_nguong_anh_huong_dem_rep(client: AsyncClient, admin_setup: dict) -> None:
    """Đổi ngưỡng đếm rep nguy hiểm hơn đổi ngưỡng chấm điểm — giao diện phải
    phân biệt được để cảnh báo."""
    resp = await client.get(f"{URL}/{admin_setup['squat'].id}", headers=admin_setup["admin"])

    theo_khoa = {t["key"]: t for t in resp.json()["tunables"]}
    assert theo_khoa["knee_depth"]["affects_rep_count"] is True
    assert theo_khoa["back_straight_min"]["affects_rep_count"] is False


@pytest.mark.asyncio
async def test_bai_khong_ton_tai_tra_404(client: AsyncClient, admin_setup: dict) -> None:
    assert (await client.get(f"{URL}/999999", headers=admin_setup["admin"])).status_code == 404


@pytest.mark.asyncio
async def test_bai_khong_co_analyzer_tra_400(client: AsyncClient, admin_setup: dict) -> None:
    resp = await client.get(f"{URL}/{admin_setup['cardio'].id}", headers=admin_setup["admin"])

    assert resp.status_code == 400
    assert "analyzer" in resp.json()["detail"]


# ─────────────────────────────────────────────────────────────────────
# Lưu ngưỡng
# ─────────────────────────────────────────────────────────────────────

@pytest.mark.asyncio
async def test_luu_roi_doc_lai_thay_gia_tri_moi(client: AsyncClient, admin_setup: dict) -> None:
    sq = admin_setup["squat"].id

    resp = await client.put(f"{URL}/{sq}", headers=admin_setup["admin"],
                            json={"values": {"knee_depth": 88.0}})

    assert resp.status_code == 200
    theo_khoa = {t["key"]: t for t in resp.json()["tunables"]}
    assert theo_khoa["knee_depth"]["current"] == 88.0
    assert theo_khoa["back_straight_min"]["current"] is None


@pytest.mark.asyncio
async def test_gia_tri_luu_xuong_toi_duoc_analyzer(
    client: AsyncClient, admin_setup: dict, db_session: AsyncSession
) -> None:
    """MẮT XÍCH QUAN TRỌNG NHẤT của cả tính năng.

    Màn hình cũ đứt đúng ở đây: giá trị được lưu vào một biến module rồi không
    bao giờ tới analyzer. Test này đi hết đường thật — ghi qua API, rồi đọc
    lại bằng chính `load_thresholds` mà handler WebSocket gọi lúc mở phiên.
    """
    sq = admin_setup["squat"].id
    await client.put(f"{URL}/{sq}", headers=admin_setup["admin"],
                     json={"values": {"knee_depth": 88.0, "back_straight_min": 145.0}})

    nguong = await load_thresholds(db_session, "Squat")

    assert nguong == {"knee_depth": 88.0, "back_straight_min": 145.0}


@pytest.mark.asyncio
async def test_ghi_de_chi_ap_cho_dung_bai_do(
    client: AsyncClient, admin_setup: dict, db_session: AsyncSession
) -> None:
    """Lỗi nghiêm trọng nhất của bản cũ.

    Bản cũ gán `squat_module.KNEE_DEPTH_THRESHOLD`, tức sửa MẶC ĐỊNH của
    SquatAnalyzer — nên chỉnh cho một bài là đổi luôn cả 21 biến thể squat.
    """
    await client.put(f"{URL}/{admin_setup['squat'].id}", headers=admin_setup["admin"],
                     json={"values": {"knee_depth": 88.0}})

    assert await load_thresholds(db_session, "Squat") == {"knee_depth": 88.0}
    assert await load_thresholds(db_session, "Barbell Squat") == {}


@pytest.mark.asyncio
async def test_bo_khoa_ra_la_go_ghi_de(
    client: AsyncClient, admin_setup: dict, db_session: AsyncSession
) -> None:
    """`values` là trạng thái đầy đủ mong muốn, nên bỏ một khoá = quay về mặc định.

    Nếu chỉ ghi thêm mà không xoá thì không có cách nào hoàn tác ngoài việc
    sửa tay DB.
    """
    sq = admin_setup["squat"].id
    await client.put(f"{URL}/{sq}", headers=admin_setup["admin"],
                     json={"values": {"knee_depth": 88.0, "back_straight_min": 145.0}})

    await client.put(f"{URL}/{sq}", headers=admin_setup["admin"],
                     json={"values": {"knee_depth": 88.0}})

    assert await load_thresholds(db_session, "Squat") == {"knee_depth": 88.0}


@pytest.mark.asyncio
async def test_gui_rong_la_bo_het_ghi_de(
    client: AsyncClient, admin_setup: dict, db_session: AsyncSession
) -> None:
    sq = admin_setup["squat"].id
    await client.put(f"{URL}/{sq}", headers=admin_setup["admin"],
                     json={"values": {"knee_depth": 88.0}})

    await client.put(f"{URL}/{sq}", headers=admin_setup["admin"], json={"values": {}})

    assert await load_thresholds(db_session, "Squat") == {}


@pytest.mark.asyncio
async def test_luu_lai_lan_nua_khong_nhan_ban_dong(
    client: AsyncClient, admin_setup: dict, db_session: AsyncSession
) -> None:
    """Mỗi (bài, khoá) chỉ được có một dòng — nếu không thì `load_thresholds`
    lấy dòng nào là chuyện may rủi theo thứ tự trả về của DB."""
    sq = admin_setup["squat"].id
    for gia_tri in (88.0, 90.0, 92.0):
        await client.put(f"{URL}/{sq}", headers=admin_setup["admin"],
                         json={"values": {"knee_depth": gia_tri}})

    from sqlalchemy import select
    dong = (await db_session.execute(
        select(ExercisePostureRule).where(ExercisePostureRule.exercise_id == sq)
    )).scalars().all()

    assert len(dong) == 1
    assert await load_thresholds(db_session, "Squat") == {"knee_depth": 92.0}


@pytest.mark.asyncio
async def test_khong_xoa_dong_cua_nguoi_khac(
    client: AsyncClient, admin_setup: dict, db_session: AsyncSession
) -> None:
    """Dòng có tên mô tả là dữ liệu seed sẵn của schema — không phải rác.

    Xoá hộ những gì mình không hiểu là cách làm mất dữ liệu của người khác.
    """
    sq = admin_setup["squat"].id
    db_session.add(ExercisePostureRule(
        exercise_id=sq, rule_name="Góc đầu gối (hip-knee-ankle)",
        joint_a="Hip", joint_b="Knee", joint_c="Ankle", min_angle=70, max_angle=100,
    ))
    await db_session.flush()

    await client.put(f"{URL}/{sq}", headers=admin_setup["admin"], json={"values": {}})

    from sqlalchemy import select
    con_lai = (await db_session.execute(
        select(ExercisePostureRule).where(ExercisePostureRule.exercise_id == sq)
    )).scalars().all()
    assert [r.rule_name for r in con_lai] == ["Góc đầu gối (hip-knee-ankle)"]


# ─────────────────────────────────────────────────────────────────────
# Kiểm giá trị trước khi ghi
# ─────────────────────────────────────────────────────────────────────

@pytest.mark.asyncio
async def test_gia_tri_ngoai_khoang_bi_tu_choi(client: AsyncClient, admin_setup: dict) -> None:
    resp = await client.put(f"{URL}/{admin_setup['squat'].id}", headers=admin_setup["admin"],
                            json={"values": {"knee_depth": 300.0}})

    assert resp.status_code == 422


@pytest.mark.asyncio
async def test_khoa_cua_analyzer_khac_bi_tu_choi(client: AsyncClient, admin_setup: dict) -> None:
    """`hip_sag` là của plank. Ghi vào squat thì lưu được nhưng bị bỏ qua lúc
    chạy — đúng kiểu hỏng im lặng cần chặn ở biên."""
    resp = await client.put(f"{URL}/{admin_setup['squat'].id}", headers=admin_setup["admin"],
                            json={"values": {"hip_sag": 150.0}})

    assert resp.status_code == 422
    assert "hip_sag" in resp.json()["detail"]


@pytest.mark.asyncio
async def test_dao_thu_tu_cap_dem_rep_bi_tu_choi(client: AsyncClient, admin_setup: dict) -> None:
    """Ngưỡng đứng thẳng thấp hơn ngưỡng chạm đáy = bộ đếm đứng im ở 0 rep,
    không lỗi nào báo. Phải chặn ngay lúc lưu."""
    resp = await client.put(f"{URL}/{admin_setup['squat'].id}", headers=admin_setup["admin"],
                            json={"values": {"knee_depth": 130.0, "stand_up_min": 125.0}})

    assert resp.status_code == 422
    assert "bộ đếm rep" in resp.json()["detail"]


@pytest.mark.asyncio
async def test_bi_tu_choi_thi_khong_ghi_gi_xuong(
    client: AsyncClient, admin_setup: dict, db_session: AsyncSession
) -> None:
    """Ghi một phần rồi mới phát hiện phần sau sai là để lại trạng thái nửa vời."""
    sq = admin_setup["squat"].id

    await client.put(f"{URL}/{sq}", headers=admin_setup["admin"],
                     json={"values": {"back_straight_min": 145.0, "knee_depth": 999.0}})

    assert await load_thresholds(db_session, "Squat") == {}


# ─────────────────────────────────────────────────────────────────────
# Bằng chứng cuối: ngưỡng admin lưu đổi được KẾT QUẢ phân tích
# ─────────────────────────────────────────────────────────────────────

@pytest.mark.asyncio
async def test_nguong_admin_luu_doi_duoc_so_rep_dem_duoc(
    client: AsyncClient, admin_setup: dict, db_session: AsyncSession
) -> None:
    """Đi trọn đường: admin lưu → DB → analyzer → số rep thay đổi.

    Các test trên chứng minh giá trị nằm đúng chỗ. Test này chứng minh nó có
    TÁC DỤNG — thứ mà màn hình cũ không có: 4 trong 7 ô của nó lưu xuống bình
    thường rồi không bao giờ tới analyzer.

    Kịch bản: một rep squat xuống 85°. Với mặc định 95° thì tính là đủ sâu
    (85 < 95) nên đếm 1 rep. Admin siết yêu cầu xuống 70° cho riêng bài này —
    cùng chuỗi động tác đó không còn đủ sâu, đếm 0 rep.
    """
    from app.ml.analyzers.squat import SquatAnalyzer
    from tests.pose_builders import squat_pose
    from tests.test_analyzers import rep_sequence

    goc = rep_sequence(170, 85)

    def dem_rep(thresholds: dict[str, float]) -> int:
        analyzer = SquatAnalyzer(thresholds=thresholds)
        for g in goc:
            analyzer.analyze(squat_pose(g, 175.0))
        return analyzer.rep_counter.rep_count

    # Trước khi admin đụng vào: chạy bằng mặc định.
    truoc = await load_thresholds(db_session, "Squat")
    assert dem_rep(truoc) == 1

    await client.put(f"{URL}/{admin_setup['squat'].id}", headers=admin_setup["admin"],
                     json={"values": {"knee_depth": 70.0}})

    sau = await load_thresholds(db_session, "Squat")
    assert dem_rep(sau) == 0, "Ngưỡng admin lưu không tới được analyzer"

    # Và bài cùng analyzer nhưng không được chỉnh vẫn đếm như cũ — đây là chỗ
    # bản cũ sai nặng nhất, vì nó sửa hằng số toàn cục dùng chung.
    assert dem_rep(await load_thresholds(db_session, "Barbell Squat")) == 1


@pytest.mark.asyncio
async def test_nguong_ti_le_cung_toi_duoc_analyzer(
    client: AsyncClient, admin_setup: dict, db_session: AsyncSession
) -> None:
    """`knee_overshoot` là ngưỡng vừa được nối vào cơ chế chung.

    Trước đây ba analyzer (squat, lunge, deadlift) đọc thẳng hằng số module
    `KNEE_OVERSHOOT_RATIO`, nên nó nằm ngoài mọi ghi đè theo bài. Test này
    chứng minh đường mới thông: cùng một tư thế gối vượt mũi chân 0.12 khung
    hình, ngưỡng 0.05 mặc định thì báo lỗi, ngưỡng 0.20 admin đặt thì không.
    """
    from app.ml.analyzers.squat import SquatAnalyzer
    from tests.pose_builders import squat_pose

    pose = squat_pose(100.0, 175.0, knee_past_toe=True)

    def co_bao_loi(thresholds: dict[str, float]) -> bool:
        ket_qua = SquatAnalyzer(thresholds=thresholds).analyze(pose)
        return any("vượt quá mũi chân" in e for e in ket_qua.errors)

    assert co_bao_loi(await load_thresholds(db_session, "Squat")) is True

    await client.put(f"{URL}/{admin_setup['squat'].id}", headers=admin_setup["admin"],
                     json={"values": {"knee_overshoot": 0.20}})

    assert co_bao_loi(await load_thresholds(db_session, "Squat")) is False
