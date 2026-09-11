# CLAUDE.md

File này hướng dẫn Claude Code (claude.ai/code) khi làm việc với mã nguồn trong repo này.

## Dự án

PostureX — "Your AI-Powered Fitness Coach". Repo này chứa hai thứ:

1. **App Flutter** (`lib/`) — app tư thế/thể hình cho người dùng, khoảng 220 file Dart trải trên 34 màn hình, trong đó 11 màn là khu vực admin nằm dưới `lib/features/admin_*/`. Hầu hết feature (kể cả toàn bộ phần admin) theo Clean Architecture: `domain/{entities,repositories,usecases}` → `data/{datasources,repositories}` → `presentation/{controllers,screens}`, cộng một file `<feature>_module.dart` làm composition root — không dùng framework DI nào, các module tự nối phụ thuộc bằng tay.
2. **Backend FastAPI** (`backend/`, nằm ngang hàng `lib/` ở gốc repo) — một service Python đầy đủ (MySQL + xác thực JWT + phân tích tư thế bằng MediaPipe), chỉ giao tiếp qua REST/WebSocket. Trước đây nó nằm lồng trong `lib/backend/`; đã dời ra gốc repo vì `lib/` vốn chỉ chứa Dart và việc lồng vào không đem lại lợi ích gì.

**Chỉ có đúng một hàm `main()`**, ở `lib/main.dart` — chạy `grep -rln "^void main()" lib/` là thấy. Khu vực admin *không* phải app riêng: nó là một nhóm màn hình trong cùng một binary, vào được bằng cách đăng nhập tài khoản mà backend đánh dấu `is_admin`. Những ghi chú cũ nói có entry point `admin_main.dart` và cờ `-t` để chạy nó là sai; file đó không tồn tại.

## Lệnh thường dùng

### App Flutter

```bash
flutter pub get                      # cài phụ thuộc
flutter analyze                      # phân tích tĩnh — phải sạch mới coi là xong việc
flutter test                         # chạy bộ test (test/widget_test.dart)
flutter test --plain-name "Logging out"   # chạy một test theo tên (khớp một phần)
flutter run -d chrome                # chạy kèm hot reload trên trình duyệt
flutter run -d windows               # chạy như app desktop Windows
flutter build web --release          # build web bản phát hành (kết quả: build/web)
```

**Có sẵn một máy ảo Android** và đã kiểm chứng chạy thông suốt (`flutter emulators` để liệt kê, `flutter emulators --launch <id>`, rồi `flutter run -d emulator-5554`) — app build được, cài với định danh `com.posturex.app`, và gọi tới backend được. Hai điểm cần biết trước khi chọn nền tảng:

- **`flutter run -d windows` sẽ lỗi** `Building with plugins requires symlink support` cho tới khi bật **Developer Mode** của Windows (`start ms-settings:developers`, rồi khởi động lại editor). Quá trình build plugin tạo symlink dưới `windows/flutter/ephemeral/.plugin_symlinks`, mà Windows cấm người dùng thường tạo. Không có cách nào lách trong code.
- **Flutter web vẽ lên `<canvas>` qua CanvasKit**, nên không có text DOM thật. Muốn kiểm tra bố cục thì `flutter build web --release`, phục vụ `build/web` bằng `python -m http.server <cổng>`, rồi điều khiển bằng Playwright/Chromium **bấm theo toạ độ pixel** — không bao giờ theo text selector — và ảnh chụp màn hình là cách kiểm chứng duy nhất đáng tin.

Lưu ý: `flutter pub get` và các lần build Android sẽ ghi lại những file plugin registrant sinh tự động dưới `linux/`, `macos/`, `windows/`. Đó là sản phẩm phụ của build chứ không phải việc bạn làm — đừng gộp chúng vào một commit không liên quan.

### Backend (chạy từ thư mục `backend/`)

```powershell
.\run.ps1                             # một lệnh: venv, deps, .env, model, DB, rồi uvicorn — chạy lại lúc nào cũng an toàn
```

`run.ps1` lo trọn phần cài đặt lần đầu trên một bản clone mới (tạo `.env` từ `.env.example` rồi dừng lại cho bạn điền `DB_PASSWORD`, lần chạy sau mới tạo venv, cài deps, tải model MediaPipe, khởi tạo schema DB nếu còn rỗng) và chạy lại nhiều lần cũng không sao — với DB đã có dữ liệu, nó chỉ bổ sung các bảng còn thiếu so với `Base.metadata` (qua `scripts/ensure_tables.py`, khác `scripts/create_tables.py` ở chỗ không bao giờ xoá `videos`/`workouts`). Dùng nó sau mỗi lần `git pull` có thêm model mới, thay vì chạy tay từng phần bên dưới. Mọi script bảo trì chạy một lần (dựng DB, tạo admin, tải model, xuất/nhập dữ liệu, kích hoạt job thủ công) đều nằm trong `backend/scripts/` — không có file script nào vứt lẻ ở thư mục gốc `backend/`:

```bash
pip install -r requirements.txt
python scripts/download_models.py     # tải model tư thế MediaPipe (app/ml/models/*.task)
python scripts/create_tables.py       # chỉ dùng lần đầu — XOÁ + tạo lại videos/workouts mỗi lần chạy
python scripts/ensure_tables.py       # chạy lại an toàn — chỉ tạo bảng còn thiếu so với Base.metadata
python scripts/create_admin.py        # tạo tài khoản admin
uvicorn app.main:app --reload --port 9000   # app Flutter mong đợi cổng 9000
pytest                                # test backend (tests/) — hiện 169, tất cả đều xanh
pytest --cov=app                      # đo coverage (58% ở lần đo gần nhất, trước khi nhập thư viện bài tập)
ruff check .                          # lint — cấu hình trong pyproject.toml; phải sạch
ruff format .                         # định dạng code
```

Bộ quy tắc của `ruff` đã được chỉnh trong `pyproject.toml` sao cho `ruff check .` **xanh trên cây mã hiện tại** — một cổng kiểm tra mà mở ra đã đỏ 200 lỗi tồn đọng thì rốt cuộc ai cũng bỏ qua. Vài quy tắc nằm trong `ignore`, mỗi cái kèm chú thích nói rõ bật lại sẽ tốn gì; hãy siết từng cái một thay vì mở rộng `select`. Có một mục mang tính sống còn chứ không phải thẩm mỹ: `flake8-bugbear.extend-immutable-calls` liệt kê `fastapi.Depends`/`Query`/`File`/…, thiếu nó là B008 báo nhầm khoảng 105 chỗ trên khắp các route.

Cấu hình đọc từ `backend/.env` (xem `.env.example`): kết nối MySQL, `SECRET_KEY`, thông tin SMTP để gửi OTP, `GOOGLE_CLIENT_ID`, `GEMINI_API_KEY` (AI Coach), khoá MoMo tuỳ chọn (BE-14 — giá trị mặc định trong `config.py` là bộ khoá *sandbox công khai* của MoMo, nên thanh toán chạy được ngay trên bản clone mới), và thông tin FCM tuỳ chọn (BE-13 — không cấu hình thì phần push bị bỏ qua lặng lẽ). `GOOGLE_CLIENT_ID` phải giống từng ký tự với `googleWebClientId` trong `lib/config/api_config.dart`. Tài liệu API tương tác ở `/docs` — nhưng chỉ khi `DEBUG=True`; trên bản triển khai thật thì `docs_url`/`redoc_url`/`openapi_url` đều là `None` để không phơi toàn bộ bề mặt API ra ngoài.

**Bẫy encoding của `.env`.** `slowapi` tự nuốt file `.env` lúc import chỉ vì file đó tồn tại (`Config(".env")` trong `slowapi/extension.py`), mà `starlette.config.Config` mở file *không chỉ định encoding* — nên trên máy Windows dùng locale tiếng Việt, codec cp1252 gặp phần chú thích UTF-8 trong file là server chết ngay lúc import với `UnicodeDecodeError: 'charmap' codec can't decode byte 0x81`, trước cả khi uvicorn kịp bind cổng. `app/core/rate_limit.py` vô hiệu hoá bẫy này bằng cách truyền `config_filename=os.devnull`; đừng trả nó về mặc định. Triệu chứng chỉ xuất hiện trên một số máy, nên "máy tôi chạy ổn" không chứng minh được gì ở đây.

## Nhật ký thay đổi

Chỉ ghi những thay đổi làm đổi cách hiểu về hệ thống, kèm phần cần lưu ý. Mục
mới nhất ở trên cùng.

### 11/09/2026 (5)

**Video upload: kết quả phân tích chưa từng hiển thị lên app, cộng một lỗi
nghiêm trọng — mọi video upload bị phân tích NHƯ THỂ LÀ SQUAT.** Phát hiện
lúc test thật (`B Stance Hip Thrust` → upload → không có cách nào xem kết
quả). Backend đã phân tích video ngầm từ 06/09/2026 (`video_analysis_service.py`,
ghi `analysis_summary`/`total_reps`/`accuracy_score` vào bảng `videos`), và
toàn bộ tầng domain/data phía Flutter (`VideoRepository.getVideo`,
usecase `GetVideo`, `ApiClient.fetchVideo`) **đã có sẵn, đã nối đủ dây** —
chỉ riêng tầng presentation (`UploadVideoScreen`/`VideoUploadController`)
chưa bao giờ dùng tới, tài liệu code (`UploadVideo`/`Video` doc comment) còn
ghi sai "backend never runs analysis" từ trước 06/09, không cập nhật khi
backend đổi — đây chính là lý do gap này lọt qua nhiều đợt.

**Lỗi nặng hơn phát hiện cùng lúc:** `UploadVideoScreen` cũ gọi cứng
`_controller.upload(exercise: 'squat')` — KHÔNG NHẬN tham số bài tập nào cả
(constructor không có field `exercise`), nên bất kể người dùng đang xem/quay
video cho bài nào, backend luôn chạy `SquatAnalyzer` lên nó. Ca thật: video
"B Stance Hip Thrust" bị đọc feedback góc gối như squat — sai hoàn toàn,
đúng kiểu rủi ro đã cảnh báo ở CHANGELOG 06/09/2026 nhưng nặng hơn nhiều
(không phải "tên lạ rơi về mặc định", mà là MỌI video, MỌI bài, MỌI lần).

Sửa:
- `UploadVideoScreen` nay nhận `exercise` bắt buộc — `ExerciseDetailScreen`
  truyền đúng `exercise.name` (đã có sẵn, chỉ chưa được truyền). Route
  "Upload a video" chung ở tab Workout (không có bài nào được chọn sẵn) đổi
  sang mở `ExercisesScreen` để người dùng chọn bài trước, thay vì âm thầm
  gán sai — sửa gốc rễ, không phải giấu triệu chứng.
- `VideoUploadController` thêm polling: sau `upload()` thành công, gọi
  `GetVideo(id)` mỗi 3 giây (tối đa 20 lần ≈ 60 giây) tới khi
  `analysisSummary != null` — trường này LUÔN được set khi job nền xong
  (kể cả video lỗi/bài chưa hỗ trợ, xem `video_analysis_service.py`), nên
  đó là tín hiệu "xong" đáng tin, không cần đoán qua `total_reps`/
  `accuracy_score` (có thể hợp lệ bằng 0/null ngay cả khi đã phân tích xong).
- `UploadVideoScreen` hiện thẻ kết quả CÓ THỂ NHẤN MỞ RA ngay dưới nút
  Upload — đúng yêu cầu "xem phân tích ngay trong trang đó" thay vì dòng chữ
  tĩnh "analysis coming soon" cũ không dẫn tới đâu cả.

3 test mới (`test/features/video/video_upload_controller_test.dart`, dùng
`fakeAsync` cùng cách `api_client_timeout_test.dart` đã làm) khoá lại state
machine polling: tới đúng lúc mới dừng gọi thêm (không rò rỉ timer), hết
giờ đúng lúc nếu server không bao giờ xong, và chọn file mới xoá sạch kết
quả phân tích cũ. `flutter analyze` 0 lỗi, 75 test Flutter xanh.

⚠️ **Cat-Cow trong routine "Posture Primer" (xem mục (4) bên dưới, đã sửa
Row/Plank/Lunge/Deadlift/Hip Thrust) KHÔNG sửa được bằng cách đổi khoá** —
thư viện hiện không có video/bài nào thuộc họ Cat-Cow (xem comment
`_CAT_COW_VARIANTS` trong `registry.py`). Cần quyết định sản phẩm: bỏ khỏi
routine, hay tìm nguồn video/nhập bài mới.

