# Posture X — Sổ Tay Vận Hành

> **Cập nhật 11/07/2026.** Tài liệu này đã được viết lại sau khi code của cả nhóm được gộp vào
> **một repo duy nhất**. Bản trước mô tả 2 repo riêng (`d:\BAEXE\posture-x-backend` và
> `C:\fe-posturex\PostureX`) — **những đường dẫn, cổng và tên file đó không còn đúng nữa**.
> Các bài học cũ vẫn còn giá trị được giữ lại ở cuối.

---

## 📁 Cấu trúc repo (đã gộp)

Tất cả nằm trong **một** repo Flutter:

| Thành phần                       | Vị trí                                                                                        |
| ---------------------------------- | ----------------------------------------------------------------------------------------------- |
| App Flutter (người dùng)        | `lib/`                                                                                        |
| App Admin (dữ liệu giả)         | `lib/admin/` — có `main()` riêng                                                         |
| **Backend FastAPI (Python)** | **`lib/backend/`** — nằm trong `lib/` nhưng Flutter bỏ qua file không phải Dart |

---

## ⚙️ Cấu hình hệ thống

* **Python: 3.12** — **KHÔNG dùng 3.14.** `mediapipe==0.10.35` chưa có wheel cho 3.14, `pip install` sẽ fail.
* **MySQL 8.0.46** (local)
  * Host/Port: `localhost:3306` · DB: **`poturex123`** (thiếu chữ "s" là chủ ý — đúng tên nhóm đặt)
  * User: `root` · Password: `123456`
  * Cấu hình đọc từ **`lib/backend/.env`** (copy từ `.env.example`). File `.env` bị gitignore nên
    mỗi người phải tự tạo — **và mật khẩu MySQL trong `.env.example` là của máy người khác, phải sửa lại.**
* **Cổng backend: 9000** (KHÔNG phải 8000 như tài liệu cũ). `lib/config/api_config.dart` chờ ở 9000.
* **Tài khoản test: `test@posturex.com` / `Test123`** ✅ đăng nhập được.

---

## 🚀 Chạy hệ thống

### 1. Backend (PowerShell riêng, để nguyên chạy)

```powershell
cd lib\backend
py -3.12 -m venv venv            # chỉ lần đầu
venv\Scripts\activate
pip install -r requirements.txt  # chỉ lần đầu
python download_models.py        # chỉ lần đầu — tải model MediaPipe (~9 MB)
python create_tables.py          # chỉ lần đầu — tạo videos/workouts/email_otps
uvicorn app.main:app --reload --host 0.0.0.0 --port 9000
```

