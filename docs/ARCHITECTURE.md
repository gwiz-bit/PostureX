# Sơ đồ tổng quan PostureX

Bốn phần: (1) bố cục repo — Flutter và backend là 2 thư mục ngang hàng, (2)
toàn bộ màn hình Flutter và đường điều hướng giữa chúng, (3) Clean
Architecture áp dụng cho 16 feature Dart, (4) kiến trúc hệ thống nhìn từ
trên xuống. Lấy trực tiếp từ [CLAUDE.md](../CLAUDE.md) — xem file đó để có
chú thích chi tiết hơn.

## 1. Bố cục repo

```mermaid
flowchart TD
    Root(["PostureX/ (1 git repo)"])
    Root --> Lib["lib/ — Flutter app (Dart)<br/>compile vào app binary"]
    Root --> Backend["backend/ — FastAPI service (Python)<br/>chạy như tiến trình server riêng (uvicorn)"]
    Root --> Other["android/ · ios/ · web/ · windows/ · docs/ ..."]

    Lib --> LibFeatures["features/ — 16 feature,<br/>Clean Architecture mỗi feature"]
    Lib --> LibShared["screens/ · widgets/ · theme/ · models/ · services/<br/>(shell điều hướng, UI dùng chung, ApiClient)"]

    Backend --> BeApp["app/ — routes · crud · models · schemas · core · services · ml"]
    Backend --> BeOther["scripts/ · tests/ · sql/"]

    classDef root fill:#402920,stroke:#FF6F4F,color:#F5F5F5
    classDef dart fill:#1c3323,stroke:#6DE86D,color:#F5F5F5
    classDef py fill:#1A1B1D,stroke:#4DA6FF,color:#F5F5F5
    class Root root
    class Lib,LibFeatures,LibShared dart
    class Backend,BeApp,BeOther py
```

Hai thư mục ngang hàng vì đây là **hai runtime hoàn toàn khác nhau** — Dart
biên dịch thành app, Python chạy như server độc lập — chúng chỉ nói chuyện
qua REST/WebSocket, không có quan hệ import nào. `backend/` từng nằm lồng ở
`lib/backend/`; đã dời ra gốc repo vì `lib/` vốn chỉ dành cho Dart và việc
lồng vào không có lợi ích gì.

## 2. Luồng màn hình & điều hướng

```mermaid
flowchart TD
    Splash([SplashScreen<br/>tự động chuyển]) --> Login[LoginScreen]
    Login <--> Register[RegisterScreen]
    Login -- quên mật khẩu --> Forgot[ForgotPasswordScreen] --> Reset[ResetPasswordScreen]
    Register --> Otp[OtpVerificationScreen]
    Otp --> Onboarding[OnboardingFlow<br/>14 bước, thuần local]
    Onboarding --> PlanGen[PlanGeneratingScreen]

    Login -- email/password đúng --> Decision
    Login -- Google Sign-In<br/>tự đăng ký nếu chưa có --> Decision
    PlanGen --> Decision{is_admin?<br/>backend trả về}

    Decision -- có --> AdminHome["admin.HomeScreen<br/>lib/features/admin_dashboard/<br/>11 màn hình quản trị"]
    Decision -- không --> MainShell[[MainShell<br/>bottom-nav, IndexedStack]]

    MainShell --- Home[Home]
    MainShell --- Exercises[Exercises]
    MainShell --- Workout[Workout]
    MainShell --- Progress[Progress]
    MainShell --- Profile[Profile]

    MainShell -.-> Analyze[AnalyzeSessionScreen<br/>camera trực tiếp + WebSocket]
    MainShell -.-> Upload[UploadVideoScreen]
    MainShell -.-> Summary[WorkoutSummaryScreen]
    MainShell -.-> ExDetail[ExerciseDetailScreen]
    MainShell -.-> Coach[AiCoachScreen<br/>chat Gemini]
    MainShell -.-> Notif[NotificationsScreen] --> NotifDetail[NotificationDetailScreen]
    MainShell -.-> EditProfile[EditProfileScreen]
    MainShell -.-> Sub[SubscriptionScreen] --> Payment[PaymentWebViewScreen<br/>MoMo checkout]

    classDef entry fill:#402920,stroke:#FF6F4F,color:#F5F5F5
    classDef shell fill:#1A1B1D,stroke:#4DA6FF,color:#F5F5F5
    class Splash,Decision entry
    class MainShell shell
```

Không dùng router package nào (không go_router/auto_route), không named
route — toàn bộ điều hướng bằng `Navigator.push`/`pushReplacement` thuần.
Đường nét đứt (`-.->`) = màn hình chỉ mở được từ trong `MainShell`, không
nằm trong 5 tab chính. `admin.HomeScreen` vẫn đúng bí danh import
(`as admin`) — khu quản trị không phải app riêng, chỉ là các màn hình khác
trong cùng 1 `main()`, giờ nằm dưới `lib/features/admin_*/`.

## 3. Clean Architecture — 16 feature Dart