⚠️ **Chưa test qua app thật** — toàn bộ xác nhận trên bằng test tự động
(`fakeAsync`, không chạm mạng/BackgroundTasks thật). Cần: build lại APK,
upload một video thật cho một bài CÓ analyzer (khác squat, vd Barbell Bent
Over Row) và xác nhận thẻ "View analysis" hiện đúng reps/accuracy sau vài
chục giây, cùng một video cho bài KHÔNG có analyzer (vd B Stance Hip Thrust)
xác nhận thẻ hiện đúng câu "Bài này chưa hỗ trợ phân tích tự động" thay vì
lại đọc nhầm thành squat như trước.

### 11/09/2026 (4)

**Bước 4 — tích hợp production + hiển thị lên app, đã deploy.** Tiếp nối
mục (3) ngay bên dưới.

Backend: `SimilarityScorer` (mới) nối vào `routes/realtime.py`, chạy CỘNG
THÊM song song với `KeypointSmoother`/rep-counting hiện có — thêm field
`similarity_score` (0-100, `None` nếu bài chưa có chuẩn hoặc cửa sổ live
chưa đủ frame) vào `FrameAnalysisResult`. Tách `reference_joints.py` (bảng
khớp chính dùng chung giữa script trích chuẩn và scorer, tránh lặp lại và
lệch nhau dần) và `reference_library.py` (đọc + cache bằng `lru_cache` chuỗi
góc từ 113 file JSON chuẩn — file không đổi sau khi sinh, tính lại mỗi
frame/mỗi phiên là lãng phí CPU trên máy 2 vCPU vốn chia sẻ với pose
estimation).

**Lỗi tự phát hiện lúc viết, đã sửa + khoá bằng test:** viết nhầm điều kiện
chọn phép chiếu — `if self._reference.analyzer` luôn đúng (chuỗi khác rỗng)
nên code LUÔN dùng 2D bất kể chuẩn đã chọn 2D hay 3D lúc trích. Sửa bằng
cách lưu hẳn `projection` vào `ReferenceMotion` thay vì suy luận lại từ tên
analyzer, và thêm test `test_uses_projection_stored_in_reference_not_a_fixed_choice`
dựng chuyển động CHỈ lộ ra ở trục z để bẫy đúng loại lỗi này nếu tái phạm.

Cũng đưa vào chặn "đứng yên trong ROM vẫn điểm cao" đã phát hiện ở
`dtw_prototype.py`: biên độ cửa sổ live < 8° → trả thẳng điểm 0, không chạy
DTW — rẻ hơn nhiều so với ràng buộc step-pattern đầy đủ trong DTW (cần thêm
một chiều trạng thái trong quy hoạch động) mà vẫn nhắm đúng trường hợp lỗi
đã đo được.

18 test mới (`test_reference_library.py`, `test_similarity_scorer.py`). 357
test backend xanh, ruff sạch.

**Đã deploy lên VPS.** 113 file chuẩn tham chiếu (trước đó ở
`/home/hiephann/reference_poses/` do chạy `extract_reference_poses.py` cần
sudo mới copy được — `storage/` trên VPS thuộc `root:root`) đã chuyển vào
đúng vị trí production `backend/storage/reference_poses/`. `git pull` +
`systemctl restart posturex` không lỗi, xác nhận bằng cách import trực tiếp
`reference_library.get_reference('bodyweight squat')` trên VPS: đọc đúng
88 frame, đúng projection `x/y`, và trả `None` sạch cho bài không tồn tại.

Flutter: `FrameAnalysisResult.similarityScore` (mới) đọc field JSON tương
ứng. `AnalyzeSessionScreen` hiện một badge nhỏ góc phải màn hình (%, đổi
màu xanh/vàng/đỏ theo mức điểm — `_similarityScoreColor()`) CHỈ khi
`similarityScore != null` — ẩn hẳn thay vì hiện 0%, vì `null` nghĩa là
"bài chưa có chuẩn hoặc cửa sổ live chưa đủ dữ liệu", không phải "tập sai
hoàn toàn". `flutter analyze` 0 lỗi (38 info có từ trước, không liên quan),
72 test Flutter xanh — không phải sửa test nào khác vì `FrameAnalysisResult`
chỉ được dựng ở đúng 1 chỗ (`fromJson`).

⚠️ **Chưa test qua app thật trên điện thoại.** Toàn bộ xác nhận trên đều
qua test tự động + smoke-test import trực tiếp trên VPS (không qua WebSocket
thật). Cần: mở `AnalyzeSessionScreen` với một bài đã có chuẩn (vd Bodyweight
Squat, Barbell Curl — xem log Bước 2 cho danh sách 113 bài), xác nhận badge
hiện và điểm số hợp lý (tập đúng theo video mẫu → điểm cao dần, đứng yên
hoặc tập khác hẳn → điểm thấp), và xác nhận bài KHÔNG có chuẩn (vd Overhead
Press, bị loại vì chất lượng video) thì badge không hiện, không có gì đổi
khác so với trước.

⚠️ **Ngưỡng `SCALE_DEGREES=30.0` và `MIN_LIVE_RANGE_DEGREES=8.0` trong
`similarity_scorer.py` là ước lượng, chưa đo trên người thật** — cùng tình
trạng với mọi ngưỡng khác trong dự án lúc mới viết. Nếu điểm số thật tế quá
khắt khe (người tập đúng vẫn ra điểm thấp) thì tăng `SCALE_DEGREES`; nếu quá
dễ dãi thì giảm.

### 11/09/2026 (3)

**Bắt đầu hướng "so khớp real-time với video mẫu bằng AI" — Giai đoạn A/B đã
xác nhận khả thi, CHƯA tích hợp vào production.** Xuất phát từ nhận thức lại
trọng tâm dự án: tracking hiện tại chấm điểm bằng ngưỡng góc viết tay
(xem "Các analyzer là ngưỡng góc viết tay" ở mục Bố cục backend), KHÔNG thực
sự "đối chiếu với bài tập mẫu" như yêu cầu ban đầu — video mẫu (`assets/video/`)
chỉ phát song song để người dùng tự nhìn so sánh, không có phép so sánh tính
toán nào. Hướng đã thống nhất: giữ nguyên phát song song video mẫu, cộng
thêm điểm "độ giống bài mẫu" tính bằng so khớp chuỗi góc thời gian thực với
chuẩn trích từ video mẫu — bổ sung, không thay hệ rep-counting/ngưỡng hiện có
(hệ đó đã ổn định, không đụng vào).

**Bước 1-2 — trích chuẩn tham chiếu.** `backend/scripts/extract_reference_poses.py`
(mới) trích chuỗi keypoint từ video mẫu, quyết định dùng góc 2D hay 3D cho
từng video theo công thức đã kiểm chứng qua 3 bài thử tay (Squat/Barbell
Curl/Overhead Press) trước khi viết script chính thức: **độ nhảy trung bình
giữa hai frame liên tiếp nhỏ hơn thắng** (mượt hơn = tín hiệu chuyển động
thật) — CHỦ Ý không dùng variance, vì variance cao có thể đến từ nhiễu ngẫu
nhiên chứ không riêng chuyển động thật (ca thật: Barbell Curl bị variance
chọn nhầm 2D). Kèm hai điều kiện loại: biên độ góc (max-min) phải ≥20° (loại
trường hợp góc đó không thấy chuyển động gì), và tỉ lệ mất dấu người trong
video phải ≤10% (video mẫu tự nó kém thì không đáng tin làm chuẩn — ca thật:
Overhead Press mất dấu 13.3%, bị loại đúng như kỳ vọng).

Đã chạy thật trên VPS qua 204 khoá tên bài trong `ANALYZER_REGISTRY`: **113
dựng được chuẩn, 91 bị loại** (thiếu file video khớp tên, hoặc không đạt
chất lượng/biên độ). Phát hiện đáng chú ý: 2D/3D **không phải thuộc tính cố
định theo họ bài tập** mà theo TỪNG VIDEO — cùng là squat nhưng
`band squat`/`bodyweight squat` chọn 2D trong khi `barbell banded back squat`/
`dumbbell goblet squat` chọn 3D, vì mỗi video mẫu quay góc camera khác nhau.
Đúng thiết kế đã định — không gộp quyết định 2D/3D theo class analyzer.

Kết quả (~28MB, 113 file JSON) lưu ở `/home/hiephann/reference_poses/` trên
VPS, **không đi theo git** — cùng cách `videos`/model MediaPipe cũng
gitignore, đây là dữ liệu sinh ra chứ không phải mã nguồn.

**Bước 3 — prototype DTW + đo thời gian.** `backend/scripts/dtw_prototype.py`
(mới, script thử nghiệm — CHƯA phải code sẽ chạy production) dùng
**Subsequence DTW** (không phải DTW cổ điển hai đầu cố định) để so một cửa
sổ trượt N frame gần nhất của "live" với toàn bộ chuẩn tham chiếu, cho phép
điểm bắt đầu/kết thúc khớp tự do trong chuẩn — đúng bài toán thật: người
đang tập dở chỉ ở MỘT ĐOẠN của chu kỳ rep, không phải cả chu kỳ.

**Lỗi phát hiện lúc thử lần đầu, đã sửa:** dùng nhầm DTW cổ điển (2 đầu cố
định) trước, cho điểm chỉ ~60/100 ngay cả khi so khớp đúng y hệt chính chuẩn
— vì nó ép cửa sổ live ngắn phải giãn ra khớp hết chiều dài chuẩn dài hơn,
phạt điểm giả tạo dù khớp hoàn hảo một đoạn. Đổi điều kiện biên (hàng khởi
tạo toàn 0 thay vì tích luỹ dần, lấy min ở cột kết thúc thay vì cố định cột
cuối) sửa đúng vấn đề — sau khi sửa, so khớp với chính chuẩn cho điểm
**100/100** chính xác.

Thời gian mỗi lần cập nhật DTW: **~1ms trung bình** (window=30 frame,
chuẩn~88 frame) trên VPS 2 vCPU — so với pose estimation ~30-60ms/frame đã
ghi ở mục "Đừng bao giờ gọi thẳng PoseEstimator.estimate()", chi phí DTW gần
như không đáng kể, không có rủi ro làm rớt FPS.

⚠️ **Giới hạn đã phát hiện, CHƯA xử lý:** DTW không giới hạn số bước cho
phép "dính" vào đúng một frame chuẩn nhiều lần liên tiếp — đứng yên ở một tư
thế nằm TRONG phạm vi chuyển động của bài vẫn được điểm không thấp (ca thử:
đứng yên ở ~90° trong squat được 47.7/100, đáng lẽ phải rất thấp vì không hề
tập). Bản sản xuất (Bước 4, CHƯA làm) cần thêm ràng buộc kiểu bước đi
(step-pattern constraint — giới hạn số bước lặp liên tiếp cùng cột) để đứng
yên không còn được điểm giả tạo cao.

⚠️ **Toàn bộ Giai đoạn A/B mới dừng ở script thử nghiệm chạy tay trên VPS,
CHƯA tích hợp vào `routes/realtime.py`, CHƯA có điểm số nào hiển thị trên
app.** Bước 4 (tích hợp vào production, đo lại hiệu năng khi chạy CÙNG lúc
với pose estimation thật trong một phiên WebSocket, thêm ràng buộc
step-pattern) là việc lớn còn lại, cần phiên làm việc riêng.

### 11/09/2026 (2)

**AI Coach nay lưu lại lịch sử chat, và được nối với "Personalize with AI"
trên Home.** Trước đó: (1) `AiCoachController.messages` chỉ tồn tại trong
RAM, tạo mới trắng tinh mỗi lần `CoachModule.controller()` được gọi (mỗi lần
mở màn) — rời màn AI Coach là mất sạch; (2) chat và sinh lịch tập ("Personalize
with AI" ở Home) là hai tính năng gọi Gemini hoàn toàn tách rời, không biết
gì về nhau — **lưu ý:** nút "Personalize with AI" tự nó ĐÃ hoạt động thật từ
trước (gọi `POST /coach/plan` thật, dùng hồ sơ + lịch sử tập thật), không
phải một chỗ chưa nối dây như ban đầu nghĩ — cái thiếu chỉ là sự LIÊN KẾT
giữa nó và chat.

**1) Lịch sử chat.** Bảng `coach_messages` mới (`user_id`, `role`, `content`,
`created_at`) — server giờ là nguồn sự thật duy nhất. `POST /coach/chat`
KHÔNG còn nhận `history` từ client (field đã xoá khỏi `CoachChatRequest`) —
tự đọc `DEFAULT_CONTEXT_LIMIT=20` tin nhắn gần nhất từ DB làm ngữ cảnh, rồi
lưu lại cả câu hỏi lẫn câu trả lời SAU KHI Gemini trả lời thành công (lưu
trước lúc gọi sẽ để lại câu hỏi mồ côi nếu request lỗi giữa chừng). Thêm
`GET /coach/history` (khôi phục lại đoạn chat lúc mở màn) và
`DELETE /coach/history` (nút "Xoá cuộc trò chuyện" mới trên AppBar).

