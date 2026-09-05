# Lỗi cần sửa

Ghi lại lỗi phát hiện khi thử app, kèm nguyên nhân đã truy được và cách kiểm
chứng lại. Mục đã sửa xong và xác nhận được thì gỡ khỏi file để tránh nhầm —
lịch sử đầy đủ luôn có trong `git log`. Mục mới nhất ở trên cùng.

---

## ▶ BẮT ĐẦU TỪ ĐÂY (phiên sau)

### 1. ~~SMTP trên VPS bị Gmail từ chối~~ — ĐÃ SỬA 05/09/2026

VanGiap sửa lại khoá ứng dụng Gmail trong `.env` trên VPS. Đã xác nhận bằng
cách gọi thẳng API (không qua app):

```bash
curl -X POST -H "Content-Type: application/json" \
  -d "{\"username\":\"x\",\"email\":\"x@example.com\",\"password\":\"Xyz123456@\"}" \
  http://103.82.21.150:9000/api/v1/auth/register
```

Trước: `535, 5.7.8 Username and Password not accepted`. Sau: tạo tài khoản
thành công, không còn lỗi SMTP. Tài khoản test đã xoá khỏi DB thật ngay sau
khi xác nhận.

`GOOGLE_CLIENT_ID` hoá ra **đã đúng từ trước** — đọc `.env` qua SSH thấy đã là
`526667437213-...`, khớp với app. Nghĩa là lỗi "Could not sign in with
Google" ban đầu **không phải do config này**; rất có thể chỉ là hệ quả phụ
của việc backend liên tục trả lỗi 500 lúc SMTP còn hỏng, hoặc một nguyên nhân
khác chưa xác định — cần thử lại Google Sign-In trên máy thật để biết chắc còn
lỗi hay không (xem mục 3 bên dưới, gộp chung vào lượt thử đó).

<details>
<summary>Triệu chứng gốc lúc phát hiện (05/09/2026, trước khi sửa)</summary>

**Ba triệu chứng, cùng một gốc:**

| # | Thao tác | Hiện tượng |
|---|---|---|
| 1 | Đăng nhập Google | "Could not sign in with Google. Check your connection." |
| 2 | Tạo tài khoản mới | "Something went wrong. Please try again." |
| 3 | Quên mật khẩu → gửi mã | Báo thành công nhưng **không có mã nào gửi tới** |

**Lỗi 2 và 3 dùng chung một nguyên nhân**, đã xác nhận bằng cách gọi thẳng API
trên VPS (không qua app, không phải suy đoán):

```bash
curl -X POST -H "Content-Type: application/json" \
  -d "{\"username\":\"x\",\"email\":\"x@example.com\",\"password\":\"Xyz123@\"}" \
  http://103.82.21.150:9000/api/v1/auth/register
```

Kết quả:

```
{"detail":"Không gửi được email OTP... 535, 5.7.8 Username and Password not accepted..."}
```

`SMTP_PASSWORD` (hoặc `SMTP_USERNAME`) trong `.env` trên VPS bị Gmail từ chối
— khoá ứng dụng hết hạn, bị thu hồi, hoặc gõ sai lúc điền `.env`.

Đăng ký bắt buộc gửi OTP ngay khi tạo tài khoản → SMTP chết là đăng ký chết
theo, đúng như ảnh "Something went wrong".

Quên mật khẩu thì **im lặng theo đúng thiết kế bảo mật**, không phải giao diện
giả. Trong `app/api/v1/routes/auth.py`, hàm `forgot_password()` bắt lỗi gửi
email chỉ để ghi log, không báo cho người dùng biết, rồi luôn trả về cùng một
câu "Nếu email tồn tại...". Trả lời giống nhau bất kể email có tồn tại hay
không là để chống dò danh sách email (user enumeration) — đúng chủ đích. Nhưng
hệ quả phụ: khi SMTP hỏng, không ai biết được mã không gửi đi, kể cả người
dùng lẫn dev đang thử tay, trừ khi có quyền đọc log server.

**Lỗi 1 (Google Sign-In) có nguyên nhân khác, đã biết từ trước:** `.env` trên
VPS còn giữ `GOOGLE_CLIENT_ID` cũ, app đã đổi sang client mới
(`526667437213-...`). Backend đối chiếu claim `aud` của token với giá trị
trong `.env` — lệch là từ chối thẳng.

