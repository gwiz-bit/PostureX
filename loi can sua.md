# Lỗi cần sửa

Ghi lại lỗi phát hiện khi thử app, kèm nguyên nhân đã truy được và cách kiểm
chứng lại. Mục mới nhất ở trên cùng.

---

## ▶ BẮT ĐẦU TỪ ĐÂY (phiên sau)

Xếp theo thứ tự nên làm. Việc 1 và 2 **không cần VPS**, làm được ngay.

### 1. Sửa fallback video — làm được ngay, ~30 phút

Chi tiết nguyên nhân ở mục 05/09 bên dưới. Tóm tắt việc phải làm:

**File:** `lib/utils/exercise_videos.dart`

```dart
// XOÁ hằng số này — nó là gốc của lỗi
const _defaultGuideVideo = 'assets/video/squat.mp4';

// ĐỔI kiểu trả về thành String? và bỏ toán tử ??
String? guideVideoAssetFor(String exercise) =>
    _guideVideoByExercise[exercise.toLowerCase()];
```

**Hai nơi gọi phải sửa theo** (`assetPath` nay có thể null):

- `lib/features/exercises/presentation/screens/exercise_detail_screen.dart:85`
- `lib/screens/analyze_session_screen.dart:534`

**`lib/widgets/guide_video_player.dart`**: `assetPath` thành `String?`. Khi cả
`networkUrl` lẫn `assetPath` đều null thì **không dựng `VideoPlayer`**, thay
bằng một khối chữ "Bài này chưa có video hướng dẫn".

**Test cần thêm** (`test/features/exercises/`):
- Bài không có video → khẳng định `find.byType(VideoPlayer)` là `findsNothing`
- Bài có `demoVideoUrl` → dùng video mạng, không phải asset
- Squat không có `demoVideoUrl` → vẫn dùng asset đóng gói

**Cách kiểm bằng mắt:** chạy app với backend local (DB local có 6 bài, 0 video
— môi trường hoàn hảo để thử ca này), mở "Bicep Curl". Trước khi sửa: hiện
video squat. Sau khi sửa: hiện dòng chữ báo chưa có video.

⚠️ Sửa xong app **vẫn chưa hiện đủ video** — 412 video nằm trên VPS, cần việc
số 3. Bản sửa này chỉ khiến app thôi hiện video SAI.

### 2. Xác nhận tab Workout cùng gốc lỗi

Chưa kiểm được. `analyze_session_screen.dart:534` dùng chung
`GuideVideoPlayer` nên nhiều khả năng cùng nguyên nhân, nhưng phải mở app trỏ
vào VPS mới loại trừ được khả năng có lỗi thứ hai đang bị lỗi này che.

### 3. Deploy lên VPS — chờ quyền SSH

Chờ VanGiap thêm khoá công khai vào `authorized_keys` (xem mục "Việc còn treo").
Có SSH rồi thì chạy:

```bash
cd /opt/posturex && git pull origin main && systemctl restart posturex
cd backend && venv/bin/python scripts/seed_posture_rules.py
# sửa GOOGLE_CLIENT_ID trong backend/.env thành 526667437213-3njik3mv75t4oo7e6s0dijlfdip06d2v...
```

Kiểm đã lên chưa: `/api/v1/admin/posture-rules` phải chuyển từ **404 → 403**.

### 4. Thử màn admin AI Config trên máy thật

Món nợ duy nhất chưa ai đóng: đã có 10 widget test và đã gọi API thật bằng
curl, nhưng chưa ai đăng nhập admin rồi bấm qua giao diện.

```powershell
# cửa sổ 1 — backend (dùng PowerShell, không phải cmd)
cd C:\Users\quang\Documents\GitHub\PostureX\backend
.\run.ps1

# cửa sổ 2
flutter emulators --launch Pixel_4
cd C:\Users\quang\Documents\GitHub\PostureX
flutter run -d emulator-5554 --dart-define=API_BASE_URL=http://10.0.2.2:9000
```