**Bẫy tìm thấy lúc chạy cả bộ test cùng lúc:** hai `add_message()` gọi liên
tiếp có thể trùng `created_at` tới độ chính xác micro-giây, khiến
`ORDER BY created_at` một mình không ổn định (thứ tự đảo lộn giữa các lần
chạy, dù luôn đúng khi test riêng lẻ). Sửa bằng cách thêm `id` (tự tăng, luôn
đúng thứ tự chèn thật) làm tiêu chí phụ trong `crud/coach_message.py`.

**2) Nối chat với sinh lịch tập.** `POST /coach/plan` giờ đọc thêm 10 lượt
chat gần nhất, định dạng gọn rồi nhét vào prompt (`ai_coach_service.generate_plan`
có thêm tham số `chat_context`, rỗng thì hành vi y hệt trước — không phá gì
đang chạy). Yêu cầu Gemini tôn trọng nguyện vọng/ràng buộc đã nói trong chat
(vd "tránh tập lưng vì đang đau") khi soạn lịch. Phía Flutter, `AiCoachScreen`
có thêm nút "Tạo lịch tập từ đoạn chat này" (icon ✨ trên AppBar) — gọi cùng
hàm dùng chung mới `generateAndApplyAiPlan()` (`lib/utils/ai_plan_apply.dart`,
tách ra từ `HomeScreen._generateAiPlan` để hai nơi không copy-paste logic áp
lịch vào `UserSession.plan`).

Thêm `tests/test_coach.py` (12 test, Gemini bị giả hoàn toàn — không test
nào gọi API thật): CRUD thuần, lưu đúng cả hai chiều hỏi-đáp, lượt hỏi sau
thấy được lịch sử lượt trước, xoá lịch sử, và `chat_context` tới đúng
`generate_plan` khi có/không có lịch sử chat. 346 test backend xanh, ruff
sạch. 72 test Flutter xanh (sửa 1 test cũ còn gọi `sendCoachMessage(...,
history: [])` — tham số đã xoá), `flutter analyze` 0 lỗi.

⚠️ **Cần chạy `scripts/ensure_tables.py` trên VPS sau khi deploy** để tạo
bảng `coach_messages` mới — không tự nhiên có, và `git pull` không đi kèm
migration DB (đúng quy trình đã ghi ở mục "Triển khai" cho mọi bảng mới).

⚠️ Chưa test bằng tài khoản thật trên điện thoại — toàn bộ xác nhận trên
đều bằng test tự động.

### 11/09/2026

**Test thật trên điện thoại của bản sửa 09/09 — camera trước bị NGƯỢC hẳn
(khớp ở sai bên cơ thể), cả hai camera vẫn còn nhảy loạn dù đã có
`KeypointSmoother`.**

**1) Camera trước ngược — lỗi hồi quy đã biết của chính plugin, không phải
lỗi công thức lật gương của app.** `SkeletonPainter.mirror` (sửa từ phiên
trước) giả định `CameraPreview` TỰ ĐỘNG lật gương camera trước để hiển thị —
đúng với hành vi cũ, nhưng `camera_android_camerax` (bản đang dùng: 0.6.30)
có một lỗi hồi quy đã biết
([flutter/flutter#156974](https://github.com/flutter/flutter/issues/156974)):
từ bản `0.6.8+2` trở đi, preview camera trước có lúc hiện "như quay phim"
(KHÔNG lật gương) thay vì lật như mọi app camera thật. Bản vá chính thức
(`0.6.18+3`) chỉ áp dụng cho **backend render Impeller** — không đảm bảo hết
lỗi trên mọi tổ hợp thiết bị/Flutter engine, và thực tế xác nhận vẫn còn lỗi
trên máy thật.

Sửa bằng cách **tự lật gương preview**, không phụ thuộc plugin nữa:
`AnalyzeSessionScreen` bọc `CameraPreview` trong `Transform` +
`Matrix4.rotationY(pi)` khi đang dùng camera trước. `SkeletonPainter.mirror`
giữ nguyên logic (vẫn lật toạ độ khớp theo đúng cách cũ) — giờ chỉ là khớp
với phép lật TỰ QUẢN LÝ thay vì lật của plugin, nên đúng bất kể phiên bản
plugin/thiết bị cư xử thế nào.

**2) Vẫn nhảy loạn dù `KeypointSmoother` đã deploy — `alpha=0.5` chưa đủ
mượt.** Xác nhận VPS đang chạy đúng bản có bộ làm mượt (`d6ad083`, khớp
commit deploy 09/09) nên đây không phải do quên deploy. Hạ `alpha` mặc định
từ 0.5 xuống **0.25** — công thức EMA có "bộ nhớ hiệu dụng" ~1/(1-alpha)
frame, nên 0.25 tương đương làm mượt trên ~4 frame gần nhất thay vì ~2 frame
như trước, đổi lại khung xương trễ hơn một chút so với chuyển động thật.

Đã build lại APK (`app-arm64-v8a-release.apk`) — điện thoại lúc này đã ngắt
kết nối USB nên không cài trực tiếp qua ADB được như commit trước, gửi thẳng
file APK để tự cài.

334 test backend xanh (đổi default `alpha` không cần sửa test nào — mọi test
đều tự truyền `alpha=` riêng), 72 test Flutter xanh, `flutter analyze` 0 lỗi.

⚠️ **Cả hai con số (`Matrix4.rotationY(pi)` cho lật gương và `alpha=0.25` cho
làm mượt) đều CHƯA được xác nhận lại trên chính điện thoại đã báo lỗi** — chỉ
mới build/cài xong, chưa có kết quả test thật. Nếu `alpha=0.25` vẫn chưa đủ
mượt, hạ tiếp (0.15-0.2); nếu khung xương "trễ" rõ rệt so với chuyển động
thật, tăng lên lại.

### 09/09/2026

**Test thật đầu tiên trên điện thoại của loạt analyzer mới 06/09 — lộ ra 2
việc, cả hai đã sửa.** Ảnh chụp thật: khung xương "nhảy loạn", không cố định
một hướng (loại được khả năng lệch toạ độ/crop), và khung xương chỉ vẽ dạng
"hộp" quanh thân (vai-hông-gối-mắt cá), không có mặt/khuỷu tay/cổ tay dù đang
tập Band Curl.

**1) Khung xương nhảy loạn — sửa bằng `KeypointSmoother` mới
(`app/ml/keypoint_smoother.py`).** Nguyên nhân: `PoseEstimator` chạy
MediaPipe ở `RunningMode.IMAGE` (mỗi frame độc lập, không có ngữ cảnh thời
gian) — đúng thiết kế ban đầu, không phải lỗi mới. **Cố tình KHÔNG đổi sang
`RunningMode.VIDEO`/`LIVE_STREAM`** (chế độ MediaPipe tự làm mượt): xung đột
với `PoseEstimatorPool` — một instance MediaPipe phục vụ xen kẽ NHIỀU phiên
tập khác nhau để tiết kiệm CPU, trong khi VIDEO/LIVE_STREAM giả định một
luồng liên tục CÙNG một người; trộn hai điều này sẽ làm hỏng bộ làm mượt nội
bộ (tưởng nhầm người khác là "frame tiếp theo"). Đổi đúng cách cần thiết kế
lại pool cho gắn instance riêng theo từng phiên — việc lớn, để dành sau.

Làm mượt EMA (α=0.5, ước lượng ban đầu chưa đo người thật) ở TẦNG ỨNG DỤNG
thay vào đó — một `KeypointSmoother` RIÊNG cho mỗi phiên WebSocket
(`routes/realtime.py`) và mỗi video upload (`video_analysis_service.py`),
không dùng chung giữa các phiên (tránh trộn người). Mất người (`None`) hoặc
số khớp phát hiện đổi khác thì XOÁ trạng thái cũ thay vì nội suy — nối một
tư thế mới với vị trí cũ (có thể của người khác) sẽ tạo chuyển động giả,
tệ hơn không làm mượt. `visibility` KHÔNG bị làm mượt — giữ nguyên tín hiệu
"đang thấy rõ không" của đúng frame hiện tại, làm mượt nó sẽ khiến
`is_visible()` phản ứng trễ.

**2) Khung xương chỉ vẽ dạng "hộp", thiếu chi tiết — sửa bằng field mới
`all_keypoints`.** Nguyên nhân: `FrameAnalysisResult.keypoints` chỉ gồm
đúng những khớp ANALYZER ĐANG CHẠY thực sự dùng để tính góc — squat không
có khuỷu tay/mặt vì squat không cần, curl không có gối. Route
`routes/realtime.py` nay tự gắn thêm `all_keypoints` SAU KHI analyzer trả
kết quả, dựng từ TOÀN BỘ khớp MediaPipe (33 khớp, trừ đầu ngón tay — quá
nhỏ/nhiễu, không đáng vẽ) qua `pose_estimator.named_keypoints()` mới — 16
file analyzer không phải sửa gì, không cần biết field này tồn tại.

`SkeletonPainter` (Flutter) vẽ theo bộ xương ĐẦY ĐỦ mới (thêm khuỷu
tay/cổ tay/bàn chân/mặt), và `AnalyzeSessionScreen` đổi sang truyền
`frame.allKeypoints ?? frame.keypoints` (fallback chỉ để an toàn, không có
ý nghĩa thực tế vì backend/app luôn deploy cùng lúc). Khớp mặt (mũi, mắt,
tai, khoé miệng) chỉ vẽ CHẤM, không nối đường — nối đường giữa các khớp mặt
sát nhau ở khoảng cách camera thường đứng để tập sẽ rối, không phải chi tiết.

Chỉ áp dụng cho WebSocket real-time — `video_analysis_service.py` không cần
`all_keypoints` vì không có màn hiện trực tiếp cho video đã upload, chỉ có
bản tóm tắt lưu vào DB sau khi phân tích xong.

Thêm `tests/test_keypoint_smoother.py` (7 test) và `tests/test_pose_estimator.py`
(4 test, chỉ phần thuần không đụng MediaPipe/model file). 334 test backend
xanh (không phải sửa lại kỳ vọng nào của `test_realtime_ws.py`/
`test_video_analysis.py` — biên độ sẵn có trong các test đó đã đủ hấp thụ
độ trễ do làm mượt). 63 test Flutter xanh, `flutter analyze` 0 lỗi/cảnh báo
(chỉ còn các `info` có từ trước, không liên quan).

⚠️ **Ngưỡng α=0.5 của `KeypointSmoother` chưa đo trên người thật** — cùng
tình trạng với ngưỡng góc của các analyzer 06/09. Nếu vẫn thấy nhảy sau khi
deploy, thử giảm α (mượt hơn, nhưng trễ hơn); nếu thấy khung xương "trôi"
theo sau chuyển động thật rõ rệt, tăng α.

⚠️ **Chưa deploy lên VPS**, chưa xác nhận lại trên chính chiếc điện thoại đã
chụp hai ảnh trên.

### 06/09/2026

**Video upload nay được phân tích thật** — lấp một trong hai lỗ hổng lớn nhất
đã ghi từ 01/09 (lỗ hổng còn lại — `WorkoutSessions`/`SessionExercises`/
`SessionReps`/`RealtimeFeedback` chưa nối — vẫn còn nguyên). `app/services/video_analysis_service.py`
mới, chạy sau `POST /videos/upload` qua `BackgroundTasks` (không chặn
response). Tái dùng nguyên hạ tầng phân tích real-time (`ANALYZER_REGISTRY`,
`load_thresholds`, `SessionState`) thay vì viết lại — khác đúng một chỗ: đọc
frame từ file (`cv2.VideoCapture`, lấy mẫu ~10fps, trần 400 frame/video bất
kể video dài bao lâu) thay vì luồng JPEG real-time, và chạy tuần tự hết video
một lần thay vì theo từng frame.