**Sửa ở đâu:** cả hai đều nằm trong `backend/.env` trên VPS, cần sudo.

```bash
sudo nano /opt/posturex/backend/.env
sudo systemctl restart posturex
```

</details>

### 2. ~~Có SSH nhưng chưa deploy được — sudo sai mật khẩu~~ — ĐÃ SỬA 05/09/2026

Nguyên nhân thật (theo VanGiap xác nhận): SSH của `hiephann` vào được **ngay
từ đầu**, chỉ có bước đặt mật khẩu sudo (`chpasswd`) chưa được chạy nên tài
khoản còn khoá — mọi lần gõ `sudo` bị từ chối trông giống lỗi đăng nhập nhưng
thực chất là lỗi xác thực sudo. VanGiap đã `passwd -S` xác nhận trạng thái
chuyển từ khoá sang `P` (đã đặt mật khẩu), gửi lại `G3BDuyRDORSyr3S7h02G` —
**chỉ dùng để `sudo`, không dùng để SSH**.

Đã dùng để deploy thành công ngay trong phiên này:

```bash
sudo git -C /opt/posturex pull origin main
sudo systemctl restart posturex
cd /opt/posturex/backend && sudo venv/bin/python scripts/seed_posture_rules.py
```

Xác nhận qua API thật (không phải đọc log):

```
/api/v1/admin/posture-rules   404 → 403   (route mới đã chạy)
/api/v1/admin/config          403 → 404   (route cũ đã gỡ)
```

`seed_posture_rules.py` ghi 6/6 dòng thành công (đã có sẵn từ lần chạy trước
nên hiện "cập nhật" chứ không phải "thêm mới") — xác nhận lại bằng cách đọc
thẳng DB qua SSH, khớp đúng giá trị mong đợi cho cả 5 bài
(`Seal Row`, `Machine Hack Squat` ×2 khoá, `Reverse Hack Squat`,
`Inverted Row`, `Chest Supported Dumbbell Row`).

VanGiap cũng đã ghi lại nguyên nhân + cách fix vào `docs/DEPLOY_SERVER.md`
(mục 1a) để tra cứu nếu lặp lại.

### 3. Xác nhận bản sửa video trên máy thật với VPS — chưa làm, giờ không còn gì chặn

Bản sửa lỗi "mọi bài tập phát video Squat" đã lên `main` (commit `a7e6a97`),
đã có 10 test tự động xanh. Mục 1 và 2 vốn chặn việc đăng nhập vào app trỏ
VPS đều đã sửa xong — giờ chỉ còn mỗi việc ngồi bấm.

Thử theo bảng này:

```powershell
flutter emulators --launch Pixel_4
flutter run --dart-define=API_BASE_URL=http://103.82.21.150:9000
```

| Bài | Kỳ vọng |
|---|---|
| **Bicep Curl, Lunge, Plank, Push-up** | "Bài này chưa có video hướng dẫn." — **không phải** video squat |
| **Squat** | video squat đóng gói (đúng bài) |
| Bài bất kỳ khác (412 bài) | video riêng của bài đó |

Thử luôn ở tab **Workout**, không chỉ tab **Exercises** — hai nơi dùng chung
`GuideVideoPlayer` nhưng chưa ai xác nhận tab Workout đi đúng đường code này.

### 4. ~~Thử màn admin AI Config trên máy thật~~ — ĐÃ THỬ 05/09/2026

Bấm qua giao diện thật bằng `adb` (đăng nhập admin, mở từng bài, kéo thanh
trượt, lưu, xác nhận qua API rằng DB ghi đúng). Danh sách 3 bài, huy hiệu,
đơn vị `knee_overshoot` không có dấu độ — đều đúng như thiết kế.

**Tìm được một lỗi tràn layout thật, không phải trong test mà ngay trên thiết
bị** — đúng cái bẫy `CLAUDE.md` cảnh báo (font test hẹp hơn font thật nên
`flutter test` không bắt được):

```
A RenderFlex overflowed by 18 pixels on the right.
Row: exercise_rules_screen.dart:238
```

