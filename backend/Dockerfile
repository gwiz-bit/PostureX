FROM python:3.11-slim

# Cài dependencies hệ thống cho OpenCV và MediaPipe
RUN apt-get update && apt-get install -y --no-install-recommends \
    libgl1 \
    libglib2.0-0 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

# Bake sẵn model MediaPipe vào image lúc build — tránh phải tải lại mỗi
# lần container khởi động lại (đặc biệt quan trọng trên PaaS free tier
# hay ngủ/restart, kiểu Render).
RUN python scripts/download_models.py

# Tạo thư mục lưu video
RUN mkdir -p storage/videos

EXPOSE 8000

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