**Cố tình KHÁC `routes/realtime.py` ở một điểm quan trọng:** bài không có
trong `ANALYZER_REGISTRY` thì KHÔNG rơi về `SquatAnalyzer`. Nhánh WebSocket
fallback squat vì client đã lọc trước bằng `supports_analysis` (không bao
giờ thực sự rơi vào nhánh đó) — nhưng nút "Upload a video instead" hiện cho
**MỌI bài**, kể cả bài không hỗ trợ phân tích (đây chính là ảnh chụp màn
hình dẫn tới việc này: "Abdominals Stretch Variation Three", một bài giãn
cơ). Rơi về squat mặc định ở đây sẽ đọc feedback squat cho một bài duỗi cơ —
sai hoàn toàn, không phải trường hợp hiếm như ở WebSocket.

Tách riêng `get_pose_estimator_pool()` singleton trong `pose_estimator_pool.py`
(trước đó pool là biến module riêng trong `realtime.py`) — để job phân tích
video dùng CHUNG pool với WebSocket thay vì tự dựng pool thứ hai tranh CPU
độc lập trên máy 2 vCPU.

Thêm `tests/test_video_analysis.py` (12 test): hàm thuần lấy mẫu frame +
dựng câu tóm tắt test trực tiếp; phần phân tích chuỗi keypoint dùng tư thế
dựng sẵn (không cần MediaPipe); phần tích hợp ghi/đọc DB monkeypatch
`AsyncSessionLocal` trỏ về SQLite của test — cùng cách `test_realtime_ws.py`
giả pose estimation. 323 test xanh, ruff sạch.

⚠️ **Chưa test bằng video thật, một video quay bằng điện thoại thật.** Toàn
bộ xác nhận trên đều bằng test tự động (monkeypatch), giống tình trạng "chưa
thử trên người thật" của các analyzer mới ngày hôm nay. Cũng chưa deploy lên
VPS.

**`PulldownAnalyzer` — rà nốt Pulldown/Pull-up, +13 bài** (analyzer thứ 16).
Suýt dùng chung `RowAnalyzer` cho gọn, nhưng rà kỹ thì lộ rủi ro thật: ngồi
kéo xà (pulldown) gập chân ra trước chứ không đứng cúi người như row, nên góc
vai-hông-gối tự nhiên chỉ còn ~90-100° dù ngồi đúng tư thế — sát ngay ngưỡng
`back_straight_min=100°` của Row, dễ báo nhầm "lưng cong" cho người ngồi bình
thường. `PulldownAnalyzer` dùng đúng góc khuỷu tay như Row nhưng **cố tình bỏ
hẳn phần kiểm lưng**. Gộp chung Lat Pulldown (kéo tạ xuống) và Pull-up/
Chin-up (kéo thân lên) vì cùng cơ chế góc khuỷu tay, chỉ khác vật di chuyển.

Loại `Straight Arm Lat Pulldown` — tên có "pulldown" nhưng chuyển động ở VAI,
khuỷu tay khoá gần thẳng suốt bài nên góc khuỷu tay gần như không đổi, không
đếm được rep nào nếu lỡ gộp vào. Loại `Single Arm Lat Pulldown` (quy tắc 1),
`Dead Hang` (giữ tĩnh), `Toes To Bar` (kết hợp thêm gập bụng, hai pha).

**Quyết định KHÔNG xây `ShrugAnalyzer`** cho 7 bài shrug (Band/Barbell/Cable/
Dumbbell/Kettlebell/Smith Machine/Trap Bar Shrug) — không phải vì lười mà vì
chưa tìm ra chỉ số góc nào đáng tin: shrug là vai nhô THẲNG LÊN (không gập
khuỷu, không gập hông, không gập gối), biên độ chuyển động rất nhỏ (vài cm),
nên khác hẳn mọi analyzer hiện có vốn dựa vào một góc khớp đổi rõ rệt (vài
chục độ). Một góc kiểu hông-vai-tai có thể đổi quá ít để phân biệt được với
nhiễu của pose estimation — xây rồi không đếm được rep nào còn tệ hơn không
hỗ trợ (đúng tinh thần "thà thiếu còn hơn chấm sai"). Cần đo thử trên người
thật trước khi quyết định có xây hay không, không đoán suông.

Giữ nguyên quyết định loại trừ `Barbell Rack Pull` (khấu 3 từ Giai đoạn 4):
rà thêm thấy rủi ro còn nặng hơn ban đầu nghĩ — ROM một phần nghĩa là có thể
**không bao giờ đếm được rep nào** với ngưỡng `hip_down=110°` mặc định của
deadlift (rack pull bắt đầu đã nửa đứng thẳng), không chỉ là "thỉnh thoảng
nhắc sai" như các trường hợp khác — mức rủi ro cao hơn hẳn, giữ loại trừ.

Độ phủ registry: 204 khoá tên / 16 analyzer, 197/417 bài. 311 test xanh,
ruff sạch.

**VPS thiếu `libGLESv2.so.2` khiến live-analysis không tracking bài nào cả,
mọi thiết bị.** Không phải bug code — MediaPipe `PoseLandmarker.create_from_options()`
cần OpenGL ES nội bộ dù chỉ chạy CPU, VPS mới `103.82.21.150` dựng lại từ đầu
hôm 04/09 thiếu 2 gói hệ điều hành `libgles2`/`libegl1`. Lỗi xảy ra ngay lúc
khởi tạo model nên 100% frame WebSocket đều rơi vào nhánh `except Exception`
chung của `routes/realtime.py`, trả `{"error": "Lỗi hệ thống phía server."}` —
không khung xương, rep không tăng, mọi bài. REST API (đăng nhập, danh sách bài
tập...) không đụng pose estimator nên vẫn chạy bình thường, đó là lý do lỗi
này không lộ ra qua các lượt test trước đó (toàn qua REST). Đã cài 2 gói qua
`apt-get` và restart service, xác nhận khung xương hiện đúng trên máy thật.
Xem chi tiết + traceback trong `loi can sua.md`.

**`CurlAnalyzer` — analyzer thứ 10, +20 bài tập** (đợt đầu của kế hoạch 4 giai
đoạn mở rộng độ phủ analyzer — xem "Còn nợ" bên dưới cho 3 giai đoạn còn lại).
Cùng cấu trúc góc khuỷu tay với `RowAnalyzer` (rep đếm bằng
`avg()` hai khuỷu tay: co hết = ngưỡng dưới, duỗi hết = ngưỡng trên), chỉ khác
không kiểm lưng thẳng vì curl không cúi người.

Rà tay 44 bài có chữ "curl" trong tên, chỉ nhận 20 bài thật sự là gập khuỷu
tay hai bên đồng thời — loại hẳn:
- **Sai khớp hoàn toàn dù tên trùng chữ "curl":** Leg Curl (gối/hamstring),
  Wrist Curl (cổ tay), Spinal Jefferson Curl (cột sống), Neck Curl (cổ) — copy
  y hệt bẫy `Rowing Machine Steady State` đã ghi trước đó, tên không nói lên
  cơ chế động tác.
- **Một tay — vỡ ngưỡng trung bình hai bên** (quy tắc 1 đã áp cho Row/Bench/
  Overhead Press/Hip Thrust): Dumbbell Standing Single Arm (Hammer) Curl,
  Dumbbell Concentration Curl (định nghĩa luôn một tay), Bayesian Curl (cable
  sau lưng, gần như luôn một tay), Cross Body Hammer Curl (luân phiên chéo
  thân), Dumbbell/Machine Preacher Curl (ghế preacher tạ đơn/máy thường tập
  một tay, khác Ez Bar Preacher Curl dùng thanh đòn nên bắt buộc hai tay).

Đã merge `hiep05` → `main` (fast-forward) và deploy lên VPS (`git pull` +
`systemctl restart posturex`) ngay trong ngày — 20 bài curl hoạt động thật
trên server, không chỉ ở local.

**`LateralRaiseAnalyzer` + `ChestFlyAnalyzer` — Giai đoạn 2, +19 bài tập**
(Raise/Fly cho vai — analyzer thứ 11 và 12). Rà tay 26 bài "Raise"/"Fly",
chỉ nhận 19 bài đối xứng hai tay: `LateralRaiseAnalyzer` gộp chung Lateral
Raise + Front Raise + Rear Delt Fly (11 bài — cùng chiều rep dù khác mặt
phẳng chuyển động: nghỉ = tay xuôi, đỉnh = tay nâng ngang vai);
`ChestFlyAnalyzer` riêng cho Chest/Pec Fly (8 bài — CHIỀU NGƯỢC LẠI: nghỉ =
tay mở rộng, đỉnh = tay khép lại trước ngực). Loại 7 bài một tay (Band/Cable
Single Arm Lateral Raise, Leaning Cable Lateral Raise — đứng nghiêng người
nên luôn một tay, Single Arm Cable Fly) theo đúng quy tắc 1, cộng calf raise
(khác khớp — mắt cá, để dành Giai đoạn 3) và knee raise (gập hông/core,
ngoài phạm vi vai).

**Bẫy phát hiện lúc viết `LateralRaiseAnalyzer`, suýt lọt qua test:** góc
hông-vai-khuỷu tay THÔ nhỏ lúc nghỉ (~15°, tay xuôi) và lớn lúc nâng (~85°) —
NGƯỢC chiều với mọi analyzer khác (squat/row/curl... đều nghỉ = góc lớn, đỉnh
= góc nhỏ). `RepCounter` mặc định khởi tạo ở `Phase.TOP`, ngầm giả định trạng
thái nghỉ ban đầu có góc LỚN HƠN `up_threshold` — nạp thẳng góc thô (nghỉ =
góc nhỏ, dưới cả `down_threshold`) sẽ khiến `RepCounter` tưởng vừa chạm đáy
ngay ở frame đầu tiên, đếm khống 1 rep trước khi người dùng làm gì cả. Sửa
bằng góc bù `180 - raw` chỉ dùng nội bộ cho `RepCounter`; `key_angles` trả về
vẫn là góc thô cho dễ đọc. `ChestFlyAnalyzer` không dính lỗi này vì nghỉ (tay
mở rộng) của nó vốn đã là góc lớn, đúng chiều mặc định.

Độ phủ registry: 152 khoá tên / 12 analyzer, 145/417 bài (từ 106/417 đầu
ngày). Cập nhật số liệu ở mọi nơi nhắc "9/10 analyzer" trong docstring code
và CLAUDE.md.

⚠️ **Mọi ngưỡng góc trong 3 analyzer mới (Curl/LateralRaise/ChestFly) đều là
ƯỚC LƯỢNG theo hình học, chưa đo trên người thật** — cùng tình trạng với
squat/lunge/deadlift lúc mới viết (xem CHANGELOG 01/09/2026). Cần hiệu chỉnh
qua `ExercisePostureRules`/`scripts/seed_posture_rules.py` sau khi có người
test thật, đặc biệt `LateralRaiseAnalyzer` vì công thức góc bù khó kiểm bằng
mắt hơn các analyzer còn lại.

Đã merge `hiep05` → `main` (fast-forward, sau khi phát hiện lỡ commit thẳng
vào `main` rồi phải đồng bộ ngược lại `hiep05`) và deploy lên VPS ngay trong
ngày — 19 bài raise/fly hoạt động thật trên server.

**`CalfRaiseAnalyzer` — Giai đoạn 3, +5 bài tập** (nhón gót — analyzer thứ
13). Rà tay 9 bài calf/ankle, chỉ nhận 5 bài đối xứng hai chân (Bodyweight
Donkey Calf Raise, Kettlebell/Smith Machine/Standing Calf Raise Machine,
Seated Calf Raise). Loại 2 bài một chân (Dumbbell Single Leg / Single Leg
Standing Calf Raise — quy tắc 1), `Tibialis Raise` (tên gần giống nhưng là
**gập mu bàn chân — ngược chiều hẳn** calf raise, cùng bẫy tên với Leg
Curl/Wrist Curl ở Giai đoạn 1), và `Horizontal Leg Press Calf Press` (máy
chuyên dụng, không đủ tự tin về góc camera, để rà lại ở Giai đoạn 4).

Khớp chính là mắt cá (góc gối-mắt cá-mũi chân) — nghỉ (bàn chân áp sàn) vốn
đã là góc lớn hơn `down_threshold`, khớp đúng giả định `Phase.TOP` mặc định
của `RepCounter` nên **không dính bẫy góc bù** như `LateralRaiseAnalyzer` ở
Giai đoạn 2 (đã tránh được nhờ nhận diện trước, không phải phát hiện lại).

