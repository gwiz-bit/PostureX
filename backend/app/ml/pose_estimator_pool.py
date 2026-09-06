"""Pool `PoseEstimator` để chạy pose estimation ngoài event loop.

VẤN ĐỀ ĐANG SỬA
---------------
`routes/realtime.py` trước đây gọi thẳng `_pose_estimator.estimate(frame)`
ngay trong hàm `async` xử lý WebSocket. MediaPipe `detect()` là tác vụ CPU
mất 30-60 ms và KHÔNG nhả điều khiển, nên trong suốt thời gian đó **toàn bộ
server đứng im** — không riêng phiên phân tích khác, mà cả đăng nhập, tải
danh sách bài tập, chat AI đều phải xếp hàng chờ.

Client gửi ~9 fps, tức mỗi người tập chiếm 30-50% event loop. Hai người là
gần bão hoà, ba người trở lên thì độ trễ dồn lại và mọi request đều chậm
theo, kể cả của người không tập.

VÌ SAO PHẢI LÀ POOL, KHÔNG PHẢI CHỈ `asyncio.to_thread`
-------------------------------------------------------
Bọc `to_thread` quanh một instance dùng chung sẽ hết chặn event loop, nhưng
sinh lỗi tệ hơn: `PoseLandmarker` KHÔNG thread-safe. Hai luồng cùng gọi
`detect()` trên một instance là hành vi không xác định — kết quả sai lệch
hoặc sập tiến trình, và lỗi kiểu này rất khó tái hiện.

Nên mỗi luồng cần một instance riêng. Pool giữ N instance, mỗi lúc chỉ một
luồng giữ một instance.

VÌ SAO GIỚI HẠN N
-----------------
Semaphore ở đây không chỉ để bảo vệ instance mà còn để giữ tải: pose
estimation ăn trọn một core, thả cho vô hạn luồng cùng chạy trên máy 2 core
thì tất cả cùng chậm đi thay vì xếp hàng có trật tự. Mặc định lấy theo số
core, chặn trên ở 4 vì quá số core thì chỉ tranh nhau CPU.

Instance được tạo LƯỜI — chỉ dựng khi thật sự có người tập. Mỗi instance nạp
model 9,4 MB cùng đồ thị MediaPipe, dựng sẵn cả N lúc khởi động là trả giá
RAM và thời gian khởi động cho thứ có thể không ai dùng.
"""

import asyncio
import logging
import os
from collections.abc import Callable
from typing import Any

from app.ml.pose_estimator import Keypoint, PoseEstimator

logger = logging.getLogger(__name__)

MAX_POOL_SIZE = 4


def default_pool_size() -> int:
    """Số instance mặc định: theo số CPU, tối thiểu 1, tối đa `MAX_POOL_SIZE`."""
    return max(1, min(os.cpu_count() or 1, MAX_POOL_SIZE))


class PoseEstimatorPool:
    """N `PoseEstimator`, mỗi lúc mỗi instance chỉ phục vụ một luồng.

    `factory` cho phép tiêm bản giả lúc test: dựng `PoseEstimator` thật cần
    mediapipe và file model 9,4 MB, quá nặng cho một test chỉ kiểm tra hành vi
    xếp hàng và tạo lười.
    """

    def __init__(
        self,
        size: int | None = None,
        factory: Callable[..., Any] = PoseEstimator,
        **estimator_kwargs: Any,
    ) -> None:
        self._size = size if size and size > 0 else default_pool_size()
        self._factory = factory
        self._estimator_kwargs = estimator_kwargs
        # LIFO để instance vừa dùng xong được dùng lại ngay — giữ cache CPU
        # còn nóng, và khi tải thấp thì các instance dư nằm im thay vì bị xoay
        # vòng vô ích.
        self._free: asyncio.LifoQueue[PoseEstimator] = asyncio.LifoQueue()
        self._slots = asyncio.Semaphore(self._size)
        self._create_lock = asyncio.Lock()
        self._created = 0
        logger.info("PoseEstimatorPool: tối đa %d instance (tạo lười)", self._size)

    @property
    def size(self) -> int:
        return self._size

    @property
    def created(self) -> int:
        """Số instance đã thực sự dựng — dùng để quan sát/test."""
        return self._created

    async def estimate(self, frame_bytes: bytes) -> list[Keypoint] | None:
        """Như `PoseEstimator.estimate` nhưng chạy trong luồng riêng.

        Chờ tại semaphore khi cả N instance đang bận. Chờ ở đây là đúng: nó
        đẩy áp lực về phía người gửi frame thay vì để mọi request khác trên
        server cùng chậm theo.
        """
        async with self._slots:
            estimator = await self._acquire()
            try:
                return await asyncio.to_thread(estimator.estimate, frame_bytes)
            finally:
                self._free.put_nowait(estimator)

    async def _acquire(self) -> PoseEstimator:
        try:
            return self._free.get_nowait()
        except asyncio.QueueEmpty:
            pass

        # Dựng dưới khoá để hai phiên vào cùng lúc không cùng dựng model —
        # mỗi lần dựng ngốn một core trong khoảng một giây.
        async with self._create_lock:
            try:
                return self._free.get_nowait()
            except asyncio.QueueEmpty:
                pass
            estimator = await asyncio.to_thread(self._factory, **self._estimator_kwargs)
            self._created += 1
            logger.info("PoseEstimatorPool: đã dựng %d/%d instance", self._created, self._size)
            return estimator

    async def close(self) -> None:
        """Giải phóng mọi instance đang rảnh.

        Chỉ gọi lúc tắt app. Instance đang được một phiên dùng dở không nằm
        trong hàng đợi nên không bị đóng giữa chừng.
        """
        while True:
            try:
                estimator = self._free.get_nowait()
            except asyncio.QueueEmpty:
                break
            await asyncio.to_thread(estimator.close)
            self._created -= 1


# Singleton dùng chung toàn app — cả `routes/realtime.py` (WebSocket) lẫn
# `services/video_analysis_service.py` (phân tích video đã upload) đều gọi
# `get_pose_estimator_pool()` thay vì tự dựng pool riêng. Hai pool riêng biệt
# sẽ tranh CPU độc lập nhau, phá vỡ đúng mục đích giới hạn N instance ở trên —
# một pool chung mới xếp hàng công bằng giữa live session và job phân tích
# video chạy nền.
_singleton: PoseEstimatorPool | None = None


def get_pose_estimator_pool() -> PoseEstimatorPool:
    """Trả về pool dùng chung, dựng lười ở lần gọi đầu tiên."""
    global _singleton
    if _singleton is None:
        _singleton = PoseEstimatorPool(model_complexity=1)
    return _singleton
