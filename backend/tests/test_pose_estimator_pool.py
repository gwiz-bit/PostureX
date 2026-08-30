"""Test pool chạy pose estimation ngoài event loop.

Dùng estimator giả: dựng `PoseEstimator` thật cần mediapipe và file model
9,4 MB, quá nặng cho test — mà thứ cần kiểm ở đây là hành vi xếp hàng và tạo
lười, không phải chất lượng nhận diện.
"""

import asyncio
import threading
import time

import pytest

from app.ml.pose_estimator_pool import MAX_POOL_SIZE, PoseEstimatorPool, default_pool_size


class _FakeEstimator:
    """Giả lập tác vụ CPU chặn luồng, có đếm số luồng chạy đồng thời."""

    concurrent = 0
    peak_concurrent = 0
    instances = 0
    _lock = threading.Lock()

    def __init__(self, delay: float = 0.05) -> None:
        self._delay = delay
        with _FakeEstimator._lock:
            _FakeEstimator.instances += 1
        self.closed = False

    def estimate(self, frame_bytes: bytes) -> list[str]:
        with _FakeEstimator._lock:
            _FakeEstimator.concurrent += 1
            _FakeEstimator.peak_concurrent = max(
                _FakeEstimator.peak_concurrent, _FakeEstimator.concurrent
            )
        try:
            time.sleep(self._delay)  # chặn luồng, giống MediaPipe detect()
            return [f"kp-{len(frame_bytes)}"]
        finally:
            with _FakeEstimator._lock:
                _FakeEstimator.concurrent -= 1

    def close(self) -> None:
        self.closed = True

    @classmethod
    def reset(cls) -> None:
        cls.concurrent = 0
        cls.peak_concurrent = 0
        cls.instances = 0


@pytest.fixture(autouse=True)
def _reset_fake() -> None:
    _FakeEstimator.reset()


@pytest.mark.asyncio
async def test_khong_chan_event_loop() -> None:
    """Trong lúc estimate chạy, event loop vẫn phải phục vụ việc khác.

    Đây là lỗi gốc đang sửa: gọi thẳng MediaPipe trong hàm async khiến cả
    server đứng im 30-60 ms mỗi frame.
    """
    pool = PoseEstimatorPool(size=1, factory=_FakeEstimator, delay=0.2)
    ticks = 0

    async def dem_nhip() -> None:
        nonlocal ticks
        while True:
            await asyncio.sleep(0.01)
            ticks += 1

    nhip = asyncio.create_task(dem_nhip())
    await pool.estimate(b"frame")
    nhip.cancel()

    # Nếu event loop bị chặn suốt 0,2s thì gần như không nhịp nào chạy được.
    assert ticks >= 5


@pytest.mark.asyncio
async def test_gioi_han_so_luong_chay_song_song() -> None:
    """Không bao giờ vượt quá `size` luồng cùng chạy.

    Vừa để bảo vệ instance (PoseLandmarker không thread-safe), vừa để giữ tải:
    thả vô hạn luồng trên máy 2 core thì tất cả cùng chậm.
    """
    pool = PoseEstimatorPool(size=2, factory=_FakeEstimator, delay=0.05)

    await asyncio.gather(*(pool.estimate(b"frame") for _ in range(10)))

    assert _FakeEstimator.peak_concurrent <= 2


@pytest.mark.asyncio
async def test_tao_luoi_khong_vuot_qua_size() -> None:
    """Chỉ dựng instance khi thật sự cần, và không quá `size`."""
    pool = PoseEstimatorPool(size=3, factory=_FakeEstimator, delay=0.01)
    assert pool.created == 0  # chưa ai tập thì chưa tốn RAM nào

    await pool.estimate(b"frame")
    assert pool.created == 1

    await asyncio.gather(*(pool.estimate(b"frame") for _ in range(10)))
    assert pool.created <= 3


@pytest.mark.asyncio
async def test_tra_ket_qua_cua_estimator() -> None:
    pool = PoseEstimatorPool(size=1, factory=_FakeEstimator, delay=0.0)
    assert await pool.estimate(b"abc") == ["kp-3"]


@pytest.mark.asyncio
async def test_close_giai_phong_instance() -> None:
    pool = PoseEstimatorPool(size=2, factory=_FakeEstimator, delay=0.0)
    await pool.estimate(b"frame")
    assert pool.created == 1

    await pool.close()
    assert pool.created == 0


def test_size_mac_dinh_nam_trong_gioi_han() -> None:
    assert 1 <= default_pool_size() <= MAX_POOL_SIZE