Độ phủ registry: 157 khoá tên / 13 analyzer, 150/417 bài. Cập nhật số liệu
"12 analyzer"/"145 bài" ở CLAUDE.md và docstring code.

⚠️ Cùng cảnh báo với Giai đoạn 1-2: ngưỡng góc là ước lượng hình học, chưa đo
trên người thật.

Đã merge `hiep05` → `main` (fast-forward) và deploy lên VPS ngay trong ngày —
5 bài calf raise hoạt động thật trên server.

**Giai đoạn 4, +34 bài — không viết analyzer mới cho phần lớn.** Rà tay hết
267 bài còn lại, tìm ra hai việc:

1. **23 bài khớp thẳng vào 4 analyzer đã có, không cần code mới** — vì cơ chế
   góc khớp vốn đã tổng quát hơn tên bài gợi ý:
   - **17 bài → `BenchPressAnalyzer`**: Push Up/Push-up + 5 biến thể (Incline/
     Decline/Diamond/Elevated/Knee) và 3 bài Dip (Bench/Machine/Parallel Bar) —
     cùng cơ chế góc khuỷu tay (vai-khuỷu-cổ tay) mà docstring `bench_press.py`
     đã ghi từ đầu "không phụ thuộc tư thế nằm hay đứng"; chống đẩy dưới sàn
     hay dip tay ra sau đọc đúng y hệt đẩy tạ trên ghế. Cộng Floor Press,
     Cable/Machine/Decline/Incline Chest Press, Jm Press.
   - **4 bài → `HipThrustAnalyzer`**: Glute Bridge và 3 biến thể — về bản chất
     là hip thrust không kê vai lên ghế, cùng trục góc hông.
   - **1 bài → `DeadliftAnalyzer`**: Good Mornings — hip hinge có tải trên
     vai, cùng trục góc với Romanian Deadlift.
   - **1 bài → `LateralRaiseAnalyzer`**: Reverse Pec Deck — tên có "pec"
     nhưng thực chất là rear delt fly trên máy, không phải bài ngực.

2. **2 analyzer mới nhỏ** (thứ 14 và 15): `LegExtensionAnalyzer` (gối,
   2 bài — Machine/Machine Plate Loaded Leg Extension) và
   `TricepExtensionAnalyzer` (khuỷu tay, 9 bài — Pushdown/Skullcrusher/
   Overhead Extension). `TricepExtensionAnalyzer` **cố tình KHÔNG dùng chung
   class** với `OverheadPressAnalyzer` dù cùng bộ ba khớp và cùng hướng
   ngưỡng: lời nhắc của overhead press giả định tạ đi thẳng QUA ĐẦU, còn
   tricep extension tay duỗi XUỐNG/RA SAU — dùng chung sẽ đếm rep đúng nhưng
   hướng dẫn sai chiều. Đây đúng kiểu lỗi đã cảnh báo nhiều lần: kỹ thuật đo
   giống nhau không có nghĩa lời nhắc giống nhau.

**Cố tình KHÔNG làm trong đợt này** (để dành, chưa đủ tự tin hoặc cần thêm
thời gian rà kỹ): toàn bộ họ Pulldown/Pull-up (~13 bài — nghi ngờ hợp lệ
nhưng chưa kiểm đủ kỹ phạm vi góc khuỷu tay cho chuyển động kéo dọc, khác
kéo ngang của row), Shrug (~7 bài — cần chỉ số góc hoàn toàn khác, vai
nhô lên không phải góc khớp nào có sẵn), Barbell Rack Pull/Reverse
Hyperextension (hình học không chắc khớp ngưỡng deadlift mặc định), cùng
Wood Chopper/Side Bend/Kickback/Crunch/Carry/Face Pull/Hip Abduction/
External Rotation và mọi bài Olympic lift (Clean/Snatch/Jerk/Thruster —
đa pha, quá phức tạp cho ngưỡng góc đơn giản).

Độ phủ registry: 191 khoá tên / 15 analyzer, 184/417 bài. Cập nhật số liệu
"13 analyzer"/"150 bài" ở CLAUDE.md và docstring code. 303 test xanh, ruff
sạch.

⚠️ Cùng cảnh báo với các giai đoạn trước: ngưỡng góc là ước lượng hình học,
chưa đo trên người thật.

#### Còn nợ sau ngày này

- **Chưa deploy phân tích video upload lên VPS**, và chưa ai thử upload một
  video quay bằng điện thoại thật để xem `analysis_summary` trả về có hợp lý
  không — toàn bộ mới xác nhận bằng test tự động (monkeypatch DB + giả
  `_read_sampled_frames`/`_estimate_all`, không chạm cv2/MediaPipe thật).
- **Chưa xác nhận rep-count tăng đúng số** qua nhiều rep liên tiếp trên điện
  thoại thật (khung xương đã xác nhận đúng vị trí sau khi sửa `libGLESv2`,
  nhưng chưa ai squat liên tục 3-5 lần để xem số REPS có nhảy đúng không).
- **220/417 bài vẫn chưa có analyzer** (giảm từ 311 đầu ngày, qua 5 đợt:
  +20 curl, +19 raise/fly, +5 calf raise, +34 giai đoạn 4, +13 pulldown/
  pull-up). Cố tình KHÔNG làm, đã có lý do rõ ràng: Shrug (7 bài — chưa tìm
  ra chỉ số góc đáng tin, xem mục ở trên), Barbell Rack Pull/Reverse
  Hyperextension (rủi ro đếm 0 rep vĩnh viễn với ngưỡng mặc định), Cardio
  (~22+ bài — không có "góc đúng/sai"), Stretch/Mobility (giữ tư thế tĩnh,
  khác cơ chế đếm rep), Olympic lift/compound movement (đa pha, quá phức
  tạp). Còn lại **chưa rà tới** (không phải cố tình bỏ, chỉ là chưa có thời
  gian): carry (Farmers Carry, Turkish Get Up), crunch/sit-up, kickback,
  wood chopper, face pull, hip abduction/adduction, external rotation, side
  bend, wrist roller/pinch, back extension, box jump/burpee/mountain
  climber và các bài cardio/plyometric khác.

### 04/09/2026

**VPS mới `103.82.21.150`** (`7a90b28`, của VanGiap). VPS Cloudfly cũ
`103.179.172.246` hết hạn dùng thử. Thư viện 417 bài và 412 video đã được nhập
lại lên server mới; `GOOGLE_CLIENT_ID` cũng đổi sang OAuth client mới.

**App Android không gọi được VPS mới** (`db82ce7`). Commit đổi địa chỉ ở trên
sửa `api_config.dart` nhưng quên `network_security_config.xml`, vốn vẫn chỉ
liệt kê IP VPS cũ. File đó không khai `<base-config>` nên Android 9+ chặn
cleartext với mọi host không có tên trong danh sách: mọi request chết ngay ở
tầng hệ điều hành với `Cleartext HTTP traffic to … not permitted`, trong khi
server vẫn sống. Triệu chứng trông hệt như "server chết" nên rất dễ đổ lỗi
nhầm chỗ.

Nay tách làm hai bản theo source set — `src/main/` chỉ tin đúng IP VPS thật,
`src/debug/` cho phép mọi địa chỉ. Lý do tách: backend local mỗi người một IP
LAN, liệt kê từng cái nghĩa là cả nhóm sửa chung một file rồi commit đè lên
nhau. Nới lỏng chỉ áp cho bản debug nên không lọt tới bản lên store.

⚠️ **Đổi VPS phải sửa CẢ HAI chỗ**: `lib/config/api_config.dart` và
`android/app/src/main/res/xml/network_security_config.xml`. Quên vế thứ hai
chính là lỗi vừa rồi.

**Viết lại màn admin "AI Config"** — món nợ ghi ở mục 01/09. Trước khi sửa đã
kiểm từng ô điều khiển, và **4 trong 7 ô không có tác dụng gì**:

- `squat_rep_down_threshold` trùng `knee_depth` (squat dựng RepCounter bằng
  `down_threshold=t.get("knee_depth", …)`), mà handler chỉ áp ô kia.
- `squat_rep_up_threshold` handler không bao giờ đọc tới.
- `pose_min_detection_confidence` và `pose_model_complexity` không có đường
  nào tới pool — pool được dựng ở cấp module lúc import. Riêng
  `model_complexity` còn vô nghĩa ở tầng dưới: MediaPipe Tasks chọn độ phức
  tạp theo file model, tham số chỉ giữ cho tương thích.

Ba ô còn lại có tác dụng nhưng theo cách sai: chúng gán đè hằng số toàn cục
của module `squat`, tức sửa MẶC ĐỊNH của SquatAnalyzer — chỉnh cho một bài là
đổi luôn cả 21 biến thể squat, và mất sạch khi restart.

Cặp route `/admin/config` nay đổi thành `/admin/posture-rules`, ghi thẳng vào
`ExercisePostureRules` — đúng bảng `_load_exercise_thresholds` đọc lúc mở
phiên WebSocket. Mọi bài có analyzer đều chỉnh được (khoảng 106 bài), riêng
từng bài, và sống qua restart.

`app/ml/analyzers/tunables.py` là nguồn sự thật duy nhất cho "bài này chỉnh
được ngưỡng nào": nhãn, mặc định, khoảng hợp lệ. Cả API lẫn giao diện đọc từ
đây, nên thêm ngưỡng mới chỉ khai một chỗ. Ba điều đáng nhớ:

- **Khoá phải có trong `VALUE_COLUMN`.** Sai khoá thì ngưỡng vẫn ghi xuống DB
  bình thường rồi bị bỏ qua lúc chạy — không lỗi nào báo. Module tự kiểm lúc
  import và ném `RuntimeError`.
- **`ORDERED_PAIRS` + `MIN_REP_RANGE = 15°`.** Đảo ngược cặp ngưỡng đếm rep
  (vd đặt "đứng thẳng" thấp hơn "chạm đáy") là đặt ra điều kiện không bao giờ
  thoả: bộ đếm đứng im ở 0 rep, không lỗi nào báo. 15° vì `RepCounter` có biên
  dung sai 10° quanh đáy. Kiểm trên **giá trị có hiệu lực** — trộn cái admin
  nhập với mặc định — chứ không chỉ trên phần vừa gửi lên, nếu không thì sửa
  một vế của cặp sẽ lọt.
- **Kiểm theo tầng.** Có lỗi khoảng thì dừng, chưa kiểm thứ tự — đem một giá
  trị đã bị từ chối đi so sẽ ra thông báo sai hướng ("155° phải lớn hơn 999°")
  khiến admin đi sửa nhầm ô.

`values` khi lưu là **trạng thái đầy đủ** mong muốn: khoá vắng mặt bị xoá và
bài quay về mặc định. Nhờ vậy "gỡ ghi đè" không cần endpoint riêng. Dòng có
`RuleName` không phải khoá máy (schema seed sẵn vài dòng tên tiếng Việt) được
giữ nguyên, không đụng tới.

**`knee_overshoot` là khoá duy nhất không phải góc.** Nó là tỉ lệ theo chiều
rộng khung hình (0.05 = gối được vượt mũi chân 5% khung hình), nên lấy giá trị
từ cột `Tolerance` chứ không phải Min/MaxAngle. Trước đây squat/lunge/deadlift
đọc thẳng hằng số `KNEE_OVERSHOOT_RATIO` nên nó nằm ngoài mọi ghi đè; nay cả
ba đọc qua `self.threshold("knee_overshoot", …)`.

Vì nó khác đơn vị, `Tunable` có thêm `unit` và `step` — giao diện **không được
tự gắn "°"** vào mọi giá trị, và bước 1.0 cho một khoảng 0–0.3 sẽ cho thanh
trượt chỉ nhảy được giữa hai đầu. Cả hai trường đến từ backend.

Rà lại toàn bộ: **25 trong 26 hằng số ngưỡng của 9 analyzer nay chỉnh được**.
Cái còn lại là `plank.HORIZONTAL_POSTURE_RATIO` — heuristic nhận biết người
đang nằm plank hay đứng, không phải ngưỡng chấm kỹ thuật, và nó nằm trong một
hàm helper cấp module không đọc được `self.thresholds`.

#### Còn nợ sau ngày này