Đăng nhập `admin@posturex.com` / `Admin123` (do `run.ps1` tạo sẵn).

**Bẫy đã gặp:** nếu `run.ps1` báo `WinError 10013` thì cổng 9000 đang bị
backend cũ chiếm. Tìm và tắt:

```powershell
Get-NetTCPConnection -LocalPort 9000 -State Listen | Select OwningProcess
Stop-Process -Id <PID> -Force
```

Cần nhìn những gì: xem checklist ở cuối file.

### 5. Quyết định về 3 model mồ côi

Xem mục "Việc còn treo". Cần người quyết vì trái với quyết định đã ghi trong
`CLAUDE.md`.

---

## 05/09/2026 — Mọi bài tập đều phát video hướng dẫn của Squat

**Người phát hiện:** hiephann, thử trên máy ảo với backend local.

### Triệu chứng

1. Tab **Exercises** → mở bài bất kỳ → video hướng dẫn luôn là squat.
2. Tab **Workout** → chọn bài bất kỳ → cũng chỉ hiện hướng dẫn squat.

### Nguyên nhân — đã truy được, không phải phỏng đoán

Cả hai triệu chứng là **một lỗi duy nhất**, nằm ở
[`lib/utils/exercise_videos.dart`](lib/utils/exercise_videos.dart):

```dart
const Map<String, String> _guideVideoByExercise = {
  'squat': 'assets/video/squat.mp4',      // ← đúng MỘT mục
};

const _defaultGuideVideo = 'assets/video/squat.mp4';   // ← và mặc định cũng là squat

String guideVideoAssetFor(String exercise) =>
    _guideVideoByExercise[exercise.toLowerCase()] ?? _defaultGuideVideo;
```

Hàm này trả `squat.mp4` cho **mọi** bài tập — bài squat thì trúng mục duy nhất
trong map, mọi bài khác thì rơi vào mặc định, mà mặc định cũng là squat.

`GuideVideoPlayer` nhận hai nguồn và **ưu tiên video mạng**:

```dart
GuideVideoPlayer(
  assetPath: guideVideoAssetFor(exercise.name),   // luôn là squat.mp4
  networkUrl: networkUrl,                          // từ Exercises.DemoVideoUrl
)
```

Nên video đúng chỉ phát khi cột `DemoVideoUrl` của bài đó có giá trị. Thiếu nó
là rơi thẳng về asset squat đóng gói sẵn.

### Trả lời câu hỏi "có phải do chưa kết nối VPS không?"

**Đúng.** Đây là nguyên nhân trực tiếp của lần thử này:

| | Số bài | Có `DemoVideoUrl` |
|---|---|---|
| **DB local** (đang dùng) | 6 | **0** |
| **VPS** `103.82.21.150` | 417 | 412 |

Đã kiểm bằng API, cả hai phía. DB local chỉ có 6 bài seed mặc định và **không
bài nào có video**, nên 100% trường hợp rơi về squat. Trỏ app sang VPS thì 412
bài sẽ phát đúng video của mình.

Lệnh kiểm chứng lại:

```powershell
# Local — hiện đang là 0
curl.exe -H "Authorization: Bearer <token>" "http://127.0.0.1:9000/api/v1/exercises?limit=50"

# VPS — hiện là 412
curl.exe "http://103.82.21.150:9000/api/v1/exercises?limit=2000"
```

### Nhưng vẫn còn lỗi thật sau khi có VPS

Trỏ sang VPS **không xoá hết vấn đề**, chỉ che phần lớn:

1. **5 trong 417 bài trên VPS vẫn không có video** → vẫn phát nhầm squat.
2. **Fallback im lặng là thiết kế sai.** Người dùng mở "Bicep Curl" mà thấy
   video squat sẽ tưởng app hỏng hoặc tưởng đó là động tác đúng. Thà không hiện
   video nào còn hơn hiện video của bài khác.
