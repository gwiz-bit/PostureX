# Posture X Backend

AI-powered gym technique analysis — FastAPI + MediaPipe + MySQL.

## Yêu cầu hệ thống

- Python 3.13+
- MySQL 8.x
- (Tuỳ chọn) Docker

---

## Cài đặt nhanh

Xem hướng dẫn chi tiết đầy đủ tại [`BA.md`](BA.md). Tóm tắt:

```bash
# 1. Clone và vào thư mục
cd posture-x-backend

# 2. Tạo virtual environment
python -m venv venv
source venv/bin/activate          # Linux/macOS
venv\Scripts\activate             # Windows

# 3. Cài dependencies
pip install -r requirements.txt

# 4. Cấu hình môi trường
cp .env.example .env
# Mở .env và điền DB_HOST, DB_PORT, DB_NAME, DB_USER, DB_PASSWORD, SECRET_KEY

# 5. Tạo database (MySQL phải đang chạy)
# mysql -u root -p -e "CREATE DATABASE posturex CHARACTER SET utf8mb4;"

# 6. Tạo bảng
python create_tables.py

# 7. Khởi động server
uvicorn app.main:app --reload --port 9000
```

Server sẽ chạy tại `http://localhost:9000`.  
Swagger UI: `http://localhost:9000/docs`

---

## Test nhanh

```bash
# Kiểm tra health
curl http://localhost:9000/health

# Chạy unit tests
pytest tests/ -v
```

---

## Test WebSocket phân tích thời gian thực

Lưu script sau thành `test_ws_client.py` rồi chạy:

```python
"""Script client mẫu gửi frame JPEG qua WebSocket đến /ws/analyze."""

import asyncio
import base64
import json
import cv2
import websockets


async def main():
    uri = "ws://localhost:9000/api/v1/ws/analyze"

    async with websockets.connect(uri) as ws:
        # Bước 1: gửi message khởi tạo
        await ws.send(json.dumps({"exercise": "squat"}))
        init_resp = await ws.recv()
        print("Server:", init_resp)

        # Bước 2: đọc webcam và gửi frame liên tục
        cap = cv2.VideoCapture(0)
        try:
            for _ in range(100):  # gửi 100 frame
                ret, frame = cap.read()
                if not ret:
                    break

                # Encode frame thành JPEG rồi base64
                _, buf = cv2.imencode(".jpg", frame, [cv2.IMWRITE_JPEG_QUALITY, 70])
                b64 = base64.b64encode(buf.tobytes()).decode()

                await ws.send(b64)
                result = await ws.recv()
                data = json.loads(result)
                print(
                    f"Reps: {data.get('rep_count')} | "
                    f"Phase: {data.get('phase')} | "
                    f"Correct: {data.get('correct')} | "
                    f"Errors: {data.get('errors')}"
                )
                await asyncio.sleep(0.033)  # ~30 FPS
        finally:
            cap.release()


asyncio.run(main())
```

Chạy:

```bash
pip install websockets opencv-python
python test_ws_client.py
```

---

## Test upload video

```bash
# Đăng ký tài khoản
curl -X POST http://localhost:9000/api/v1/auth/register \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"secret123","full_name":"Test User"}'

# Đăng nhập lấy token
TOKEN=$(curl -s -X POST http://localhost:9000/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"secret123"}' | python -c "import sys,json; print(json.load(sys.stdin)['access_token'])")

# Upload video
curl -X POST http://localhost:9000/api/v1/videos/upload \
  -H "Authorization: Bearer $TOKEN" \
  -F "file=@/path/to/your/workout.mp4" \
  -F "exercise=squat"

# Xem danh sách video
curl http://localhost:9000/api/v1/videos \
  -H "Authorization: Bearer $TOKEN"
```

---

## Cấu trúc dự án

```
posture-x-backend/
├── app/
│   ├── main.py              # FastAPI app, CORS, /health
│   ├── core/                # config, security, database
│   ├── api/v1/routes/
│   │   ├── realtime.py      # ⭐ WebSocket /ws/analyze
│   │   ├── videos.py        # Upload & truy vấn video
│   │   ├── auth.py          # Đăng ký / đăng nhập
│   │   ├── users.py         # Thông tin user
│   │   └── workouts.py      # Lịch sử buổi tập
│   ├── ml/
│   │   ├── pose_estimator.py  # MediaPipe wrapper
│   │   ├── angle_utils.py     # Tính góc khớp
│   │   ├── rep_counter.py     # Đếm rep theo chu kỳ góc
│   │   ├── session_state.py   # Trạng thái per-connection
│   │   └── analyzers/
│   │       └── squat.py       # Phân tích squat tiếng Việt
│   ├── services/
│   │   └── video_service.py   # Lưu file + metadata DB
│   ├── models/              # SQLAlchemy ORM models
│   ├── schemas/             # Pydantic v2 schemas
│   └── crud/                # Database queries
├── storage/videos/          # File video (gitignored)
├── tests/
├── Dockerfile
└── requirements.txt
```

---

## Docker

```bash
docker build -t posture-x-backend .
docker run -p 9000:8000 \
  -e DB_HOST=host.docker.internal \
  -e DB_PORT=3306 \
  -e DB_NAME=posturex \
  -e DB_USER=root \
  -e DB_PASSWORD=pass \
  -e SECRET_KEY=your-secret \
  -v $(pwd)/storage:/app/storage \
  posture-x-backend
```