- **Chưa thử trên người thật** — vẫn nguyên từ 01/09.
- **Chưa deploy lên VPS mới.** Sau khi deploy: chạy `scripts/seed_posture_rules.py`
  để nhập 6 ngưỡng cho 5 bài (dữ liệu rule không đi theo git).
- **Chưa sửa `.env` trên VPS** — `GOOGLE_CLIENT_ID` phải đổi sang client mới,
  file `.env` không đi theo `git pull`.
- **OAuth Android client cho `com.posturex.app`** chưa đăng ký.
- **Bốn bảng lịch sử vẫn rỗng** — như 01/09.
- **Hai tham số pose không chỉnh được.** `min_detection_confidence` và
  `model_complexity` bị bỏ khỏi màn admin vì chúng là cấu hình toàn cục của
  một pool dựng sẵn lúc khởi động, không phải ngưỡng theo bài. Muốn chỉnh thật
  thì phải dựng lại pool giữa chừng.
- **Chưa ai mở màn admin mới trên máy thật.** Đã phủ 10 widget test (danh sách,
  mở chi tiết, gỡ ghi đè, đơn vị tỉ lệ, lỗi mạng) và đã gọi thử API trên server
  thật bằng curl, nhưng chưa ai đăng nhập admin rồi bấm qua giao diện.

### 01/09/2026

**Sửa 3 lỗi trong phân tích tư thế** (`bf77b44`). Cả ba đều không nhìn thấy
được khi chạy app, chỉ lộ ra khi bơm chuỗi góc đã biết trước vào analyzer:

- **Mọi rep bị đếm gấp đôi** (10 rep thật → 20), ở mọi bài tập vì lỗi nằm
  trong `RepCounter` dùng chung. Chỉ sai ở tốc độ tập thông thường — rất
  nhanh hoặc rất chậm lại đúng, nên rất khó thấy bằng mắt. Nguyên nhân:
  `_min_angle_seen` không được xoá khi người tập đứng thẳng lại, nên đáy của
  rep vừa xong khiến nhánh fallback FPS thấp tưởng vừa chạm đáy lần nữa.
- **Báo "chưa đủ sâu" suốt lúc đứng lên từ một rep hoàn hảo** (Squat, Lunge,
  Row, Bench Press). Điều kiện cũ `phase in (bottom, going_up) and góc >
  ngưỡng` không bao giờ đúng được. Điểm chính xác của một rep squat chuẩn chỉ
  còn 64,5%, và app đọc to lỗi đó qua TTS.
- **Cảnh báo "chưa duỗi hết ở đỉnh" là mã chết** (Deadlift, Hip Thrust,
  Overhead Press) — `phase == "top" and góc < ngưỡng_trên` tự mâu thuẫn vì
  phase chỉ thành "top" đúng lúc góc vượt ngưỡng đó.

`RepCounter` nay có hai tín hiệu **chỉ đúng trong frame hiện tại**:
`shallow_reversal` (đảo chiều đi lên khi chưa xuống gần đáy) và
`incomplete_lockout` (quay đầu đi xuống khi chưa duỗi hết). Analyzer đọc hai
cờ này thay vì tự suy từ `phase` — nhắc đúng một lần vào đúng lúc. Đừng quay
lại kiểu suy từ `phase`, đó chính là gốc của hai lỗi trên.

**Ngưỡng theo từng bài tập** (`c187512`). Xem mục "Bố cục backend" ở trên.
Sáu ngưỡng đã nhập cho 5 bài là **ước lượng theo cơ chế động tác, chưa đo trên
người thật** — thử được với camera thì sửa số trong `scripts/seed_posture_rules.py`
rồi chạy lại.

**Test tích hợp WebSocket**. Trước đó `load_thresholds` và analyzer đều có
test riêng nhưng chuỗi thật thì chưa: mở kết nối → xác thực → đọc ngưỡng →
chọn analyzer → phân tích từng frame. Nay `tests/test_realtime_ws.py` phủ
trọn đường đó, thay pose estimation bằng tư thế dựng sẵn nên không cần
MediaPipe. Ghi chú tìm được: `phase == "top"` chỉ tồn tại đúng một frame —
vượt ngưỡng đứng thẳng là thành "top", frame kế tiếp góc vẫn tăng nên đã
chuyển sang "going_down".

**Cách ly test Flutter** (`04d16c3`). Commit i18n dời nút Log out sang màn
Settings làm đỏ 2 test; thêm `setUp` reset trạng thái `static` để một lỗi
không kéo theo lỗi thứ hai che mất nguyên nhân.

**Dịch tài liệu này sang tiếng Việt** (`c59ca13`).

#### Còn nợ sau ngày này

- **Chưa thử trên người thật.** Toàn bộ phần trên kiểm bằng tư thế dựng sẵn.
  106 bài mở phân tích và 6 ngưỡng riêng đều chưa ai đứng trước camera thử.
- **Chưa deploy** — VPS Cloudfly hết hạn dùng thử và đang tắt. Khi bật lại:
  `git pull`, rồi chạy `scripts/seed_posture_rules.py` để nhập ngưỡng vào DB
  thật (dữ liệu rule không đi theo git).
- **Bốn bảng lịch sử vẫn rỗng** — `WorkoutSessions` / `SessionExercises` /
  `SessionReps` / `RealtimeFeedback`. Mỗi phiên vẫn chỉ lưu 4 con số tổng kết
  qua `POST /workouts`, nên không trả lời được "bài này user hay sai lỗi gì"
  hay "tuần này lỗi gối đổ vào trong có giảm không".
- **Màn admin "AI Config" lưu ngưỡng trong RAM** nên mất sạch mỗi lần restart,
  và chỉ chỉnh được squat, lại sửa biến toàn cục của module nên áp cho cả 21
  biến thể cùng lúc. Nên cho nó dùng chung cơ chế `ExercisePostureRules`.
  *(Đã sửa 04/09 — xem mục ngày đó. Hoá ra còn tệ hơn: 4 trong 7 ô điều khiển
  của màn hình đó không có tác dụng gì cả.)*
- **Android đổi `applicationId` sang `com.posturex.app`** — phải đăng ký OAuth
  client Android mới trong Google Cloud Console, nếu không nút "Continue with
  Google" báo lỗi.

## Kiến trúc

### Phân chia client ⇄ backend

App nói chuyện với backend qua REST (`http`) và một WebSocket. `ApiConfig` (`lib/config/api_config.dart`) **mặc định trỏ tới VPS đã triển khai**; nếu truyền `--dart-define=API_BASE_URL=…` lúc build thì giá trị đó thắng, và `wsUrl` suy ra `ws`/`wss` từ URL đang dùng. Trường hợp cần cờ bây giờ là khi chạy backend ngay trên máy mình:

```bash
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:9000    # máy ảo Android
flutter run --dart-define=API_BASE_URL=http://localhost:9000   # Windows/web
```

`10.0.2.2` là bí danh máy ảo dùng để gọi về *loopback của máy chủ*, nên backend bind ở `127.0.0.1` vẫn tới được từ máy ảo; `--host 0.0.0.0` chỉ cần khi test trên điện thoại thật qua LAN (khi đó còn cần IP thật của máy — xem docs/SETUP.md).

Mặc định trỏ về server là có chủ đích, và chiều của nó quan trọng. `API_BASE_URL` là hằng số **biên dịch**, không phải cấu hình lúc chạy — mỗi lần build đều phải truyền lại, và nó không được lưu ở đâu cả. Hồi mặc định còn là địa chỉ máy dev, quên cờ một lần là app im lặng trỏ về `10.0.2.2` rồi báo "Could not reach the server" trong khi server vẫn sống; tệ hơn nữa, một bản phát hành build kiểu đó sẽ lên store với địa chỉ chỉ có nghĩa trên máy ảo. Hỏng về phía server thật thì người chịu là dev đang chạy backend local, và họ phát hiện ngay lập tức. `.vscode/launch.json` có sẵn cấu hình cho cả hai chiều, còn `test/config/api_config_test.dart` sẽ đỏ nếu mặc định bị đổi ngược về địa chỉ dev.

⚠️ Mặc định hiện tại là một **IP trần chạy HTTP**. Trước khi phát hành thật phải đổi thành domain HTTPS: App Transport Security của iOS chặn thẳng `http://`, nhiều mạng trường học/công ty chặn các cổng lạ như 9000, và IP nằm cứng trong bản build nghĩa là ngày server đổi chỗ thì mọi app đã cài đều chết. `googleWebClientId` trong file đó phải luôn khớp với `GOOGLE_CLIENT_ID` của backend, vì backend đối chiếu claim `aud` của ID token với giá trị này.

- `ApiClient` (`lib/services/api_client.dart`) — lớp bọc mỏng dạng singleton cho REST API (`ApiClient.instance`). `http.Client` bên trong có thể tiêm được nên test truyền vào `MockClient`; `instance` cố tình không khai `final` cũng vì lý do đó. Response không thuộc 2xx sẽ ném `ApiException` mang theo chuỗi `detail` của backend. Mọi lời gọi đều có timeout, vì `package:http` không đặt sẵn cái nào và một request treo sẽ khiến màn hình đứng vĩnh viễn: 20 giây cho lời gọi thường, **90 giây cho `/coach/*`** (Gemini mất 5–20 giây là chuyện bình thường), **5 phút cho upload video**. Hết giờ thì lộ ra dưới dạng `ApiException(408, …)` nên mọi khối `catch` sẵn có vẫn chạy đúng.
- `TokenStorage` (`lib/services/token_storage.dart`) — lưu phiên đăng nhập vào Android Keystore / iOS Keychain qua `flutter_secure_storage`, tuyệt đối không dùng SharedPreferences. Nó uỷ quyền cho `SecureStorageBackend` thay thế được, vì plugin thật không có platform channel trong môi trường widget test.
- `AnalyzeSocketService` (`lib/services/analyze_socket_service.dart`) — bọc `/api/v1/ws/analyze`: kết nối, gửi `{"exercise": ...}`, rồi truyền liên tục các frame JPEG dạng base64 và nhận về `FrameAnalysisResult` từng frame (số rep, các góc chính, lời góp ý). `AnalyzeSessionScreen` đọc to phần góp ý đó qua `flutter_tts` và vẽ khung xương bằng `SkeletonPainter`. Endpoint này **có** yêu cầu xác thực: token truyền qua query string (`/ws/analyze?token=…`) chứ không qua header, vì nhiều WebSocket client không đặt được header lúc bắt tay. Ghi chú cũ nói đây là lỗ hổng không xác thực đã lỗi thời.

Thống kê theo từng người dùng (chuỗi ngày liên tiếp, trung bình tuần, xu hướng độ chính xác) được tính **phía client** trong `lib/utils/workout_stats.dart` từ danh sách thô của `GET /workouts`, dùng chung cho màn Progress và Profile. Không có endpoint `/stats` nào; hai route tổng hợp duy nhất của backend là `/admin/stats` và `/admin/revenue`, đều ở phạm vi toàn hệ thống và chỉ admin gọi được.

### Điều hướng

Không dùng package router nào (không go_router/auto_route) và không có named route — các màn hình điều hướng bằng `Navigator.push`/`pushReplacement(MaterialPageRoute(...))` thuần. Sơ đồ tổng thể:

```
SplashScreen (tự chuyển) → LoginScreen ⇄ RegisterScreen → OtpVerificationScreen
                             │    │                                │
                ForgotPassword    │                        OnboardingFlow (14 bước)
                      ↓           │                                │
               ResetPassword      │                        PlanGeneratingScreen
                                  ▼                                ▼
                    ┌─── is_admin ? ───┐
                    ▼                  ▼
         admin.HomeScreen        MainShell (khung bottom-nav)
         (11 màn admin)       ── Home · Exercises · Workout · Progress · Profile ──
```

`MainShell` (`lib/screens/main_shell.dart`) chứa 5 tab trong một `IndexedStack`, không phải router — trạng thái tab chỉ là một biến `int` trong `State`. Các màn hình mở ra từ shell: `AnalyzeSessionScreen` (camera trực tiếp + WebSocket), `UploadVideoScreen`, `WorkoutSummaryScreen`, `ExerciseDetailScreen`, `AiCoachScreen` (chat Gemini), `NotificationsScreen` → `NotificationDetailScreen`, `EditProfileScreen`, và `SubscriptionScreen` → `PaymentWebViewScreen` (thanh toán MoMo trong `webview_flutter`).

### Luồng xác thực

