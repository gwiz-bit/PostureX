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

`.env` hiện để **khoá GIẢ** (`VNPAY_TMN_CODE=DEMOTMN`) — đủ để giả lập callback và test luồng, **nhưng không mở được trang thanh toán thật**. Muốn thanh toán thật: đăng ký [https://sandbox.vnpayment.vn](https://sandbox.vnpayment.vn) lấy TmnCode + HashSecret rồi điền vào `.env`.

### Đã sửa luôn: giá trong app lệch với database

Màn Subscription cũ **hardcode** `0₫ / 199.000₫ / 299.000₫`, trong khi DB bán `Free 0₫ / Premium 99.000₫ / Pro 199.000₫`. Giờ đọc từ `GET /subscriptions/plans` nên không thể lệch nữa.

### Kiểm chứng (chạy thật, không phải lý thuyết)

- `pytest tests/test_vnpay.py` — **8/8 pass** (ký, verify, chống sửa số tiền, sai secret, thiếu hash).
- Giả lập trọn luồng: checkout → callback ký đúng → **MySQL**: `Payments` 1 dòng `Completed` (99.000đ, có `TransactionNo`), `UserSubscriptions` = `Active` (12/07 → 11/08), `Notifications` sinh 1 dòng `type=payment`.
- Callback giả mạo (sửa số tiền) → bị từ chối.

### File Flutter mới

`models/app_notification.dart`, `models/subscription.dart`, `screens/notifications_screen.dart`, `screens/payment_webview_screen.dart`; sửa `screens/subscription_screen.dart` (đọc API), `screens/home_screen.dart` (icon chuông + badge), `services/api_client.dart` (7 hàm mới). Thêm dependency **`webview_flutter`**.

---

## 📦 TÌNH TRẠNG COMMIT — 12/07/2026

Nhánh `hiepga`, tổng **6 commit**. Working tree sạch (trừ `linux/ macos/ windows/` là
nhiễu line-ending, cố ý không commit).

> ⚠️ **5 commit đầu đã push. Commit thứ 6 (`17951e9`, sửa bug) CHƯA PUSH.**

### 5 commit đầu — đã push (tách theo chủ đề để review được)

| Commit      | Nội dung                                                                                                                                                                                                 |
| ----------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `94d8c34` | **Fix: bắt message `websocket.disconnect` trong `/ws/analyze`** — *tách riêng có chủ ý*, vì đây là code của thành viên khác. Gửi họ đúng mã commit này để cherry-pick. |
| `9c56e81` | Fix Kotlin`jvmTarget = 17` + API host cho emulator/điện thoại (không có thì **không build được**)                                                                                       |
| `d0ec4d7` | **BE-13 thông báo + BE-14 thanh toán VNPay** — 21 file                                                                                                                                          |
| `b60459c` | Cập nhật tài liệu (`CLAUDE.md`, `hiep.md`)                                                                                                                                                        |
| `26ff29b` | Xoá prototype`posturex_flutter` (133 file)                                                                                                                                                             |

### Đã kiểm chứng trước khi push

- Commit BE-13/BE-14 **không phải điểm hỏng**: chạy `import app.main` từ đúng trạng thái đã commit → backend nạp được, chứng minh `router.py` + `config.py` đã đi kèm. (Nếu chỉ commit 10 file model/route mà quên 2 file này thì backend **crash ngay khi import**.)
- **Không commit** `linux/`, `macos/`, `windows/` — git báo "modified" nhưng nội dung không đổi, chỉ là line-ending LF→CRLF. Commit vào chỉ tạo conflict vô nghĩa cho teammate.
- **`lib/backend/.env` KHÔNG bị đẩy lên** (đã kiểm tra 2 cách) — mật khẩu MySQL và khoá VNPay vẫn nằm yên trên máy.

### Commit thứ 6 — sửa bug (12/07 chiều)

| Commit      | Nội dung                                              | Trạng thái                          |
| ----------- | ------------------------------------------------------ | ------------------------------------- |
| `17951e9` | **Fix BUG-1..BUG-4** — 11 file, +703/−96 dòng | ⚠️**ĐÃ COMMIT, CHƯA PUSH** |

11 file trong commit này:

```
lib/backend/app/crud/subscription.py        (BUG-1 het han + is_premium)
lib/backend/app/models/subscription.py      (them hang so SUBSCRIPTION_EXPIRED)
lib/backend/app/utils/deps.py               (BUG-2 require_premium)
lib/backend/app/api/v1/routes/workouts.py   (BUG-2 gioi han Free + BUG-3 thong bao)
lib/backend/tests/conftest.py               (MOI - ha tang test SQLite)
lib/backend/tests/test_subscriptions.py     (MOI - 9 test)
lib/backend/tests/test_workout_limit.py     (MOI - 6 test)
lib/backend/tests/test_notifications.py     (MOI - 7 test)
lib/backend/requirements.txt                (them aiosqlite)
lib/screens/analyze_session_screen.dart     (hien loi khi khong luu duoc buoi tap)
hiep.md
```

**Việc đầu tiên khi mở máy lần sau:**

```powershell
cd D:\clonecode\PostureX
git push          # day commit 17951e9 len nhanh hiepga
```

### Trạng thái nhánh

```
main     ── ... ── c4cc5f1 (Merge branch 'Viet')
                        \
hiepga                   94d8c34 → 9c56e81 → d0ec4d7 → b60459c → 26ff29b   ← đã push
                                                                      \
                                                                       17951e9  ← CHƯA push
```

`main` **không bị đụng tới**. Nhánh `hiepga` vẫn commit tiếp bình thường — push xong nhánh **không hề "đóng"**.

### Pull Request — giờ đã tạo được

Trước đây ghi "đừng bấm PR vì còn 2 bug đỏ". **Bug đã sửa xong**, nên sau khi `git push` là có thể bấm *"Compare & pull request"* để nhóm review.

Nhớ trong phần mô tả PR: nói rõ commit `94d8c34` (fix WebSocket) là **code của thành viên khác**, để họ biết mà xem lại.

---

## 🔴 REPO ĐANG ĐỂ PUBLIC — cần xử lý

`github.com/gwiz-bit/PostureX` là repo **Public** (đã có **1 fork**). Nghĩa là ai trên internet cũng đọc được:

- `lib/backend/.env.example` → chứa **mật khẩu MySQL thật** của một máy trong nhóm (giá trị cụ thể xem trong lịch sử git — cố ý không chép lại vào đây)
- `login_screen.dart` → backdoor admin cứng `admin@gmail.com` / `123456`
- `config.py` → `SECRET_KEY` mặc định `"change-me-in-production"` → **ai cũng ký được JWT giả mạo bất kỳ user nào, kể cả admin**

**Việc cần làm:**

1. GitHub → **Settings** → **General** → **Danger Zone** → **Change repository visibility** → **Private**.
2. Chuyển private **không xoá được thứ đã lộ** → vẫn phải **báo nhóm đổi mật khẩu MySQL đã bị lộ**, và thay giá trị trong `.env.example` bằng placeholder.

---

## ✅ ĐÃ SỬA XONG 4 BUG — 12/07/2026 (buổi chiều)

Cả 4 bug ghi hôm qua **đã sửa xong và kiểm chứng**. Test tăng từ **13 → 35**.

### 🔴 BUG-1 — Gói hết hạn không bao giờ tự tắt → ĐÃ SỬA

**File:** `app/crud/subscription.py` → `get_active_subscription()`, `app/models/subscription.py`

Hàm cũ chỉ lọc `Status = 'Active'`, không nhìn `EndDate` → trả tiền một lần dùng vĩnh viễn.

Giờ hàm này **tự lật gói quá hạn sang `Status = 'Expired'` ngay lúc đọc**. Chọn cách này thay vì viết cron job vì nhóm không có hạ tầng chạy job định kỳ — mà kết quả thì tương đương, gói hết hạn tắt ngay lần gọi API kế tiếp. Thêm hằng số `SUBSCRIPTION_EXPIRED` ('Expired' là giá trị schema **có** cho phép).

Lưu ý: `EndDate = NULL` được coi là **còn hiệu lực** (dữ liệu cũ không ghi hạn — không tự ý tắt gói của người ta). Gói hết hạn **đúng hôm nay** vẫn dùng được, không cắt sớm một ngày.

**Đã kiểm chứng trên MySQL thật:** `UPDATE UserSubscriptions SET EndDate='2020-01-01'` → `GET /subscriptions/me` trả `null`, và dòng trong DB tự chuyển `Active → Expired`.

### 🔴 BUG-2 — Mua Premium không mở khoá gì → ĐÃ SỬA

**File:** `app/utils/deps.py`, `app/crud/subscription.py`, `app/api/v1/routes/workouts.py`

- `require_premium` — dependency mới trong `deps.py` (theo đúng mẫu `get_current_admin`). Gắn vào route nào thì route đó thành tính năng trả phí:
  ```python
  current_user: User = Depends(require_premium)
  ```
- `is_premium(db, user_id)` trong `crud/subscription.py` — **không chỉ hỏi "có gói Active không"**: một dòng Active trỏ vào gói giá 0 vẫn là người dùng miễn phí.
- `POST /workouts` giờ **thực thi giới hạn 3 buổi/ngày** của gói Free (con số lấy đúng từ cột `Features` của bảng `SubscriptionPlans`, không bịa). Buổi thứ 4 → **403**. Ngày reset tính theo **giờ VN (UTC+7)**, không theo UTC.

**Đã kiểm chứng:** user Free → 3 buổi OK, buổi 4 trả 403. Bật Premium → buổi 4, 5 vào bình thường.

**Phía app cũng phải sửa theo:** `analyze_session_screen.dart` trước đây `catch (_) {}` nuốt lỗi lưu buổi tập — người dùng Free bị chặn vẫn thấy bảng tổng kết như thường và tưởng đã lưu. Giờ lỗi được hiện ngay trong hộp thoại tổng kết.

### 🟡 BUG-3 — Thông báo không có nguồn tự sinh → ĐÃ SỬA

`POST /workouts` giờ tự bắn thông báo `type='workout'` sau mỗi buổi tập ("squat · 15 lần · độ chính xác 92% · 3 phút"). Buổi tập **bị chặn thì không sinh thông báo** (có test riêng cho việc này).

Vẫn **chưa có** scheduler cho "nhắc nghỉ giải lao" / "tổng kết hằng ngày" — những thứ đó cần job định kỳ, chưa làm.

### 🟡 BUG-4 — Chưa có test → ĐÃ SỬA

Dựng hạ tầng test thật: **`tests/conftest.py`** chạy trên **SQLite trong bộ nhớ** (thêm `aiosqlite` vào `requirements.txt`), ghi đè `get_db`. Nghĩa là `pytest` chạy được trên máy bất kỳ ai, **không cần cài MySQL**, không đụng dữ liệu thật.

| File test                       | Số test | Nội dung                                                                                               |
| ------------------------------- | -------- | ------------------------------------------------------------------------------------------------------- |
| `tests/test_subscriptions.py` | 9        | Hết hạn, gói Free-giá-0, chặn checkout gói 0đ, yêu cầu auth                                    |
| `tests/test_workout_limit.py` | 6        | Hạn mức Free, Premium không bị chặn, gói hết hạn tụt về hạn mức Free                        |
| `tests/test_notifications.py` | 7        | Đếm chưa đọc, đánh dấu đã đọc,**không đọc được thông báo của người khác** |

**Đã kiểm tra test có "răng" thật:** cố tình phá lại fix BUG-1 → đúng 3 test đỏ lên. Test không phải để chạy cho đẹp.

> ⚠️ **Giới hạn:** SQLite không có CHECK constraint như MySQL (`CK_UserSub_Status`...). Test ở đây **không bắt được** lỗi ghi sai giá trị Status — phần đó vẫn phải dựa vào hằng số trong `app/models/subscription.py`.

### Cần commit (nhánh `hiepga`)

```powershell
git add lib/backend/app/crud/subscription.py lib/backend/app/models/subscription.py `
        lib/backend/app/utils/deps.py lib/backend/app/api/v1/routes/workouts.py `
        lib/backend/tests/conftest.py lib/backend/tests/test_subscriptions.py `
        lib/backend/tests/test_workout_limit.py lib/backend/tests/test_notifications.py `
        lib/backend/requirements.txt lib/screens/analyze_session_screen.dart hiep.md
git commit -m "Fix BUG-1..BUG-4: het han goi, quyen Premium, thong bao tu sinh, them test"
git push
```

---

## 🆕 ĐỢT 3 — Scheduler, Push, Quản lý gói (13/07/2026, rạng sáng)

> ✅ **ĐÃ COMMIT VÀ PUSH** lên nhánh `hiepga` — commit `41d5e09` + `900ebe2`.
> Test: **69 passed** (13 → 35 → 44 → 54 → 69).

### 1️⃣ Scheduler — 3 job định kỳ (BE-13)

Trước đây plan ghi *"nhắc nghỉ giải lao, tổng kết hằng ngày"* nhưng **không có gì cả** vì thiếu hạ tầng chạy job. Giờ đã có, dùng **APScheduler** cắm vào `lifespan` của FastAPI.

| Job | Giờ chạy (giờ VN) | Gửi cho ai |
|---|---|---|
| **Nhắc nghỉ giải lao** | 10h, 15h | Người **hôm nay chưa tập buổi nào**. Ai đã tập rồi thì bỏ qua — nhắc họ "đứng dậy vận động đi" là vô duyên. |
| **Tổng kết hằng ngày** | 20h | Người **có tập**. Không tập thì im lặng (đã nhắc nghỉ rồi, cằn nhằn thêm làm gì). |
| **Nhắc gia hạn** | 9h | Gói còn ≤ 3 ngày **và** đang bật tự động gia hạn. |

**File:** `app/services/reminders.py` (job, hàm thuần — test gọi thẳng được), `app/core/scheduler.py` (lịch chạy), `app/main.py` (lifespan).

**Chạy tay để test, không phải chờ tới 20h:**
```powershell
python run_jobs_now.py break     # nhac nghi giai lao
python run_jobs_now.py summary   # tong ket hang ngay
python run_jobs_now.py expiry    # nhac sap het han
python run_jobs_now.py all
```

> 🔴 **GIỚI HẠN PHẢI BIẾT — đừng nhầm là bug:** đây là scheduler **trong tiến trình**, KHÔNG phải cron của hệ điều hành. **Server tắt thì job không chạy.** Tổng kết 20h sẽ bị bỏ lỡ nếu lúc đó máy tắt. Triển khai thật phải đẩy sang cron/cloud scheduler. **Đừng ghi trong báo cáo là "đã có cron job".**

**Chống trùng lặp** là phần quan trọng nhất: `uvicorn --reload` khởi động lại liên tục, không cẩn thận là mỗi lần reload bắn thông báo lần nữa. Trước khi gửi, job hỏi DB "user này đã nhận thông báo loại đó gần đây chưa" (`users_notified_since`).

### 2️⃣ Push notification — BACKEND xong, Flutter CHƯA (BE-13)

Gọi thẳng **FCM HTTP v1** bằng `google-auth` + `httpx` — repo đã có sẵn cả hai, **không thêm thư viện nào** (`firebase-admin` quá nặng cho việc này).

**File mới:** `app/services/push.py`, `app/services/notifier.py`, `app/models/device_token.py`, `app/crud/device_token.py`
**Endpoint mới:** `POST /notifications/device-token`, `DELETE /notifications/device-token`
**Bảng mới:** `device_tokens` (đã tạo trong MySQL)

Cắm vào `create_notification()`, nên **mọi loại thông báo tự động có push** — kể cả 3 job trên.

**Chưa cấu hình Firebase → bỏ qua trong im lặng** (giống `vnpay_configured`). Đã kiểm chứng: lưu buổi tập vẫn 201, thông báo vẫn tạo, không lỗi. Firebase sập cũng không làm mất buổi tập của ai.

> ⏸️ **Còn thiếu:** `google-services.json` + khoá service account (phải lấy trên Firebase Console) và phần Flutter. **Cố ý chưa đụng Gradle** — apply plugin Firebase mà thiếu file config là **build đỏ ngay**.

### 3️⃣ Quản lý gói cước (BE-14)

**Endpoint mới:** `POST /subscriptions/cancel`, `POST /subscriptions/resume`, `GET /payments`

- **Huỷ gói KHÔNG cắt quyền ngay.** Khách đã trả tiền tới `EndDate` → gói vẫn Active tới ngày đó rồi mới tự hết hạn. Cắt ngay là ăn chặn ngày họ đã mua. Đã kiểm chứng trên MySQL: huỷ xong `auto_renew=false` nhưng buổi tập thứ 4 vẫn `201`.
- **Gia hạn sớm được cộng dồn ngày.** Code cũ đặt lại `end_date = today + 30` → còn 10 ngày mà gia hạn là **mất trắng 10 ngày**. Giờ được 40. Không sửa thì không ai dám bấm gia hạn sớm. (Đổi sang gói khác thì tính lại từ đầu — proration cố tình không làm.)
- **`AutoRenew` mặc định BẬT khi mua gói** (trước đây luôn = 0, nên không ai từng được nhắc gia hạn).

> 🔴 **SỰ THẬT VỀ "TỰ ĐỘNG GIA HẠN" — quan trọng cho báo cáo:** VNPay trong tích hợp hiện tại **KHÔNG trừ tiền định kỳ được**. Cờ `AutoRenew` **không tự thu tiền** — nó chỉ quyết định có gửi thông báo nhắc gia hạn hay không. **Đừng ghi là "đã có tự động gia hạn".**

**App:** màn gói cước giờ hiện *"Còn 2 ngày · hết hạn 15/07"*, trạng thái gia hạn, nút huỷ/bật lại. Hộp thoại huỷ nói rõ *"Bạn vẫn dùng bình thường tới ngày X"* — người dùng hay tưởng bấm huỷ là mất quyền ngay.

### 🐛 Bug chỉ MySQL mới lộ ra (test SQLite không bắt được)

69 test SQLite đều xanh, nhưng chạy thật trên MySQL thì phát hiện: thông báo *"Đã huỷ tự động gia hạn"* dùng **chung nhãn `subscription`** với lời nhắc hết hạn. Mà job chống trùng bằng cách hỏi *"đã nhận thông báo loại đó chưa"* → **một lần huỷ gói nuốt mất lời nhắc hết hạn của cả tuần sau**. Ai đổi ý bật lại gia hạn sẽ không bao giờ được nhắc, rồi mất quyền mà không hiểu vì sao.

**Đã sửa:** tách nhãn `subscription_expiry` riêng. Đã viết test bắt đúng ca này và **kiểm tra test có răng** (quay lại nhãn cũ → test đỏ đúng cái đó).

**Bài học:** test xanh ≠ chạy đúng. SQLite không có CHECK constraint, không có ràng buộc thật của MySQL.

### 🧹 Dọn dẹp kèm theo

- **`app/utils/timezone.py`** (mới) — `VN_TZ` đang lặp ở 2 nơi, sắp thành 3. Gom về một chỗ.
- **`.env.example`** — đã thay mật khẩu MySQL thật của teammate bằng placeholder.
- **`.gitignore`** — chặn file khoá Firebase (commit lên là ai cũng gửi push được cho toàn bộ user).
- **`notifications_screen.dart`** — có nhánh icon `'reminder'` mà backend **không bao giờ gửi** (code chết). Đã thay bằng 4 nhãn thật.

### 💥 Tôi đã lỡ xoá dữ liệu — và đây là quả mìn cho cả nhóm

Chạy `create_tables.py` để tạo bảng `device_tokens` → **nó có `DROP TABLE workouts` ở đầu**, xoá sạch bảng `workouts` + `videos`. Mất 1 buổi tập test (không đáng kể).

> 🔴 **CẢNH BÁO CẢ NHÓM:** `create_tables.py` **XOÁ TOÀN BỘ lịch sử tập của mọi người dùng** mỗi lần chạy. Tài liệu chỉ ghi nhẹ "chỉ chạy lần đầu" — không có gì ngăn ai đó chạy lại. **Tôi đã dính. Người khác cũng sẽ dính.** Nên sửa script này (thêm xác nhận, hoặc bỏ DROP đi).

### 📋 Đã commit thành 2 (không phải 3)

| Commit | Nội dung | File |
|---|---|---|
| `41d5e09` | **FCM push — backend** | 13 |
| `900ebe2` | **Scheduler + BE-14 quản lý gói** | 18 |

**Vì sao không tách 3 như dự định:** ba mảng này **phụ thuộc chéo nhau** — `services/reminders.py` (scheduler) cần `get_expiring_subscriptions()` từ `crud/subscription.py` (nhóm BE-14), còn `tests/conftest.py` cần model `device_token` (nhóm FCM). Tách rời ra thì **commit ở giữa không import được**. Gộp thành 2 commit thật sự độc lập.

**Đã kiểm chứng từ trạng thái ĐÃ COMMIT** (giải nén `git archive` ra thư mục tạm rồi chạy từ đó, không tin file trên đĩa):
- `import app.main` → OK. *Nếu quên một file thì backend crash ngay khi import — đây là cách duy nhất bắt được lỗi đó.*
- `pytest` → **69 passed**
- `.env` và khoá Firebase **chưa từng lọt vào lịch sử git** (kiểm tra toàn bộ lịch sử, không chỉ commit mới nhất)

---

## ⚠️ Nợ kỹ thuật — CỦA NGƯỜI KHÁC, chỉ báo lại, ĐỪNG tự sửa

1. **MediaPipe chạy đồng bộ trong hàm `async`** (`realtime.py`, chỗ gọi `_pose_estimator.estimate()`) → **khoá event loop**. Một người dùng thì không sao; **hai người demo cùng lúc là cả server đứng**, kể cả các API REST khác. Cần đẩy sang `run_in_executor`.
2. **Một `PoseEstimator` global dùng chung mọi kết nối** → MediaPipe không an toàn khi chạy song song, kết quả có thể lẫn giữa 2 người.
3. **WebSocket `/ws/analyze` không có auth** — ai cũng gọi được, server không biết phiên thuộc user nào.
4. **Bảng `PostureErrorTypes` bị bỏ không** — có sẵn `ErrorCode`, `CorrectionTip`, `VoicePrompt` trong DB, nhưng `squat.py` hardcode toàn bộ câu lỗi. Tính năng đọc lỗi bằng giọng nói mà DB đã chuẩn bị sẵn đang không ai dùng.

---

## 🔐 Vấn đề bảo mật cần báo cả nhóm (chưa sửa)

1. **Mật khẩu MySQL thật bị commit vào git**: `lib/backend/.env.example` **đang được git theo dõi** và từng chứa mật khẩu thật. Nằm trong lịch sử git, ai clone cũng đọc được → **phải đổi mật khẩu đó**. (File hiện tại đã thay bằng placeholder, nhưng lịch sử thì không xoá được.)
2. **`SECRET_KEY` mặc định là `"change-me-in-production"`** — vì `.env` bị gitignore, ai clone về mà chưa tạo `.env` đều đang ký JWT bằng khoá công khai → **giả mạo được token của bất kỳ ai, kể cả admin**.
3. **CORS mở toang**: `allow_origins=["*"]` đi kèm `allow_credentials=True`.
4. **Không có rate limit ở `POST /auth/login`** → dò mật khẩu vô hạn.
5. **Backdoor admin cứng** `admin@gmail.com` / `123456` trong `login_screen.dart`.

---

## 📊 Tình trạng thật so với plan (12/07/2026)

| Mục                        | Plan ghi         | Thực tế                                                                                                                                            |
| --------------------------- | ---------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------- |
| BE-02 CI/CD                 | Hoàn thành     | ❌**Không có `.github/workflows`**                                                                                                         |
| BE-03 Microservice          | Hoàn thành     | ❌ Thực tế là**monolith**                                                                                                                   |
| BE-07 API hồ sơ           | Chưa bắt đầu | ✅**Đã xong**                                                                                                                                |
| BE-09 WebSocket             | Đang làm       | ✅**Đã xong**, đã test với người thật                                                                                                  |
| BE-11 Pose estimation       | Xong             | ✅ Đúng (nhưng nằm trong monolith)                                                                                                               |
| BE-12 Phân loại tư thế  | Chưa bắt đầu | ⚠️ Có gắn nhãn lỗi squat, nhưng**rule-based** chứ không phải model ML                                                                |
| **BE-13 Thông báo** | Chưa bắt đầu | ⚠️ **~90%** — thông báo trong app + **3 job định kỳ** + **backend push xong**. **Thiếu:** phần Flutter của FCM (chờ `google-services.json`) |
| **BE-14 Thanh toán** | Chưa bắt đầu | ⚠️ **~95%** — VNPay, hết hạn, quyền Premium, huỷ/bật lại gia hạn, cộng dồn ngày, lịch sử thanh toán. **Thiếu:** IPN (cần URL công khai) |
| BE-15 Test ≥80%            | Chưa bắt đầu | ⚠️ Backend có **69 test** (13 → 69). Chưa đo coverage, chắc chắn **chưa tới 80%**                                               |
| BE-10, 16, 17, 18-20        | Chưa bắt đầu | ❌ Đúng                                                                                                                                            |

⚠️ **Lưu ý cho báo cáo:** plan ghi công cụ thanh toán là *"Stripe / IAP"*. Google Play **bắt buộc** dùng Google Play Billing cho nội dung số — bán Premium qua VNPay là **vi phạm chính sách nếu lên store**. Đồ án thì không sao, nhưng **đừng ghi là "đã tích hợp IAP"**.

---

## ▶️ LẦN SAU MỞ MÁY LÀM GÌ

### ✅ Trạng thái chốt (13/07/2026)

**Code đã an toàn.** Nhánh `hiepga` = **9 commit**, đã push hết lên GitHub, không còn gì nằm trên máy.
`main` **chưa bị đụng**. **Chưa tạo Pull Request** (cố ý — BE-13 còn thiếu phần Flutter của FCM).

```
main   ── c4cc5f1
              \
hiepga         94d8c34 → 9c56e81 → d0ec4d7 → b60459c → 26ff29b
               → 17951e9 → a6d3a5a → 41d5e09 → 900ebe2   ← đã push hết
```

Backend: **69 test pass**. BE-13 ~90%, BE-14 ~95%.

---

### 🔴 VIỆC SỐ 1 — Chuyển repo sang Private (1 phút, làm ngay)

`github.com/gwiz-bit/PostureX` đang **Public**, đã có **1 fork**. Đang công khai cho cả internet:

| Lộ cái gì | Ở đâu |
|---|---|
| **Mật khẩu MySQL thật** của teammate | `.env.example` — file hiện tại đã thay bằng placeholder, **nhưng giá trị cũ vẫn nằm trong LỊCH SỬ git**, đổi file không xoá được |
| **Backdoor admin** `admin@gmail.com` / `123456` | `login_screen.dart` |
| **`SECRET_KEY` mặc định** | `config.py` → ai cũng ký được JWT giả mạo **bất kỳ user nào, kể cả admin** |

**Làm:** GitHub → Settings → General → Danger Zone → **Change repository visibility** → Private.
**Rồi báo nhóm đổi mật khẩu MySQL** — chuyển private không xoá được thứ đã lộ.

> Việc này **quan trọng hơn toàn bộ code còn lại**. Đã treo 2 ngày.

---

### Việc tiếp theo (chọn 1)

| Việc | Cần gì | Ghi chú |
|---|---|---|
| **Phần Flutter của FCM** | Bạn tạo project Firebase → `google-services.json` + khoá service account | Backend **đã xong hết**. BE-13 sẽ lên 100%. Emulator Pixel_4 có Google Play → test push thật được. |
| **IPN của VNPay** | URL công khai (ngrok / deploy) | BE-14 lên 100%. Không có IPN thì khách trả tiền xong tắt app ngay → **tiền bị trừ, gói không bật**. |
| **Sửa `create_tables.py`** | Không cần gì | Xem cảnh báo bên dưới. Nhanh, và cứu cả nhóm khỏi mất dữ liệu. |
| **Tạo Pull Request** | Không cần gì | Nếu muốn chốt phần đã làm, để nhóm review. |

---

### 💣 Ba thứ PHẢI nhớ (đã trả giá để biết)

1. **`create_tables.py` XOÁ SẠCH bảng `workouts` + `videos` mỗi lần chạy.** Nó có `DROP TABLE` ở đầu. Tài liệu chỉ ghi nhẹ "chỉ chạy lần đầu". **Tôi đã dính và mất dữ liệu test của bạn.** Người khác cũng sẽ dính.

2. **uvicorn chạy sẵn từ phiên trước KHÔNG tự nạp code mới.** Sửa code xong mà API vẫn trả kết quả cũ → **tắt hẳn rồi chạy lại**, đừng ngồi debug code. Đã mất thời gian vì đúng chuyện này.

3. **Test xanh ≠ chạy đúng.** 69 test SQLite đều pass nhưng vẫn có bug chỉ MySQL mới lộ ra (xem mục "Bug chỉ MySQL mới lộ ra"). SQLite không có CHECK constraint và ràng buộc thật của MySQL. **Việc gì quan trọng thì phải chạy thử trên MySQL.**

---

### ⚠️ Ba điều ĐỪNG ghi sai trong báo cáo

- **Đừng ghi "đã có cron job"** — scheduler chạy *trong tiến trình*, server tắt là job không chạy.
- **Đừng ghi "đã có tự động gia hạn"** — VNPay không trừ tiền định kỳ được. Cờ `AutoRenew` chỉ để *nhắc* gia hạn.
- **Đừng ghi "đã tích hợp IAP"** — dùng VNPay, không phải in-app purchase. (Và VNPay bán nội dung số là **vi phạm chính sách Google Play** nếu lên store.)

### Chạy lại hệ thống (nhắc nhanh)

```powershell
cd D:\clonecode\PostureX\lib\backend
venv\Scripts\activate
uvicorn app.main:app --reload --host 0.0.0.0 --port 9000
pytest                     # phai thay 69 passed
python run_jobs_now.py all # chay tay 3 job dinh ky, khong phai cho toi gio
```

Tài khoản test: `test@posturex.com` / `Test123` (UserId = 3).

> ⚠️ **Bẫy đã dính một lần:** uvicorn chạy sẵn từ phiên trước **không tự nạp code mới**. Sửa code xong mà API vẫn trả kết quả cũ thì **tắt hẳn rồi chạy lại**, đừng ngồi debug code (đã mất thời gian vì đúng chuyện này).

> ⚠️ **Dữ liệu test trong MySQL đã bị nghịch nhiều lần.** UserId 3 (`test@posturex.com`) hiện có: gói Premium hết hạn 15/07 (đã tắt tự gia hạn), vài buổi tập giả, một token FCM giả (`fake-fcm-token-tu-may-that`) trong bảng `device_tokens`. **Không phải dữ liệu thật, cứ xoá thoải mái:**
>
> ```sql
> DELETE FROM Payments WHERE UserSubscriptionId IN (SELECT UserSubscriptionId FROM UserSubscriptions WHERE UserId=3);
> DELETE FROM UserSubscriptions WHERE UserId=3;
> DELETE FROM workouts WHERE user_id=3;
> DELETE FROM Notifications WHERE UserId=3;
> DELETE FROM device_tokens WHERE user_id=3;
> ```
> (Xoá `Payments` trước rồi mới `UserSubscriptions` — ngược lại sẽ vướng khoá ngoại.)
