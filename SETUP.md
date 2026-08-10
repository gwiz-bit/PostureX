# Hướng dẫn chạy PostureX sau khi clone

## 1. Yêu cầu cài sẵn trên máy

- **Flutter SDK** (đã cài `flutter` chạy được, `flutter doctor` không lỗi nặng)
- **Python 3.11+**
- **MySQL Server** đang chạy (local hoặc XAMPP/WAMP đều được)
- Android Studio / Xcode nếu muốn chạy trên emulator/simulator

## 2. Clone code

```powershell
git clone https://github.com/gwiz-bit/PostureX.git
cd PostureX
```

## 3. Setup Backend (FastAPI)

**Cách nhanh — 1 lệnh làm hết (khuyên dùng):**

```powershell
cd lib\backend
.\run.ps1
```

Lần đầu chạy, nếu chưa có `.env` script sẽ tự tạo từ `.env.example` rồi dừng
lại để bạn điền `DB_PASSWORD` — điền xong chạy lại `.\run.ps1` là xong: script
tự tạo venv, cài dependencies, tải model MediaPipe, khởi tạo database (nếu
database rỗng) hoặc chỉ đồng bộ thêm bảng còn thiếu (nếu đã có dữ liệu —
không đụng gì dữ liệu cũ), rồi chạy server. Chạy lại `.\run.ps1` bất cứ lúc
nào cũng an toàn, kể cả sau khi `git pull` có model/bảng mới.

Các bước dưới đây là để hiểu/điều chỉnh thủ công từng phần khi cần — không
cần làm nếu `run.ps1` đã chạy được.

```powershell
cd lib\backend
python -m venv venv
venv\Scripts\pip install -r requirements.txt
```

### 3.1. Tạo file `.env`

Copy file mẫu rồi điền giá trị thật:

```powershell
copy .env.example .env
```

Mở `.env` và điền các giá trị sau (khớp với MySQL trên máy bạn):

```
DB_HOST=localhost
DB_PORT=3306          # hoặc port MySQL đang chạy trên máy bạn
DB_NAME=poturex123
DB_USER=root
DB_PASSWORD=           # mật khẩu MySQL của bạn

SECRET_KEY=posturex-dev-secret-key-change-in-production
VIDEO_STORAGE_PATH=storage/videos
DEBUG=True

SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=              # Gmail dùng để gửi OTP/reset password
SMTP_PASSWORD=          # App Password của Gmail đó (không phải mật khẩu đăng nhập thường)
SMTP_FROM_NAME=Posture X

GOOGLE_CLIENT_ID=879931217481-eeqak275h11nji6v93j8a9s65rc7pjt3.apps.googleusercontent.com
```

> `SMTP_USER`/`SMTP_PASSWORD` chỉ cần đúng nếu bạn muốn test chức năng gửi OTP/quên mật khẩu qua email thật — nếu chỉ test các chức năng khác thì có thể để tạm, backend vẫn chạy được, chỉ có 2 chức năng đó sẽ lỗi khi gọi tới.

### 3.2. Khởi tạo database

**Cách A — lấy dữ liệu của người khác gửi cho bạn (khuyên dùng nếu có):**
nếu ai đó trong team đã gửi bạn file `data_dump.sql` (qua chat/Zalo/Drive
riêng tư — **không** qua git, xem ghi chú bên dưới), đặt file đó vào
`lib/backend/sql/data_dump.sql` rồi chạy:

```powershell
venv\Scripts\python.exe sql\import_data.py
```

**Cách B — tạo database trống, tự thêm dữ liệu:**

```powershell
venv\Scripts\python.exe sql\run_schema.py
venv\Scripts\python.exe create_tables.py
venv\Scripts\python.exe create_admin.py admin@posturex.com Admin123 "Super Admin"
```

⚠️ Cả 2 cách trên đều **xóa sạch và tạo lại** database `poturex123` nếu đã tồn tại — chỉ chạy khi chắc chắn chưa có dữ liệu quan trọng trong đó.

### 3.2.1. Cập nhật dữ liệu mới nhất sau này (dành cho người giữ dữ liệu gốc)

Sau khi tự tạo thêm tài khoản/dữ liệu trên máy mình, chạy lệnh export để
tạo lại file dữ liệu mới nhất:

```powershell
venv\Scripts\python.exe sql\export_data.py
```

Lệnh này ghi ra `lib/backend/sql/data_dump.sql` — **file này bị gitignore, không tự động lên git khi bạn push code**. Muốn chia sẻ, tự gửi file này cho đồng đội qua kênh riêng tư (chat, Zalo, Google Drive share riêng...), không đăng công khai hay push lên git.

⚠️ File này chứa dữ liệu user thật (email, mật khẩu đã hash) — vì repo GitHub của dự án có thể là Public, tuyệt đối không commit/push file này lên git dưới mọi hình thức.

### 3.3. Chạy server

```powershell
venv\Scripts\python.exe -m uvicorn app.main:app --host 0.0.0.0 --port 9000
```

Kiểm tra chạy đúng: mở trình duyệt vào `http://localhost:9000/health`, thấy `{"status":"ok",...}` là được.

Để server tự reload khi sửa code, thêm `--reload`:

```powershell
venv\Scripts\python.exe -m uvicorn app.main:app --reload --host 0.0.0.0 --port 9000
```

## 4. Setup Flutter (app)

Ở thư mục gốc project (`PostureX/`):

```powershell
flutter pub get
```

App đã cấu hình sẵn để gọi backend qua `http://10.0.2.2:9000` (`lib/config/api_config.dart`) — đây là địa chỉ đặc biệt để **Android emulator** trỏ về `localhost` của máy host, không cần đổi gì nếu chạy trên emulator Android.

> Nếu chạy trên **thiết bị thật** (điện thoại) thay vì emulator, phải đổi `baseUrl`/`wsUrl` trong `lib/config/api_config.dart` thành địa chỉ IP LAN thật của máy chạy backend (ví dụ `http://192.168.1.x:9000`), vì `10.0.2.2` chỉ hoạt động trên emulator.

Chạy app:

```powershell
flutter run
```

## 5. Đăng nhập admin

- Email: `admin@posturex.com`
- Password: `Admin123` (đổi trong bước 3.2 nếu bạn dùng lệnh khác)

## 6. Thứ tự khởi động mỗi lần code lại

1. Bật MySQL
2. Chạy backend: `.\run.ps1` (trong `lib\backend`) — hoặc thủ công: `venv\Scripts\python.exe -m uvicorn app.main:app --host 0.0.0.0 --port 9000`
3. Chạy app Flutter: `flutter run`

Backend **không tự chạy nền** — mỗi lần tắt máy/terminal phải khởi động lại thủ công theo bước 2.
