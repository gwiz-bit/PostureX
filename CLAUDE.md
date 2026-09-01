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
pytest                                # test backend (tests/) — hiện 123, tất cả đều xanh
pytest --cov=app                      # đo coverage (58% ở lần đo gần nhất, trước khi nhập thư viện bài tập)
ruff check .                          # lint — cấu hình trong pyproject.toml; phải sạch
ruff format .                         # định dạng code
```

Bộ quy tắc của `ruff` đã được chỉnh trong `pyproject.toml` sao cho `ruff check .` **xanh trên cây mã hiện tại** — một cổng kiểm tra mà mở ra đã đỏ 200 lỗi tồn đọng thì rốt cuộc ai cũng bỏ qua. Vài quy tắc nằm trong `ignore`, mỗi cái kèm chú thích nói rõ bật lại sẽ tốn gì; hãy siết từng cái một thay vì mở rộng `select`. Có một mục mang tính sống còn chứ không phải thẩm mỹ: `flake8-bugbear.extend-immutable-calls` liệt kê `fastapi.Depends`/`Query`/`File`/…, thiếu nó là B008 báo nhầm khoảng 105 chỗ trên khắp các route.

Cấu hình đọc từ `backend/.env` (xem `.env.example`): kết nối MySQL, `SECRET_KEY`, thông tin SMTP để gửi OTP, `GOOGLE_CLIENT_ID`, `GEMINI_API_KEY` (AI Coach), khoá MoMo tuỳ chọn (BE-14 — giá trị mặc định trong `config.py` là bộ khoá *sandbox công khai* của MoMo, nên thanh toán chạy được ngay trên bản clone mới), và thông tin FCM tuỳ chọn (BE-13 — không cấu hình thì phần push bị bỏ qua lặng lẽ). `GOOGLE_CLIENT_ID` phải giống từng ký tự với `googleWebClientId` trong `lib/config/api_config.dart`. Tài liệu API tương tác ở `/docs` — nhưng chỉ khi `DEBUG=True`; trên bản triển khai thật thì `docs_url`/`redoc_url`/`openapi_url` đều là `None` để không phơi toàn bộ bề mặt API ra ngoài.

**Bẫy encoding của `.env`.** `slowapi` tự nuốt file `.env` lúc import chỉ vì file đó tồn tại (`Config(".env")` trong `slowapi/extension.py`), mà `starlette.config.Config` mở file *không chỉ định encoding* — nên trên máy Windows dùng locale tiếng Việt, codec cp1252 gặp phần chú thích UTF-8 trong file là server chết ngay lúc import với `UnicodeDecodeError: 'charmap' codec can't decode byte 0x81`, trước cả khi uvicorn kịp bind cổng. `app/core/rate_limit.py` vô hiệu hoá bẫy này bằng cách truyền `config_filename=os.devnull`; đừng trả nó về mặc định. Triệu chứng chỉ xuất hiện trên một số máy, nên "máy tôi chạy ổn" không chứng minh được gì ở đây.

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

`ANALYZER_REGISTRY` nằm ở `app/ml/analyzers/registry.py` (không phải `routes/realtime.py` — `routes/exercises.py` cũng cần nó, mà import module realtime sẽ kéo cả mediapipe vào chỉ để đọc vài cái tên). Nó ánh xạ **112 khoá tên bài tập vào 9 class analyzer**, phủ 106 trong khoảng 417 bài của thư viện. Danh sách được liệt kê từng tên một cách có chủ đích: khớp theo chuỗi con nhìn thì tiện nhưng sai theo kiểu đánh lừa người dùng — "Barbell Upright Row" là bài vai, "Nar-row Pulldown" chỉ tình cờ chứa mấy chữ cái đó, "Rowing Machine Steady State" là bài cardio. Các biến thể cũng bị loại khi analyzer gộp hoặc so sánh hai bên (row một tay không bao giờ chạm ngưỡng co vì cánh tay rảnh kéo giá trị trung bình lên), và split squat được ánh xạ sang `LungeAnalyzer` chứ không phải `SquatAnalyzer` vì lunge lấy `min()` của hai gối trong khi squat lấy trung bình. `tests/test_analyzer_registry.py` khoá lại các quyết định loại trừ đó. Tên không có trong bảng sẽ rơi về `SquatAnalyzer` kèm một cảnh báo trong log, nhưng client nên dùng cờ `supports_analysis` của `GET /exercises` để người dùng không bao giờ rơi vào nhánh dự phòng đó.

Các analyzer là **ngưỡng góc viết tay, không phải model đã huấn luyện** — `squat.py` ghi cứng `KNEE_DEPTH_THRESHOLD = 95.0` và tương tự. Đáng chú ý là DB *cũng* chứa kiến thức này: `ExercisePostureRules` và `PostureErrorTypes` đã được nạp sẵn bộ ba khớp, góc nhỏ nhất/lớn nhất, và câu nhắc bằng giọng nói tiếng Việt, nhưng **không có code nào đọc chúng**. Hai nguồn này đã lệch nhau (DB ghi lưng thẳng ≥160°, `squat.py` dùng 150°). Sửa ngưỡng trong DB không có tác dụng gì; phải sửa ở analyzer.