`--host 0.0.0.0` **bắt buộc**, nếu không emulator/điện thoại không gọi tới được.
Kiểm tra: [http://localhost:9000/health](http://localhost:9000/health) → `{"status":"ok","app":"Posture X"}` · Swagger: `/docs`

### 2. App Flutter

```powershell
flutter pub get
flutter run -d emulator-5554                # app người dùng
flutter run -t lib/admin/admin_main.dart    # app admin (dữ liệu giả)
```

---

## 📱 Emulator — 2 cái bẫy đã tốn nhiều thời gian

**① Emulator crash vì OpenGL.** Bật từ Android Studio bằng cấu hình mặc định thì crash
(`Failed to load opengl32sw`). Phải chạy bằng lệnh, với render phần mềm:

```powershell
& "$env:LOCALAPPDATA\Android\Sdk\emulator\emulator.exe" -avd Pixel_4 -gpu swiftshader_indirect -no-snapshot -no-metrics -no-boot-anim
```

Nếu vẫn không lên: xóa `%TEMP%\AndroidEmulator` — hộp thoại xin gửi báo cáo crash cũ sẽ chặn khởi động.

**② Camera emulator là cảnh 3D giả** → MediaPipe không thấy người, rep count luôn 0.
Device Manager → Edit Pixel_4 → Show Advanced Settings → **Camera Back = Webcam0** → cold boot lại.
Webcam laptop thường chỉ thấy nửa thân → **muốn test squat đủ động tác thì dùng điện thoại thật, đặt xa.**

Ngoài ra Windows phải **bật Developer Mode** (`start ms-settings:developers`) thì Flutter mới tạo được symlink cho plugin.

---

## 📲 Chạy trên điện thoại thật (Wi-Fi)

`lib/config/api_config.dart` lấy host từ biến build, mặc định `10.0.2.2` (emulator):

```powershell
flutter build apk --debug --dart-define=API_HOST=192.168.1.9   # IP LAN của PC
```

Ba việc bắt buộc:

1. **Mở cổng 9000 trên firewall** (PowerShell **Administrator**):
   `New-NetFirewallRule -DisplayName "PostureX backend 9000" -Direction Inbound -Protocol TCP -LocalPort 9000 -Action Allow -Profile Private,Public`
2. Thêm IP đó vào `android/app/src/main/res/xml/network_security_config.xml` — Android chặn HTTP thường theo mặc định.
3. Điện thoại phải **cùng mạng Wi-Fi** với PC.

Kiểm tra trước khi cài app: mở trình duyệt **trên điện thoại** vào `http://192.168.1.9:9000/health`.
Thấy JSON ⇒ mạng thông, cứ cài. Không thấy ⇒ lỗi ở firewall/mạng, **đừng mất công debug app**.

---

## 🧠 AI phân tích tư thế (phần lõi, vẫn nguyên vẹn)

* `lib/backend/app/ml/pose_estimator.py` — MediaPipe, 33 điểm khớp
* `lib/backend/app/ml/rep_counter.py` — đếm rep theo góc gập gối (state machine)
* `lib/backend/app/ml/analyzers/squat.py` — phản hồi lỗi squat, tiếng Việt, thời gian thực
* WebSocket: **`ws://<host>:9000/api/v1/ws/analyze`**

⚠️ **Chỉ hỗ trợ squat.** `ANALYZER_REGISTRY` trong `routes/realtime.py` chỉ đăng ký `"squat"`;
bài khác **âm thầm** fallback về `SquatAnalyzer` và cho kết quả sai.
⚠️ WebSocket này **không có auth** — lỗ hổng đã biết, chưa vá.

---

## ✅ BLOCKER cũ đã được GIẢI QUYẾT

Tài liệu trước ghi: *"Backend CHƯA chạy được với DB mới"* — mọi endpoint chạm DB trả HTTP 500
(`Unknown column 'users.id'`), vì model backend dùng `users.id` còn schema nhóm dùng `Users.UserId`.

**Đã fix.** Model giờ map đúng sang `Users.UserId` / `Email` / `PasswordHash` / `RoleId`.
Kiểm chứng thật ngày 11/07/2026 trên emulator:

```
POST /api/v1/auth/login  -> 200 OK   (trả JWT)
GET  /api/v1/users/me    -> 200 OK
GET  /api/v1/workouts    -> 200 OK
```

App đăng nhập được, Home hiển thị tên lấy từ MySQL. **Auth thật đã xong** — dev auto-login
(`dev@posturex.com` / `ensureDevToken()`) đã bị bỏ hoàn toàn.

---

## ⛔ Vẫn còn tồn đọng

**① Hai tài khoản seed KHÔNG đăng nhập được** (vấn đề cũ, chưa ai sửa).
`admin@posturex.com` / `user01@posturex.com` có mật khẩu seed bằng `UNHEX(SHA2(...,256))` — **SHA-256**,
trong khi backend dùng **bcrypt**. Đã kiểm tra trong MySQL: cột `PasswordHash` của 2 user này là
nhị phân SHA-256, backend không verify được.

→ Cách tạo tài khoản dùng được:

```powershell
python create_admin.py test@posturex.com Test123 "Tester"
# rồi trong MySQL:
# UPDATE Users SET IsEmailVerified = 1 WHERE Email = 'test@posturex.com';
```

(`create_admin.py` **không** set cờ `IsEmailVerified`, mà login lại chặn user chưa xác thực email —
nên bước UPDATE là bắt buộc.)

**② Register/OTP** trả **502** nếu chưa cấu hình SMTP — `auth.py` ném lỗi khi không gửi được mail.
Muốn dùng: điền `SMTP_USER`/`SMTP_PASSWORD` (Gmail **App Password**) trong `.env`.

**③ Google Sign-In** chưa chạy — cần tạo OAuth client trên Google Cloud Console và điền `GOOGLE_CLIENT_ID`.

**④ Upload video là ngõ cụt** — backend chỉ **lưu file**, không chạy ML trên video
(`services/video_service.py` chỉ có `save`/`delete`), và Flutter không bao giờ gọi `fetchVideos()` để xem lại.

**⑤ App admin 100% dữ liệu giả** — dù backend **đã có sẵn 10 endpoint admin** (`/api/v1/admin/...`).
Đăng nhập admin qua backdoor cứng `admin@gmail.com` / `123456` trong `login_screen.dart`.

**⑥ Kế hoạch tập** sinh hoàn toàn ở client (`WorkoutPlan.generate`), không lưu server → mất khi cài lại app.

---

## 🩹 Bài học còn nguyên giá trị

**`create_tables.py` từng xóa nhầm schema của nhóm.** Bản cũ tắt `FOREIGN_KEY_CHECKS` rồi `drop_all`
theo model backend; MySQL ở đây có `lower_case_table_names=1` nên `Users` và `users` là **cùng một bảng**
→ script xoá luôn bảng `Users` của nhóm.
→ **Đã fix**: bản hiện tại chỉ `DROP TABLE videos, workouts` (liệt kê tường minh), không đụng `Users`.
Kiểm chứng lại ngày 11/07/2026: chạy xong DB vẫn đủ **29 bảng**, seed data còn nguyên (6 exercises, 2 roles).

**Lỗi trong `PostureX123.sql`** (đã sửa — báo cho người thiết kế DB): dòng 510 vốn là
`CREATE OR ALTER VIEW` — cú pháp **SQL Server**, MySQL không hiểu. Script **dừng im lặng** tại đó,
khiến toàn bộ seed data không bao giờ chạy mà không ai hay biết. Đã đổi thành `CREATE OR REPLACE VIEW`.

**Console Windows**: script Python in tiếng Việt sẽ lỗi `UnicodeEncodeError` (cp1252).
Đặt `$env:PYTHONIOENCODING="utf-8"` trước khi chạy.

**Build Gradle**: nếu gặp *"Inconsistent JVM-target compatibility ... Java (17) / Kotlin (21)"* —
đã xử lý bằng cách ghim Kotlin về 17 trong `android/app/build.gradle.kts`.

---

## 🧪 Lệnh kiểm tra nhanh

```powershell
# Backend (từ lib\backend, đã activate venv)
python test_connection.py                     # kết nối MySQL
uvicorn app.main:app --reload --host 0.0.0.0 --port 9000
curl http://localhost:9000/health

# Đăng nhập thử — phải trả về JWT
curl -X POST http://localhost:9000/api/v1/auth/login -H "Content-Type: application/json" `
     -d '{\"email\":\"test@posturex.com\",\"password\":\"Test123\"}'

# Flutter
flutter analyze
flutter run -d emulator-5554
```

---

## 🆕 BE-13 (Thông báo) + BE-14 (Thanh toán VNPay) — 12/07/2026

Hai mục này trước ghi "Chưa bắt đầu, 0%". **Backend đã xong và kiểm chứng bằng dữ liệu thật trong MySQL.**

### Endpoint mới

```
GET    /api/v1/notifications                 danh sách (chỉ của mình)
GET    /api/v1/notifications/unread-count    số chưa đọc (cho badge chuông)
PATCH  /api/v1/notifications/{id}/read       đánh dấu đã đọc
PATCH  /api/v1/notifications/read-all
GET    /api/v1/subscriptions/plans           3 gói — KHÔNG cần đăng nhập (giá là công khai)
GET    /api/v1/subscriptions/me              gói đang dùng (null nếu chưa mua)
POST   /api/v1/subscriptions/checkout        {plan_id} -> {payment_id, pay_url}
GET    /api/v1/payments/vnpay/return         VNPay redirect về đây — KHÔNG có auth (xem dưới)
```

### ⚠️ Schema có CHECK constraint — đừng tự chế giá trị Status

Đây là thứ đã làm hỏng lần chạy đầu (MySQL error 3819). Schema khoá cứng:

```sql
CK_UserSub_Status  CHECK (Status IN ('Active', 'Expired', 'Cancelled'))
CK_Payments_Status CHECK (Status IN ('Pending', 'Completed', 'Failed', 'Refunded'))
```

Hệ quả: `Payments` phải dùng **`Completed`** (không phải "Paid"), và **`UserSubscriptions` không có trạng thái `Pending`** — nên đơn chờ thanh toán tạm ghi là `Cancelled` rồi lật sang `Active` khi trả tiền xong.
→ **Đề nghị người thiết kế DB thêm `'Pending'` vào `CK_UserSub_Status`** thì mô hình mới sạch.

### Vì sao `/payments/vnpay/return` không có auth

VNPay redirect trình duyệt người dùng về, **không mang theo JWT**. Danh tính đơn hàng lấy từ `vnp_TxnRef` (= `PaymentId`), tính toàn vẹn bảo đảm bằng **chữ ký HMAC-SHA512** — không có `HashSecret` thì không giả mạo được. Endpoint đã chặn:

- chữ ký sai → từ chối
- **số tiền bị sửa** → từ chối (so lại `vnp_Amount` với số tiền trong đơn)
- bấm F5 gọi lại → không xử lý lặp (idempotent)

Hiện chỉ dùng kênh **ReturnUrl**, chưa dùng **IPN**. IPN là VNPay gọi thẳng server-to-server, **không chạy được trên localhost** (VNPay không với tới máy mình) — cần URL công khai (ngrok). Production thì phải làm IPN, vì ReturnUrl không chạy nếu người dùng tắt app ngay sau khi trả tiền.

### Cấu hình VNPay

`.env` hiện để **khoá GIẢ** (`VNPAY_TMN_CODE=DEMOTMN`) — đủ để giả lập callback và test luồng, **nhưng không mở được trang thanh toán thật**. Muốn thanh toán thật: đăng ký <https://sandbox.vnpayment.vn> lấy TmnCode + HashSecret rồi điền vào `.env`.

### Đã sửa luôn: giá trong app lệch với database

Màn Subscription cũ **hardcode** `0₫ / 199.000₫ / 299.000₫`, trong khi DB bán `Free 0₫ / Premium 99.000₫ / Pro 199.000₫`. Giờ đọc từ `GET /subscriptions/plans` nên không thể lệch nữa.

### Kiểm chứng (chạy thật, không phải lý thuyết)

- `pytest tests/test_vnpay.py` — **8/8 pass** (ký, verify, chống sửa số tiền, sai secret, thiếu hash).
- Giả lập trọn luồng: checkout → callback ký đúng → **MySQL**: `Payments` 1 dòng `Completed` (99.000đ, có `TransactionNo`), `UserSubscriptions` = `Active` (12/07 → 11/08), `Notifications` sinh 1 dòng `type=payment`.
- Callback giả mạo (sửa số tiền) → bị từ chối.

### File Flutter mới

`models/app_notification.dart`, `models/subscription.dart`, `screens/notifications_screen.dart`, `screens/payment_webview_screen.dart`; sửa `screens/subscription_screen.dart` (đọc API), `screens/home_screen.dart` (icon chuông + badge), `services/api_client.dart` (7 hàm mới). Thêm dependency **`webview_flutter`**.

---

## 📝 Thay đổi CHƯA COMMIT (nhánh `hiepga`, tính đến 12/07/2026)

### A. Sửa code — nên commit

| File                                                         | Thay đổi                                                                     | Vì sao                                                                                                                                                                                                                                                                                                                                                                                                                                                    |
| ------------------------------------------------------------ | ------------------------------------------------------------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `lib/backend/app/api/v1/routes/realtime.py`                | Bắt message`websocket.disconnect` trong vòng lặp nhận frame              | **Bug thật.** `websocket.receive()` không ném `WebSocketDisconnect` mà trả message `type: "websocket.disconnect"`. Code cũ bỏ qua nó rồi gọi `receive()` tiếp trên socket đã đóng → `RuntimeError` mỗi lần đóng màn phân tích, và **nuốt mất dòng tổng kết phiên** (`Reps: N / Độ chính xác: X%`). Đã vá và kiểm chứng: log giờ ra `INFO Client ngắt kết nối...`, không còn ERROR |
| `android/app/build.gradle.kts`                             | Ghim Kotlin`jvmTarget = 17`                                                  | **Build hỏng nếu không có.** Java compile ở 17, Kotlin mặc định lấy theo JDK (21) → Gradle báo *"Inconsistent JVM-target compatibility"* và dừng                                                                                                                                                                                                                                                                                      |
| `lib/config/api_config.dart`                               | Host đọc từ`String.fromEnvironment('API_HOST')`, mặc định `10.0.2.2` | Trước đây hardcode`localhost` — **sai với emulator** (emulator hiểu `localhost` là chính nó). Giờ emulator chạy mặc định, còn điện thoại thật thì build kèm `--dart-define=API_HOST=<IP LAN>` mà không phải sửa code                                                                                                                                                                                                 |
| `android/app/src/main/res/xml/network_security_config.xml` | Thêm`192.168.1.9` vào whitelist cleartext                                  | Để test trên điện thoại thật qua Wi-Fi.**Lưu ý:** IP này là của máy Hiệp, người khác phải đổi. Cũng cẩn thận: XML **cấm dấu `--` trong comment** (đã làm build fail một lần)                                                                                                                                                                                                                                   |

### B. File MỚI của BE-13 + BE-14 — nên commit (tất cả đang untracked)

**Backend (10 file mới):**

```
lib/backend/app/models/notification.py        map bảng Notifications
lib/backend/app/models/subscription.py        map SubscriptionPlans/UserSubscriptions/Payments
lib/backend/app/schemas/notification.py
lib/backend/app/schemas/subscription.py
lib/backend/app/crud/notification.py          create_notification() — điểm vào dùng chung
lib/backend/app/crud/subscription.py
lib/backend/app/services/vnpay.py             ký + verify HMAC-SHA512 (hàm thuần)
lib/backend/app/api/v1/routes/notifications.py
lib/backend/app/api/v1/routes/subscriptions.py
lib/backend/tests/test_vnpay.py               8 test, đều pass
```

**Backend (sửa):** `app/api/v1/router.py` (thêm 2 include_router), `app/core/config.py` (4 biến VNPAY_*)

**Flutter (4 file mới):**

```
lib/models/app_notification.dart
lib/models/subscription.dart
lib/screens/notifications_screen.dart
lib/screens/payment_webview_screen.dart
```

**Flutter (sửa):** `lib/services/api_client.dart` (7 hàm mới), `lib/screens/home_screen.dart` (chuông + badge), `lib/screens/subscription_screen.dart` (viết lại, đọc giá từ API), `pubspec.yaml` (+ `webview_flutter`)

### C. Tài liệu — nên commit

- `CLAUDE.md` — viết lại: bản cũ vẫn ghi *"No backend, all client-side"*, sai từ khi tích hợp backend thật.
- `hiep.md` — chính file này (**đang untracked, chưa từng được commit**).

### D. Xoá thư mục thừa — nên commit

- **133 file** trong `posturex_flutter/` đã bị xoá. Prototype Flutter cũ, không được tham chiếu ở đâu, không nằm trong build nào. Đã xác minh `dart analyze` sạch sau khi xoá.

### E. Nhiễu — KHÔNG commit

- `linux/`, `macos/`, `windows/` (`generated_plugin_registrant.*`): git báo "modified" nhưng **nội dung không đổi**, chỉ là line-ending LF→CRLF → `git checkout -- linux/ macos/ windows/`
- `pubspec.lock`: `flutter pub get` tự nâng vài dependency phụ. **Lần này PHẢI commit** vì có thêm `webview_flutter` thật.
- `lib/backend/.env` — đã bị gitignore, **đừng ép commit** (chứa mật khẩu).

### Gợi ý commit (tách theo chủ đề để teammate review được)

```powershell
git checkout -- linux/ macos/ windows/     # bỏ nhiễu line-ending

# 1. Bug fix của người khác (realtime) — tách riêng để họ review/cherry-pick
git add lib/backend/app/api/v1/routes/realtime.py
git commit -m "Fix: bat message websocket.disconnect trong /ws/analyze"

# 2. Sửa để build/chay duoc
git add android/ lib/config/api_config.dart
git commit -m "Fix Kotlin jvmTarget 17 va API host cho emulator/dien thoai"

# 3. BE-13 + BE-14
git add lib/backend/app/models/notification.py lib/backend/app/models/subscription.py `
        lib/backend/app/schemas/notification.py lib/backend/app/schemas/subscription.py `
        lib/backend/app/crud/notification.py lib/backend/app/crud/subscription.py `
        lib/backend/app/services/vnpay.py lib/backend/tests/test_vnpay.py `
        lib/backend/app/api/v1/routes/notifications.py `
        lib/backend/app/api/v1/routes/subscriptions.py `
        lib/backend/app/api/v1/router.py lib/backend/app/core/config.py `
        lib/models/app_notification.dart lib/models/subscription.dart `
        lib/screens/notifications_screen.dart lib/screens/payment_webview_screen.dart `
        lib/screens/home_screen.dart lib/screens/subscription_screen.dart `
        lib/services/api_client.dart pubspec.yaml pubspec.lock
git commit -m "BE-13 thong bao trong app + BE-14 thanh toan VNPay"

# 4. Tài liệu + dọn rác
git add CLAUDE.md hiep.md
git commit -m "Cap nhat tai lieu theo codebase da gop"
git add -A posturex_flutter
git commit -m "Xoa prototype posturex_flutter khong con dung"
```

---

## 🐛 BUG CẦN SỬA — làm tiếp ngày mai

> Xếp theo mức quan trọng. Bug #1 là lỗi trong code vừa viết, sửa nhanh.

### 🔴 BUG-1 — Gói cước hết hạn KHÔNG BAO GIỜ tự tắt

**File:** `lib/backend/app/crud/subscription.py`, hàm `get_active_subscription()`

Nó chỉ lọc `Status = 'Active'`, **không so `EndDate` với hôm nay**. Hệ quả: sau 30 ngày, gói vẫn báo Active vĩnh viễn — trả tiền một lần dùng mãi mãi.

**Cách sửa:** thêm điều kiện vào câu `where`:

```python
UserSubscription.end_date >= date.today()   # hoặc end_date IS NULL
```

Làm kỹ hơn thì viết thêm một job quét định kỳ, chuyển các gói quá hạn sang `Status = 'Expired'` (giá trị này schema **có** cho phép).

**Cách kiểm chứng:** trong MySQL, `UPDATE UserSubscriptions SET EndDate = '2020-01-01' WHERE UserId = 3;` rồi gọi `GET /api/v1/subscriptions/me` — phải trả `null`, hiện tại nó vẫn trả Premium.

### 🔴 BUG-2 — Mua Premium xong KHÔNG mở khoá gì cả

**Khoảng trống lớn nhất của BE-14.** Không một endpoint nào kiểm tra gói cước của user. Trả 99.000đ xong thì app y hệt bản Free. Ngay cả giới hạn *"3 bài tập/ngày"* ghi trong mô tả gói Free cũng **không được thực thi ở đâu**.

**Cách sửa:** viết một dependency `require_premium` trong `app/utils/deps.py` (theo mẫu `get_current_admin` đã có sẵn), rồi gắn vào chỗ cần giới hạn — ví dụ đếm số buổi tập trong ngày ở `POST /workouts` và chặn nếu user Free đã đủ 3 buổi.

### 🟡 BUG-3 — Thông báo không có nguồn tự sinh

Hiện **chỉ có một chỗ duy nhất** tạo thông báo: thanh toán thành công (`routes/subscriptions.py`). Các thứ plan mô tả — *"nhắc nghỉ giải lao"*, *"tổng kết hằng ngày"* — **chưa có gì cả**, không có scheduler.

**Việc dễ làm trước:** gọi `create_notification(...)` trong `POST /api/v1/workouts` để mỗi buổi tập lưu xong thì bắn một thông báo. Hàm này đã viết sẵn ở `app/crud/notification.py`, chỉ cần import và gọi.

### 🟡 BUG-4 — Chưa có test cho notification & subscription

Mới chỉ có `tests/test_vnpay.py` (8 test cho phần chữ ký). Các endpoint notification/subscription mới chỉ được kiểm bằng script chạy tay, **chưa có test tự động**.

---

## ⚠️ Nợ kỹ thuật — CỦA NGƯỜI KHÁC, chỉ báo lại, ĐỪNG tự sửa

1. **MediaPipe chạy đồng bộ trong hàm `async`** (`realtime.py`, chỗ gọi `_pose_estimator.estimate()`) → **khoá event loop**. Một người dùng thì không sao; **hai người demo cùng lúc là cả server đứng**, kể cả các API REST khác. Cần đẩy sang `run_in_executor`.
2. **Một `PoseEstimator` global dùng chung mọi kết nối** → MediaPipe không an toàn khi chạy song song, kết quả có thể lẫn giữa 2 người.
3. **WebSocket `/ws/analyze` không có auth** — ai cũng gọi được, server không biết phiên thuộc user nào.
4. **Bảng `PostureErrorTypes` bị bỏ không** — có sẵn `ErrorCode`, `CorrectionTip`, `VoicePrompt` trong DB, nhưng `squat.py` hardcode toàn bộ câu lỗi. Tính năng đọc lỗi bằng giọng nói mà DB đã chuẩn bị sẵn đang không ai dùng.

---

## 🔐 Vấn đề bảo mật cần báo cả nhóm (chưa sửa)

1. **Mật khẩu MySQL thật bị commit vào git**: `lib/backend/.env.example` **đang được git theo dõi** và chứa `DB_PASSWORD=Trumsolo456@`. Nằm trong lịch sử git, ai clone cũng đọc được → nên **đổi mật khẩu đó** và thay bằng placeholder.
2. **`SECRET_KEY` mặc định là `"change-me-in-production"`** — vì `.env` bị gitignore, ai clone về mà chưa tạo `.env` đều đang ký JWT bằng khoá công khai → **giả mạo được token của bất kỳ ai, kể cả admin**.
3. **CORS mở toang**: `allow_origins=["*"]` đi kèm `allow_credentials=True`.
4. **Không có rate limit ở `POST /auth/login`** → dò mật khẩu vô hạn.
5. **Backdoor admin cứng** `admin@gmail.com` / `123456` trong `login_screen.dart`.

---

## 📊 Tình trạng thật so với plan (12/07/2026)

| Mục | Plan ghi | Thực tế |
|---|---|---|
| BE-02 CI/CD | Hoàn thành | ❌ **Không có `.github/workflows`** |
| BE-03 Microservice | Hoàn thành | ❌ Thực tế là **monolith** |
| BE-07 API hồ sơ | Chưa bắt đầu | ✅ **Đã xong** |
| BE-09 WebSocket | Đang làm | ✅ **Đã xong**, đã test với người thật |
| BE-11 Pose estimation | Xong | ✅ Đúng (nhưng nằm trong monolith) |
| BE-12 Phân loại tư thế | Chưa bắt đầu | ⚠️ Có gắn nhãn lỗi squat, nhưng **rule-based** chứ không phải model ML |
| **BE-13 Thông báo** | Chưa bắt đầu | ⚠️ **~50%** — hạ tầng xong, thiếu nguồn tự sinh + FCM |
| **BE-14 Thanh toán** | Chưa bắt đầu | ⚠️ **~60%** — VNPay xong, thiếu hết hạn/gia hạn/huỷ + **Premium chưa mở khoá gì** |
| BE-15 Test ≥80% | Chưa bắt đầu | ❌ Backend mới có **13 test** |
| BE-10, 16, 17, 18-20 | Chưa bắt đầu | ❌ Đúng |

⚠️ **Lưu ý cho báo cáo:** plan ghi công cụ thanh toán là *"Stripe / IAP"*. Google Play **bắt buộc** dùng Google Play Billing cho nội dung số — bán Premium qua VNPay là **vi phạm chính sách nếu lên store**. Đồ án thì không sao, nhưng **đừng ghi là "đã tích hợp IAP"**.
