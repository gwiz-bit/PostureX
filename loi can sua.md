# Lỗi cần sửa

Ghi lại lỗi phát hiện khi thử app, kèm nguyên nhân đã truy được và cách kiểm
chứng lại. Mục đã sửa xong và xác nhận được thì gỡ khỏi file để tránh nhầm —
lịch sử đầy đủ luôn có trong `git log`. Mục mới nhất ở trên cùng.

---

## ▶ BẮT ĐẦU TỪ ĐÂY (phiên sau)

### 1. SMTP trên VPS bị Gmail từ chối — chặn đăng ký + quên mật khẩu

**Phát hiện 05/09/2026**, thử app trỏ vào VPS thật (không phải giả định).

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

**Sửa ở đâu:** cả hai đều nằm trong `backend/.env` trên VPS, **cần sudo** —
xem mục 2 bên dưới về việc quyền chưa xong.

```bash
sudo nano /opt/posturex/backend/.env
# sửa GOOGLE_CLIENT_ID = 526667437213-3njik3mv75t4oo7e6s0dijlfdip06d2v.apps.googleusercontent.com
# kiểm tra lại SMTP_USERNAME / SMTP_PASSWORD — cần khoá ứng dụng Gmail còn hiệu lực
sudo systemctl restart posturex
```

**Kiểm chứng lại sau khi sửa** (không cần app, gọi thẳng API):

```bash
curl -X POST -H "Content-Type: application/json" \
  -d "{\"username\":\"test\",\"email\":\"<email thật của bạn>\",\"password\":\"Xyz123@\"}" \
  http://103.82.21.150:9000/api/v1/auth/register
```

Phải KHÔNG còn dòng "Không gửi được email OTP" — và mã OTP phải tới hộp thư.

### 2. Có SSH nhưng chưa deploy được — sudo sai mật khẩu

**Cập nhật 05/09/2026:** VanGiap đã tạo tài khoản riêng `hiephann` trên VPS
(không dùng chung root). SSH **đăng nhập được**:

```bash
ssh hiephann@103.82.21.150   # bí danh cấu hình sẵn: ssh posturex
```

Nhưng **không deploy được** — mọi lệnh cần thiết đều đòi `sudo`
(`/opt/posturex` thuộc `root:root`, `hiephann` không ghi được), mà mật khẩu
sudo `G3BDuyRDORSyr3S7h02G` VanGiap gửi bị từ chối:

```
$ sudo -S true
[sudo] password for hiephann: Sorry, try again.
```

Đã báo lại VanGiap, đang chờ một trong hai:

- Mật khẩu sudo đúng (có thể copy hụt ký tự lúc gửi)
- Hoặc cấu hình `NOPASSWD` giới hạn đúng 4 lệnh deploy trong
  `/etc/sudoers.d/hiephann-deploy` (an toàn hơn cho VanGiap vì không cấp toàn
  quyền root)

**Có sudo rồi thì chạy:**

```bash
sudo git -C /opt/posturex pull origin main      # 7a90b28 → nhánh main hiện tại
sudo systemctl restart posturex
cd /opt/posturex/backend && sudo venv/bin/python scripts/seed_posture_rules.py
```

Kiểm đã lên chưa: `/api/v1/admin/posture-rules` phải chuyển từ **404 → 403**.

### 3. Xác nhận bản sửa video trên máy thật — đang bị lỗi 1 chặn đường

Bản sửa lỗi "mọi bài tập phát video Squat" đã lên `main` (commit `a7e6a97`),
đã có 10 test tự động xanh. Nhưng **kiểm bằng mắt trên VPS thật chưa làm
được** — thử app trỏ vào VPS thì mắc ngay ở màn đăng nhập vì lỗi mục 1
(không tạo được tài khoản mới, Google Sign-In cũng hỏng).

Khi mục 1 sửa xong, đăng nhập được rồi thì thử theo bảng này:

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

- **Chưa chạy `scripts/seed_posture_rules.py`** trên VPS mới — chờ mục 2.
- **Chưa đăng ký OAuth Android client** cho `com.posturex.app` trong Google
  Cloud Console — việc riêng của VanGiap, không sửa được qua SSH.
- **`FrameInitMessage`** (`app/schemas/analysis.py`) là mã chết — khai một lần,
  không ai import; `realtime.py` tự `json.loads` thô.

---

## Checklist thử màn admin AI Config (cho mục 4)

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
được) — muốn thấy đủ phải chờ mục 2.

---

## Trạng thái lúc ghi (05/09/2026, cập nhật lần 3)

```
Flutter   55 test xanh · 0 lỗi analyze
backend  250 test xanh · ruff sạch
```

Đã xong trong lần cập nhật này: sửa lỗi tràn layout màn AI Config (mục 4),
xoá 3 model mồ côi (mục 5). Còn lại đúng ba việc thật sự vướng, xem mục 1–3
ở đầu file — cả ba đều cần sudo trên VPS, đang chờ VanGiap.

**VPS vẫn chạy code cũ** — `/api/v1/admin/posture-rules` trả 404, route cũ
`/admin/config` vẫn 403. SSH đã thông (`hiephann@103.82.21.150`) nhưng deploy
bị chặn ở bước sudo — xem mục 2.