Hàng huy hiệu ("Đã chỉnh · mặc định 95°" + "Ảnh hưởng đếm rep") cộng với nút
"Về mặc định" nhét chung một `Row` cứng — tràn khi bài vừa bị ghi đè vừa có cờ
đếm rep. Đã sửa: đổi thành `Wrap` cho hai huy hiệu, nút "Về mặc định" xuống
dòng riêng bên phải. Xác nhận bằng cách quay lại code lỗi và chạy test — đỏ
với `381px overflow` ở chiều rộng 320px, xanh sau khi sửa — rồi bấm lại trên
máy ảo thật để chắc chắn.

### 5. ~~Quyết định về 3 model mồ côi~~ — ĐÃ XOÁ 05/09/2026

`plan.py` / `promo_code.py` / `transaction.py` xoá hẳn — xác nhận lại 0 lần
dùng trong code chạy thật trước khi xoá. Kéo theo phải sửa
`scripts/create_tables.py` (bỏ hàm `seed_plans()` chèn dữ liệu vào một bảng
không ai đọc) và `scripts/ensure_tables.py` (import vỡ nếu không sửa — đã
chạy thật để xác nhận không lỗi). Bảng `plans`/`promo_codes`/`transactions`
vẫn còn trên DB (không tự xoá bảng, chỉ bỏ model quản lý chúng).

---

## Việc còn treo (không phải lỗi)

- **Chưa đăng ký OAuth Android client** cho `com.posturex.app` trong Google
  Cloud Console — việc riêng của VanGiap, không sửa được qua SSH. Lưu ý:
  `GOOGLE_CLIENT_ID` trong `.env` đã đúng, nhưng nếu Google Sign-In vẫn lỗi
  sau khi thử lại (mục 3) thì đây là nghi phạm tiếp theo.
- **`FrameInitMessage`** (`app/schemas/analysis.py`) là mã chết — khai một lần,
  không ai import; `realtime.py` tự `json.loads` thô.

---

## Checklist thử màn admin AI Config

Đã tự thử bằng `adb` ngày 05/09 (xem mục 4 lịch sử) — giữ checklist này để
người khác thử lại hoặc thử tay:

| Chỗ | Phải thấy |
|---|---|
| Danh sách | 3 bài (Squat, Lunge, Plank) kèm tên analyzer · ô tìm kiếm lọc được |
| Mở **Squat** | 4 thanh trượt, 2 cái có huy hiệu "Ảnh hưởng đếm rep" |
| Mở **Plank** | chỉ 2 thanh trượt, **bộ khoá khác hẳn** ← điều màn hình cũ không làm được |
| `knee_overshoot` | hiện `0.05`, **không có dấu độ** ← chỗ dễ sai nhất |
| Kéo một thanh | huy hiệu đổi thành "Đã chỉnh · mặc định 95°", hiện nút "Về mặc định" |
| Bấm **Lưu** | toast báo thành công, quay ra danh sách thấy "N ngưỡng riêng" |
| Bấm **Về mặc định** | giá trị quay lại mặc định, nút biến mất |
| Thoát khi chưa lưu | hỏi "Bỏ thay đổi?" |

**Ca lỗi cần thử:** kéo "Độ sâu gối" lên **cao hơn** "Đứng thẳng lại" rồi Lưu.
Phải hiện hộp thoại giải thích bộ đếm rep sẽ không hoạt động, và **không** ghi
gì xuống DB.

⚠️ DB local chỉ có 6 bài seed nên danh sách ngắn. VPS có 417 bài (106 phân tích
được) — dùng VPS để thấy đủ (`API_BASE_URL=http://103.82.21.150:9000`).

---

## Trạng thái lúc ghi (05/09/2026, cập nhật lần 4 — sau khi deploy)

```
Flutter   55 test xanh · 0 lỗi analyze
backend  250 test xanh · ruff sạch
```

**VPS đã deploy code mới nhất** (`bc37619`), service đang chạy, đã seed 6
ngưỡng cho 5 bài, SMTP đã sửa (đăng ký test thành công, đã dọn tài khoản
test khỏi DB thật). Xác nhận bằng API thật ở mỗi bước, không chỉ đọc log.

Việc thật sự còn lại chỉ còn **mục 3** — chưa ai bấm tay xác nhận bản sửa
video trên app trỏ VPS, và **OAuth Android client** cho VanGiap (mục "Việc
còn treo"). Không còn gì cần sudo hay quyền đặc biệt nữa.