```mermaid
flowchart LR
    subgraph Pattern["Khuôn dùng cho MỌI feature"]
        direction TB
        P1["presentation/<br/>screens + controller (ChangeNotifier)"]
        D1["domain/<br/>entities · repositories (interface) · usecases"]
        Da1["data/<br/>datasources (gọi ApiClient) · repository impl"]
        M1["‹feature›_module.dart<br/>composition root — nối tay, không DI framework"]
        P1 --> D1
        Da1 -.implements.-> D1
        M1 --> P1
        M1 --> Da1
    end

    subgraph MainApp["7 feature main app"]
        F1[workout]:::f
        F2[video]:::f
        F3[exercises]:::f
        F4[notifications]:::f
        F5[subscription]:::f
        F6[coach]:::f
        F7["auth<br/>(strangler-fig quanh UserSession/TokenStorage)"]:::f
    end

    subgraph AdminApp["9 feature admin (lib/features/admin_*)"]
        A1[admin_dashboard]:::af
        A2[admin_users]:::af
        A3[admin_workouts]:::af
        A4[admin_videos]:::af
        A5[admin_exercises]:::af
        A6[admin_ai_config]:::af
        A7[admin_plans]:::af
        A8[admin_revenue]:::af
        A9[admin_notifications]:::af
    end

    Pattern -.áp dụng cho.-> MainApp
    Pattern -.áp dụng cho.-> AdminApp

    classDef f fill:#1c3323,stroke:#6DE86D,color:#F5F5F5
    classDef af fill:#3a2a15,stroke:#FFA64D,color:#F5F5F5
```

`AppFailure` (`lib/core/errors/failures.dart`, sealed class với
`NetworkFailure`/`ServerFailure`) là kiểu lỗi domain-layer dùng chung cho cả
16 feature, tách biệt khỏi `ApiException` (data-layer). Phần chưa migrate:
shell điều hướng (`MainShell`, `Splash/Home/Profile screen`), `UserSession`
tĩnh, `TokenStorage`, `lib/theme/`, `lib/widgets/` — những thứ mang tính hạ
tầng dùng chung, không thuộc về 1 feature cụ thể nên vẫn ở nguyên vị trí cũ.

## 4. Kiến trúc hệ thống

```mermaid
flowchart LR
    subgraph Client["Flutter App (lib/)"]
        UI["Screens / Widgets"]
        RDS["‹Feature›RemoteDataSource<br/>(1 cái mỗi feature)"]
        ApiClient["ApiClient<br/>(lib/services/api_client.dart)"]
        WS["AnalyzeSocketService<br/>(WebSocket)"]
        TokenStorage["TokenStorage<br/>(Keychain / Keystore)"]
    end

    subgraph Backend["FastAPI Backend (backend/) — port 9000"]
        Routes["api/v1/routes<br/>auth · users · workouts · videos<br/>realtime · admin · notifications<br/>subscriptions · exercises · coach"]
        ML["app/ml<br/>MediaPipe pose estimator<br/>+ 9 analyzer (11 tên bài tập)"]
        Services["services<br/>email · gemini · momo · fcm · reminders"]
    end

    DB[("MySQL")]
    Google(["Google OAuth"])
    Gemini(["Gemini API"])
    MoMo(["MoMo Payment Gateway"])
    SMTP(["Gmail SMTP"])
    FCM(["Firebase Cloud Messaging"])

    UI --> RDS --> ApiClient
    UI --> WS
    TokenStorage -.token.-> ApiClient
    TokenStorage -.token.-> WS

    ApiClient <-->|"REST + Bearer JWT"| Routes
    WS <-->|"WS ?token=&lt;access_token&gt;"| Routes

    Routes --> ML
    Routes --> Services
    Routes <--> DB

    Services --> SMTP
    Services --> Gemini
    Services --> MoMo
    Services --> FCM
    Routes -. "verify id_token" .-> Google

    classDef client fill:#1c3323,stroke:#6DE86D,color:#F5F5F5
    classDef backend fill:#1A1B1D,stroke:#4DA6FF,color:#F5F5F5
    classDef ext fill:#3a2a15,stroke:#FFA64D,color:#F5F5F5
    class Client client
    class Backend backend
    class Google,Gemini,MoMo,SMTP,FCM ext
```

**Ghi chú:**
- Chiều gọi thật là `Screen → RemoteDataSource → ApiClient` (qua use case +
  repository ở giữa) — UI không gọi thẳng `ApiClient.instance` nữa như
  trước migrate, mỗi feature có 1 `RemoteDataSource` riêng bọc quanh
  `ApiClient`.
- `ApiConfig` (`lib/config/api_config.dart`) chọn host theo 2 lớp: build-time
  `--dart-define=API_BASE_URL=…` nếu có, không thì tự suy ra
  `10.0.2.2:9000` (Android emulator) hoặc `localhost:9000`.
- WebSocket là endpoint duy nhất xác thực qua **query param** `token=`
  thay vì header `Authorization` (xem [docs/COMMUNICATION.md](COMMUNICATION.md) mục 4).
- `ML` (MediaPipe + analyzer) chạy **trong tiến trình backend**, không phải
  service tách riêng — mỗi frame WebSocket được xử lý đồng bộ ngay trong
  route handler.
- MoMo/Gemini/FCM đều optional — thiếu key thì tính năng liên quan tắt êm
  (MoMo trả 503 có chủ đích, FCM bỏ qua push trong im lặng), không crash app.