Đăng ký **bắt buộc qua OTP**: `register()` tạo tài khoản chưa xác thực và gửi mã qua email; tài khoản không đăng nhập được cho tới khi `verifyOtp()` thành công, và chính lời gọi đó trả về access token (nên nó kiêm luôn lần đăng nhập đầu tiên). Google Sign-In (`lib/services/google_auth_service.dart` → `POST /api/v1/auth/google`) tự đăng ký phía server ở lần dùng đầu, nên vừa là đăng nhập vừa là đăng ký trong một lời gọi.

**Việc vào khu admin do server quyết định.** Sau khi đăng nhập thành công, `LoginScreen` rẽ nhánh theo `profile.isAdmin` — trường mà backend điền từ bảng `Roles` — và push `admin.HomeScreen()` thay vì `MainShell()`. Không còn cửa hậu bằng tài khoản cứng nữa (lối tắt `admin@gmail.com` / `123456` trước đây đã bị gỡ), và không có dữ liệu giả: cả 11 màn admin (`lib/features/admin_*/`) đều đi qua khoảng 22 phương thức `/api/v1/admin/*` của `ApiClient`, bọc sau lớp repository/use-case riêng của từng feature admin, gọi vào server thật. Muốn vào khu admin thì cần tài khoản thật có vai trò `Admin` — `python scripts/create_admin.py` tạo một cái.

### Trạng thái: một session tĩnh, không dùng thư viện quản lý state

Không có provider/riverpod/bloc. `UserSession` (`lib/models/user_session.dart`) là một class thuần gồm các trường `static`, đóng vai trò session trong bộ nhớ cho cả app — các màn hình đọc thẳng `UserSession.name`, `UserSession.plan`… ngay trong `build()`. Không có listener/stream nào, nên cập nhật `UserSession` **không** tự động vẽ lại những màn hình đã dựng; giá trị mới chỉ hiện ở lần build kế tiếp (thường là sau một lần điều hướng).

Hiện nó trộn hai nguồn sự thật: các trường từ backend (`accessToken`, `userId`, `email`, do `applyAuthSession` đặt) và các trường chỉ có trong onboarding (`heightCm`, `weightKg`, `age`, `plan`, …) vốn không có cột tương ứng ở backend và do `completeOnboarding` đặt. `logOut()` đặt lại **mọi** trường về giá trị mặc định đã ghi rõ — khi thêm trường session mới, phải nối nó vào tất cả các đường "set" (`completeOnboarding`, `applyAuthSession`) *và* phần reset của `logOut`, đồng thời xoá khỏi `TokenStorage` nếu trường đó có lưu xuống.

### Hệ thống bước onboarding

`OnboardingFlow` (`lib/screens/onboarding/onboarding_flow.dart`) chạy một bộ câu hỏi tuyến tính bằng các widget bước dùng chung trong `lib/widgets/onboarding/` (`MultiSelectChipStep`, `SingleSelectListStep`, `SingleSelectCardStep`, `CheckboxListStep`, `NumberWheelStep`, `WorkoutFrequencyStep`, `WorkoutDaysStep`), mỗi cái bọc trong khung `OnboardingScaffold` dùng chung (nút quay lại, thanh tiến độ, nút CTA ghim dưới). `OnboardingFlow` giữ một `OnboardingProfile` thay đổi được và một biến `int _index`, đổi `steps[_index]` sau mỗi `setState`.

**Bẫy:** mỗi bước trong danh sách đó đều được gán `key: ValueKey(step)`. Đây là bắt buộc chứ không phải trang trí — khi hai bước *liền nhau* dùng cùng một class widget (ví dụ ba `NumberWheelStep` liên tiếp cho chiều cao/tuổi/cân nặng), cơ chế so khớp element của Flutter sẽ tái dùng chính object `State` đó nếu key không khác nhau, âm thầm mang giá trị các trường khởi tạo `late` của bước trước sang bước sau. Lỗi này đã từng lọt ra thật (tuổi và cân nặng đều hiện giá trị chiều cao) trước khi thêm key — đừng bao giờ thêm bước mới mà không có key riêng.

Chỉ một phần câu trả lời có cột tương ứng ở backend (`gender`, `height_cm`, `weight_kg`, `fitness_level`, và `weekly_goal`); `ApiClient.updateProfile` gửi đúng phần đó. Phần còn lại chỉ nằm ở client.

### Sinh lịch tập

`WorkoutPlan.generate(...)` (`lib/models/workout_plan.dart`) là một hàm thuần, biến câu trả lời onboarding (ngày trong tuần đã chọn, tần suất, nhóm cơ trọng tâm, trình độ) thành lịch 4 tuần canh theo lịch dương (luôn bắt đầu từ Chủ Nhật gần nhất để lưới hiện đủ tuần). Nội dung buổi tập theo mẫu có sẵn (`Full Body`, `Upper Push`, `Upper Pull`, `Lower & Core`) và xoay vòng qua các ngày tập người dùng chọn. Bất chấp cách trình bày của `PlanGeneratingScreen` và việc backend có tồn tại, **phần sinh lịch này vẫn chạy hoàn toàn ở máy và không gọi gì cả** — phần AI trong app là ở khâu phân tích tư thế, không phải khâu lên lịch.

### Bố cục backend (`backend/app/`)

Phân tầng FastAPI tiêu chuẩn: `api/v1/routes/` (auth, users, workouts, videos, realtime, admin, notifications, subscriptions, exercises, coach) → `crud/` → `models/` (SQLAlchemy, MySQL bất đồng bộ qua aiomysql) cùng `schemas/` cho phần vào/ra kiểu Pydantic. `core/` giữ settings, phiên DB, rate limit, và phần bảo mật JWT/mật khẩu; `services/` giữ các tích hợp ra ngoài (email, Gemini, MoMo, FCM push, nhắc nhở).

Phần đáng chú ý nhất là `app/ml/`: `pose_estimator.py` chạy pose landmarker của MediaPipe (`app/ml/models/pose_landmarker_full.task`, tải bằng `scripts/download_models.py` — là file nhị phân, đã gitignore, không commit vào mã nguồn), `angle_utils.py` tính góc khớp, `rep_counter.py` đếm rep bằng máy trạng thái, và `analyzers/` chứa phần nhận xét kỹ thuật cho từng bài.

**Đừng bao giờ gọi thẳng `PoseEstimator.estimate()` từ code async.** `detect()` của MediaPipe là lời gọi CPU 30–60 ms và không nhả điều khiển, nên chạy nó bên trong handler WebSocket sẽ đóng băng *toàn bộ* event loop — đăng nhập và mọi request khác đều xếp hàng sau người đang tập dở. `app/ml/pose_estimator_pool.py` đẩy việc đó sang luồng riêng và giới hạn số lượng chạy cùng lúc. Phải là pool chứ không phải chỉ `asyncio.to_thread`, vì `PoseLandmarker` **không thread-safe**: hai luồng dùng chung một instance là hành vi không xác định. Instance được tạo lười, số lượng lấy theo số CPU và chặn trên ở 4.

`ANALYZER_REGISTRY` nằm ở `app/ml/analyzers/registry.py` (không phải `routes/realtime.py` — `routes/exercises.py` cũng cần nó, mà import module realtime sẽ kéo cả mediapipe vào chỉ để đọc vài cái tên). Nó ánh xạ **204 khoá tên bài tập vào 16 class analyzer**, phủ 197 trong khoảng 417 bài của thư viện (thêm 7 analyzer mới ngày 06/09/2026 — xem Nhật ký thay đổi). Danh sách được liệt kê từng tên một cách có chủ đích: khớp theo chuỗi con nhìn thì tiện nhưng sai theo kiểu đánh lừa người dùng — "Barbell Upright Row" là bài vai, "Nar-row Pulldown" chỉ tình cờ chứa mấy chữ cái đó, "Rowing Machine Steady State" là bài cardio. Các biến thể cũng bị loại khi analyzer gộp hoặc so sánh hai bên (row một tay không bao giờ chạm ngưỡng co vì cánh tay rảnh kéo giá trị trung bình lên), và split squat được ánh xạ sang `LungeAnalyzer` chứ không phải `SquatAnalyzer` vì lunge lấy `min()` của hai gối trong khi squat lấy trung bình. `tests/test_analyzer_registry.py` khoá lại các quyết định loại trừ đó. Tên không có trong bảng sẽ rơi về `SquatAnalyzer` kèm một cảnh báo trong log, nhưng client nên dùng cờ `supports_analysis` của `GET /exercises` để người dùng không bao giờ rơi vào nhánh dự phòng đó.

Các analyzer là **ngưỡng góc viết tay, không phải model đã huấn luyện** — `squat.py` ghi cứng `KNEE_DEPTH_THRESHOLD = 95.0` và tương tự. Đó là **giá trị mặc định**; từng bài tập ghi đè được qua bảng `ExercisePostureRules` (xem `app/ml/analyzers/thresholds.py`).

**Ngưỡng theo từng bài.** Chỉ có 16 analyzer cho 197 bài nên mọi biến thể cùng họ vốn dùng chung một bộ ngưỡng — `Seal Row` nằm sấp bị chấm bằng đúng ngưỡng lưng của `Barbell Bent Over Row` cúi 45°. Analyzer giữ nguyên phần logic phức tạp (gối vượt mũi chân, lệch hai bên, nhận biết tư thế nằm) và chỉ đọc CON SỐ ngưỡng từ DB. Bài chưa nhập ngưỡng riêng thì dùng mặc định, nên bật cơ chế này lên không đổi hành vi bài nào đang chạy.

Ba điều cần nhớ khi nhập ngưỡng: `RuleName` là **khoá máy** (`back_straight_min`, `knee_depth`…), không phải mô tả — tên khác sẽ bị bỏ qua trong im lặng, trong đó có 4 dòng seed sẵn của schema đặt tên tiếng Việt. Mỗi khoá lấy giá trị từ **cột cố định** (`MinAngle` cho cận dưới, `MaxAngle` cho cận trên) — nhầm cột thì ngưỡng đảo chiều mà không có lỗi nào báo. Và `RepCounter` có **biên dung sai 10°** quanh đáy cho trường hợp FPS thấp, nên hai ngưỡng cách nhau dưới 10° sẽ cho cùng kết quả. Dùng `scripts/seed_posture_rules.py` (có `--dry-run`, chạy lại an toàn) để nhập.

`PostureErrorTypes` thì vẫn **chưa có code nào đọc** — câu nhắc bằng giọng nói tiếng Việt trong đó chưa được dùng.

Rộng hơn, `sql/postureX123_schema.sql` thiết kế 25 bảng (DB thật có 35 nếu tính cả view và phần thêm về sau) mà phần lớn vẫn chưa nối vào code. `MuscleGroups`/`ExerciseMuscleGroups` thì *đã* nối — `app/models/muscle_group.py` là nền cho bộ lọc 16 nhóm cơ ở tab Exercises. Nhóm chưa dùng gồm `WorkoutSessions` / `SessionExercises` / `SessionReps` / `RealtimeFeedback` — tức toàn bộ lịch sử theo từng rep, từng lỗi mà WebSocket đang tính rồi vứt đi, chỉ giữ lại bản tóm tắt do client gửi ngược lên qua `POST /workouts`. Đừng mặc định rằng bảng tồn tại nghĩa là tính năng chạy.

**Video người dùng tải lên có được phân tích** (từ 06/09/2026, xem CHANGELOG) — trước đó chỉ lưu file, `analysis_summary`/`total_reps`/`accuracy_score` trên bảng `videos` không bao giờ được ghi. `app/services/video_analysis_service.py` chạy NGẦM qua `BackgroundTasks` ngay sau `POST /videos/upload` (response trả về trước, không bắt client chờ), tái dùng nguyên `ANALYZER_REGISTRY`/`load_thresholds`/`SessionState` mà `routes/realtime.py` dùng cho WebSocket — chỉ khác nguồn frame là `cv2.VideoCapture` đọc file thay vì luồng JPEG theo thời gian thực, và chạy tuần tự hết video một lần thay vì theo từng frame trực tiếp. Bài không có trong `ANALYZER_REGISTRY` thì KHÔNG rơi về `SquatAnalyzer` như nhánh WebSocket — client offer nút upload cho MỌI bài kể cả bài không hỗ trợ phân tích (khác nút "Phân tích tư thế" trực tiếp, chỉ hiện khi `supports_analysis`), rơi vào squat mặc định sẽ đọc feedback sai hoàn toàn cho một bài duỗi cơ hay bài cổ. `get_pose_estimator_pool()` (`app/ml/pose_estimator_pool.py`) là pool DÙNG CHUNG giữa WebSocket và job phân tích video — video không tự dựng pool riêng, tránh tranh CPU độc lập với người đang tập live trên cùng server.