3. **Lý do biện minh trong chú thích đã lỗi thời.** File đó viết rằng fallback
   về squat là "nhất quán chứ không đánh lừa", vì backend cũng fallback sang
   `SquatAnalyzer` cho bài lạ. Lập luận này không còn đúng: nay đã có cờ
   `supports_analysis`, và tab Exercises hiện huy hiệu **LIVE ANALYSIS** đúng
   những bài phân tích được. Bài KHÔNG có huy hiệu đó (Bicep Curl, Jumping Jack
   trong ảnh chụp) thì chẳng có phản hồi squat nào cả — phát video squat cho
   chúng là sai thuần tuý.

### Đề xuất sửa

Bỏ hẳn `_defaultGuideVideo`, đổi `guideVideoAssetFor` trả `String?`:

- Có `DemoVideoUrl` → phát video mạng (đường chính, 412/417 bài)
- Không có, nhưng là squat → phát asset đóng gói
- Không có gì → **không hiện khung video**, thay bằng dòng chữ "Bài này chưa có
  video hướng dẫn"

Kèm test: mở một bài không có video, khẳng định **không** có `VideoPlayer` nào
trong cây widget.

### Chưa kiểm được

- Chưa xác nhận triệu chứng ở tab **Workout** đi qua đúng đường code này.
  `analyze_session_screen.dart:534` cũng dựng `GuideVideoPlayer` với cùng
  fallback, nên nhiều khả năng cùng gốc — nhưng cần mở app trỏ vào VPS để loại
  trừ khả năng có lỗi thứ hai bị lỗi này che mất.

---

## Việc còn treo (không phải lỗi)

- **VPS chưa deploy code mới.** `/api/v1/admin/posture-rules` trả 404, route cũ
  `/admin/config` vẫn 403 → server đang chạy bản trước commit `05cfd1a`.
  Cần `git pull` + `systemctl restart posturex`.
- **Chưa chạy `scripts/seed_posture_rules.py`** trên VPS mới.
- **`GOOGLE_CLIENT_ID` trong `.env` trên VPS** vẫn là client cũ (`.env` không đi
  theo `git pull`).
- **Chưa đăng ký OAuth Android client** cho `com.posturex.app`.
- **Chưa có quyền SSH vào VPS** — cả bốn việc trên đều chờ VanGiap thêm khoá
  công khai vào `authorized_keys`.
- **3 model mồ côi** `plan.py` / `promo_code.py` / `transaction.py`: không code
  nào đọc, nhưng nằm trong `app/models/__init__.py` nên `ensure_tables.py` vẫn
  tạo 3 bảng rác trên DB. Chưa xoá vì trái quyết định đã ghi trong `CLAUDE.md`,
  và `plans`/`transactions` còn 4 dòng dữ liệu.
- **`FrameInitMessage`** (`app/schemas/analysis.py`) là mã chết — khai một lần,
  không ai import; `realtime.py` tự `json.loads` thô.

---

## Checklist thử màn admin AI Config (cho việc số 4)

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
được) — muốn thấy đủ phải chờ việc số 3.

---

## Trạng thái lúc ghi (05/09/2026)

```
main = hiep05 = 3f7f242    cây mã sạch
backend  250 test xanh · ruff sạch
Flutter   44 test xanh · 0 lỗi analyze
```

Ba commit gần nhất:

| | |
|---|---|
| `3f7f242` | Sửa tài liệu sai tên biến build, dọn file rác |
| `05cfd1a` | Viết lại màn admin AI Config — ngưỡng theo từng bài, lưu vào DB |
| `db82ce7` | Sửa app Android không gọi được VPS mới, tách cấu hình debug/release |

**VPS đang chạy code cũ hơn `05cfd1a`** — xác nhận bằng API, không phải phỏng
đoán: `/api/v1/admin/posture-rules` trả 404 còn route cũ `/admin/config` vẫn
trả 403.