Rộng hơn, `sql/postureX123_schema.sql` thiết kế 25 bảng (DB thật có 35 nếu tính cả view và phần thêm về sau) mà phần lớn vẫn chưa nối vào code. `MuscleGroups`/`ExerciseMuscleGroups` thì *đã* nối — `app/models/muscle_group.py` là nền cho bộ lọc 16 nhóm cơ ở tab Exercises. Nhóm chưa dùng gồm `WorkoutSessions` / `SessionExercises` / `SessionReps` / `RealtimeFeedback` — tức toàn bộ lịch sử theo từng rep, từng lỗi mà WebSocket đang tính rồi vứt đi, chỉ giữ lại bản tóm tắt do client gửi ngược lên qua `POST /workouts`. Video người dùng tải lên cũng vậy: có lưu nhưng không bao giờ được phân tích (`analysis_summary`, `total_reps`, `accuracy_score` trên bảng `videos` không bao giờ được ghi). Đừng mặc định rằng bảng tồn tại nghĩa là tính năng chạy.

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

### Hình vẽ tay (không có asset ảnh/font)

Asset duy nhất được đóng gói là `assets/video/` (hiện có `squat.mp4`, khoảng 1,9 MB, do `GuideVideoPlayer` phát làm video mẫu). **Không có asset ảnh hay font nào** — các dấu hiệu thương hiệu đều vẽ vector bằng code với `CustomPainter`: `AppLogo` (`lib/widgets/app_logo.dart`, dấu "X" của PostureX), chữ "G" của Google bên trong `lib/widgets/google_sign_in_button.dart`, và lớp phủ khung xương trong `lib/widgets/skeleton_painter.dart`. Hãy theo đúng cách này cho mọi icon/logo mới cần co giãn theo nhiều kích thước (đã dùng từ 18 đến 48px) thay vì thêm asset ảnh.

### Giao diện và màu sắc

`lib/theme/app_theme.dart` là nguồn sự thật duy nhất cho màu (`AppColors`, nền tối với màu nhấn `primary` cam san hô) và `AppTheme.dark` (`ThemeData` Material 3). Hãy tái dùng `AppColors.*` thay vì ghi cứng mã hex trong widget. Các màn admin có bảng màu riêng ở `lib/theme/admin_theme.dart` (cùng các widget dùng chung trong `lib/widgets/admin/`), nhưng vì chúng vẽ bên trong cùng một `MaterialApp` do `lib/main.dart` dựng nên, `ThemeData` bao quanh vẫn là `AppTheme.dark`.

### Cách viết test và các bẫy (xem `test/widget_test.dart`)

Bộ test gồm 17 bài: phần lớn là widget test chạy trọn luồng (đăng ký → onboarding → sinh lịch → home, đăng nhập → đăng xuất, bấm vào một ngày trên lịch) cộng vài unit test thuần nằm dưới `test/features/`, `test/config/` và `test/services/`. Bất cứ thứ gì chạm tới mạng đều phải tiêm `MockClient` vào `ApiClient` và một `SecureStorageBackend` giả vào `TokenStorage` — plugin thật không có platform channel dưới `flutter_test`. Vài cái bẫy hay gặp, nên biết trước khi viết thêm test:

- **`ListView` dựng lười:** `ListView(children: [...])` chỉ gắn vào cây những phần tử nằm trong khung nhìn cộng vùng đệm — widget nằm dưới màn hình sẽ không tìm thấy bằng `find.text(...)` dù về mặt logic nó có trong cây widget. Test nào cần với tới nội dung ở dưới thì phải đặt bề mặt cao lên trước: `tester.view.physicalSize = const Size(500, 2400); tester.view.devicePixelRatio = 1.0; addTearDown(tester.view.reset);`.
- **Nội dung "offstage" giữa lúc chuyển màn:** kiểm tra text ngay sau một `pushReplacement` (ví dụ ở frame đầu tiên của `PlanGeneratingScreen`/`SplashScreen`) có thể trượt, vì route đang vào về mặt kỹ thuật nằm ngoài sân khấu trong đúng một frame — trong tình huống đó hãy dùng `find.text(..., skipOffstage: false)`.
- **Chuyển màn tự động theo thời gian phải dùng `AnimationController`, không dùng `Future.delayed`:** `pumpAndSettle()` chỉ chờ hết các *frame/ticker* đang chờ; một `Future.delayed` trần không được nó theo dõi nên test sẽ chạy vượt qua điểm điều hướng trước khi nó kịp bắn. Cả `PlanGeneratingScreen` lẫn `SplashScreen` đều điều khiển việc tự chuyển màn bằng `AnimationController.addStatusListener` chính vì lý do này — hãy theo đúng cách đó cho mọi chuyển màn có hẹn giờ.
- **Font dự phòng trong test làm text rộng ra:** môi trường test không nạp font thật nên chữ đo ra rộng hơn trên máy/trình duyệt thật, và điều đó đã từng lộ ra lỗi tràn `Row`/`spaceBetween` có thật mà kiểm tra tay trên máy không thấy. Với mọi `Row` chứa hai nhãn text nằm cạnh nhau, hãy ưu tiên `Expanded`/`Flexible` kèm `overflow: TextOverflow.ellipsis`.