### Rate limit và CORS

`app/core/rate_limit.py` giữ một `Limiter` duy nhất dùng chung. Bốn endpoint bị giới hạn: `/auth/forgot-password` (5/giờ, chống spam email), `/auth/login` (10/phút;100/giờ, chống dò mật khẩu), và cả hai route AI Coach — `/coach/chat` (10/phút;100/giờ) và `/coach/plan` (5/phút;20/giờ) — vì mỗi lời gọi tiêu quota Gemini thật, nên endpoint không giới hạn đồng nghĩa hoá đơn không giới hạn. Hai cái bẫy nằm ở đây:

- Thân response 429 là `{"detail": ...}` bằng tiếng Việt, do chính hàm `rate_limit_handler` của module tạo ra. Handler mặc định của slowapi trả `{"error": ...}`, mà `ApiClient._decode` chỉ đọc khoá `detail` — nên quay về mặc định là app hiện câu chung chung "Something went wrong" thay vì lý do thật. Một test trong `tests/test_forgot_password.py` khoá lại hình dạng này.
- **Đừng** bật `headers_enabled=True` trên `Limiter`. Ở nhánh thành công, slowapi gọi `_inject_headers(kwargs.get("response"), …)` cho mọi endpoint không trả về `Response` — mà các endpoint ở đây trả về model Pydantic — nên nó truyền `None` và ném lỗi ở *mọi request thành công*. Muốn bật thì phải thêm `response: Response` vào chữ ký của tất cả endpoint có rate limit; thay vào đó `rate_limit_handler` tự gắn `Retry-After`.

CORS **không** để `["*"]`: kết hợp với `allow_credentials=True` sẽ khiến Starlette phản chiếu lại origin của bất kỳ ai gọi tới. `settings.ALLOWED_ORIGINS` nhận danh sách origin production cụ thể từ `.env`, còn `ALLOWED_ORIGIN_REGEX` khớp localhost ở mọi cổng để phục vụ `flutter run -d chrome` (lệnh này chọn cổng ngẫu nhiên). Bản build native Android/iOS/Windows không gửi header `Origin`, nên phần này không ảnh hưởng gì tới chúng.

### Thư viện bài tập và video demo

Thư viện gồm khoảng 417 bài trải trên 16 nhóm cơ, nhập từ một cây thư mục 412 file `.mp4` bằng `scripts/import_exercise_videos.py` (chạy `--dry-run` trước; `--copy` giữ nguyên thư mục nguồn để chạy lại được nếu lần đầu hỏng giữa chừng). Tên bài suy ra từ tên file, nên `band-assisted-pull-up.mp4` thành "Band Assisted Pull Up".

**App tìm video qua cột trong DB, không phải bằng cách quét thư mục.** `Exercises.DemoVideoUrl` giữ một đường dẫn *tương đối* (`/media/exercise-videos/<file>.mp4`) mà client ghép thêm `ApiConfig.baseUrl` vào trước. Chép file lên server mà không cập nhật cột đó thì hoàn toàn không có tác dụng — nhầm lẫn này đã tốn một buổi gỡ lỗi.

Phục vụ video đòi hỏi đăng nhập: `main.py` xử lý `/media/exercise-videos/{filename}` kèm phụ thuộc `get_current_user` thay vì mount `StaticFiles`, vì phần lớn thư viện là video bản quyền của bên thứ ba, không nên đặt ở URL công khai. Hai hệ quả cần nhớ — `{filename}` chỉ khớp một đoạn đường dẫn, nên file phải nằm **phẳng** trong `storage/exercise_videos/` (không chia thư mục con theo nhóm cơ); và `video_player` không đi qua `ApiClient`, nên `GuideVideoPlayer` phải tự gắn bearer token qua `httpHeaders`.

### Triển khai

Backend chạy trên một VPS Cloudfly (Ubuntu, 2 vCPU / 4 GB) dưới systemd với tên service `posturex.service`, MySQL nằm ngay trên máy đó và cổng 3306 đóng với Internet. Chưa có nginx và chưa có TLS, nên nó phục vụ HTTP trần ở cổng 9000 — đó là lý do iOS chưa gọi được và đôi khi các mạng bị siết cũng không gọi được.

Thông tin đăng nhập thật (đường dẫn khoá SSH, mật khẩu DB, các lệnh deploy) nằm trong `DEPLOY_SERVER.md`, file này **bị gitignore và chỉ có trên máy các thành viên** — hãy hỏi đồng đội thay vì tìm trong repo. `.gitignore` chặn file đó ở cả gốc repo lẫn trong `docs/`, cộng thêm `*.pem`/`*.key`, sau khi phát hiện khoá riêng tư nằm chình ình trong thư mục làm việc mà chỉ cần một lệnh `git add .` là đẩy lên công khai.

Deploy là `git pull` + `systemctl restart posturex` trên server. Lưu ý `backend/.env` **không** nằm trong git và không đi theo lệnh pull: mọi biến mới đều phải thêm tay trên server — đó đúng là cách một giá trị `GEMINI_MODEL` gõ sai sống sót qua vài lần deploy.

⚠️ **VPS cần cài sẵn `libgles2` và `libegl1`** (`apt-get install -y libgles2 libegl1`), không có trong `requirements.txt` vì đây là thư viện hệ điều hành, không phải gói Python. MediaPipe `PoseLandmarker.create_from_options()` cần OpenGL ES nội bộ dù chỉ chạy CPU — thiếu nó thì **khởi tạo model ném ngay `libGLESv2.so.2: cannot open shared object file`**, bị nuốt bởi handler bắt lỗi chung trong `routes/realtime.py` (gửi `{"error": "Lỗi hệ thống phía server."}`) — hậu quả là mọi request `/ws/analyze` đều lỗi, mọi bài tập, mọi thiết bị, không có khung xương, rep không tăng, mà endpoint khác (REST) vẫn chạy bình thường nên trông như "chỉ mỗi khung xương bị lỗi vặt". VPS Cloudfly cũ có sẵn gói này (cài kèm từ trước không rõ khi nào); VPS mới `103.82.21.150` dựng lại từ đầu hôm 04/09 thì thiếu, và không ai phát hiện ra cho tới khi thử live-analysis thật hôm 06/09 — trước đó chỉ kiểm REST API (đăng ký/đăng nhập/danh sách bài tập) nên không đụng tới code path này. Đổi/dựng lại VPS lần sau nhớ cài 2 gói này trước khi coi như xong.

### Hình vẽ tay (không có asset ảnh/font)

Asset duy nhất được đóng gói là `assets/video/` (hiện có `squat.mp4`, khoảng 1,9 MB, do `GuideVideoPlayer` phát làm video mẫu). **Không có asset ảnh hay font nào** — các dấu hiệu thương hiệu đều vẽ vector bằng code với `CustomPainter`: `AppLogo` (`lib/widgets/app_logo.dart`, dấu "X" của PostureX), chữ "G" của Google bên trong `lib/widgets/google_sign_in_button.dart`, và lớp phủ khung xương trong `lib/widgets/skeleton_painter.dart`. Hãy theo đúng cách này cho mọi icon/logo mới cần co giãn theo nhiều kích thước (đã dùng từ 18 đến 48px) thay vì thêm asset ảnh.

### Giao diện và màu sắc

`lib/theme/app_theme.dart` là nguồn sự thật duy nhất cho màu (`AppColors`, nền tối với màu nhấn `primary` cam san hô) và `AppTheme.dark` (`ThemeData` Material 3). Hãy tái dùng `AppColors.*` thay vì ghi cứng mã hex trong widget. Các màn admin có bảng màu riêng ở `lib/theme/admin_theme.dart` (cùng các widget dùng chung trong `lib/widgets/admin/`), nhưng vì chúng vẽ bên trong cùng một `MaterialApp` do `lib/main.dart` dựng nên, `ThemeData` bao quanh vẫn là `AppTheme.dark`.

### Test analyzer bằng tư thế dựng sẵn (backend)

`tests/pose_builders.py` dựng bộ 33 keypoint giả đặt đúng vị trí hình học, nên kiểm được toàn bộ logic phân tích mà không cần camera hay MediaPipe — cách còn lại là nhờ người đứng trước camera tập thử, vừa chậm vừa không tái hiện được. Đã xác minh bộ dựng chính xác: yêu cầu góc 95° thì đo lại đúng 95,0°.

`tests/test_analyzers.py` phủ cả 16 analyzer, `tests/test_posture_thresholds.py` phủ cơ chế ngưỡng theo từng bài. Chạy analyzer qua một dãy góc mô phỏng nhịp tập thật (14 frame mỗi chiều ≈ một rep 2,5 giây ở 12 fps) rồi so với kỳ vọng.

Ba lỗi từng lọt qua vì **không lỗi nào nhìn thấy được khi chạy app** — số rep vẫn nhảy, vẫn có lời nhắc, mọi thứ trông như đang hoạt động. Viết test cho phần này nghĩa là bơm chuỗi góc đã biết trước vào và so kết quả, không phải mở app ra nhìn.

### Cách viết test và các bẫy (xem `test/widget_test.dart`)

Bộ test Flutter gồm 17 bài: phần lớn là widget test chạy trọn luồng (đăng ký → onboarding → sinh lịch → home, đăng nhập → đăng xuất, bấm vào một ngày trên lịch) cộng vài unit test thuần nằm dưới `test/features/`, `test/config/` và `test/services/`.

`test/widget_test.dart` có một `setUp` reset `UserSession`, ngôn ngữ và kho lưu trữ giả trước mỗi test. Đừng bỏ nó: trạng thái app nằm ở các class toàn trường `static` và không tự reset, nên một test hỏng giữa chừng sẽ để lại phiên đăng nhập và test kế tiếp vào thẳng Home thay vì Login rồi hỏng theo — lỗi thứ hai che mất nguyên nhân thật. Thêm trạng thái `static` mới thì nhớ nối vào `setUp` đó. Bất cứ thứ gì chạm tới mạng đều phải tiêm `MockClient` vào `ApiClient` và một `SecureStorageBackend` giả vào `TokenStorage` — plugin thật không có platform channel dưới `flutter_test`. Vài cái bẫy hay gặp, nên biết trước khi viết thêm test:

- **`ListView` dựng lười:** `ListView(children: [...])` chỉ gắn vào cây những phần tử nằm trong khung nhìn cộng vùng đệm — widget nằm dưới màn hình sẽ không tìm thấy bằng `find.text(...)` dù về mặt logic nó có trong cây widget. Test nào cần với tới nội dung ở dưới thì phải đặt bề mặt cao lên trước: `tester.view.physicalSize = const Size(500, 2400); tester.view.devicePixelRatio = 1.0; addTearDown(tester.view.reset);`.
- **Nội dung "offstage" giữa lúc chuyển màn:** kiểm tra text ngay sau một `pushReplacement` (ví dụ ở frame đầu tiên của `PlanGeneratingScreen`/`SplashScreen`) có thể trượt, vì route đang vào về mặt kỹ thuật nằm ngoài sân khấu trong đúng một frame — trong tình huống đó hãy dùng `find.text(..., skipOffstage: false)`.
- **Chuyển màn tự động theo thời gian phải dùng `AnimationController`, không dùng `Future.delayed`:** `pumpAndSettle()` chỉ chờ hết các *frame/ticker* đang chờ; một `Future.delayed` trần không được nó theo dõi nên test sẽ chạy vượt qua điểm điều hướng trước khi nó kịp bắn. Cả `PlanGeneratingScreen` lẫn `SplashScreen` đều điều khiển việc tự chuyển màn bằng `AnimationController.addStatusListener` chính vì lý do này — hãy theo đúng cách đó cho mọi chuyển màn có hẹn giờ.
- **Font dự phòng trong test làm text rộng ra:** môi trường test không nạp font thật nên chữ đo ra rộng hơn trên máy/trình duyệt thật, và điều đó đã từng lộ ra lỗi tràn `Row`/`spaceBetween` có thật mà kiểm tra tay trên máy không thấy. Với mọi `Row` chứa hai nhãn text nằm cạnh nhau, hãy ưu tiên `Expanded`/`Flexible` kèm `overflow: TextOverflow.ellipsis`.
