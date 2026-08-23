# Sơ đồ tổng quan PostureX

Hai flowchart: (1) toàn bộ màn hình Flutter và đường điều hướng giữa chúng,
(2) kiến trúc hệ thống nhìn từ trên xuống. Lấy trực tiếp từ [CLAUDE.md](../CLAUDE.md)
(mục Navigation/Architecture) — xem file đó để có chú thích chi tiết hơn.

## 1. Luồng màn hình & điều hướng

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

    Decision -- có --> AdminHome[admin.HomeScreen<br/>11 màn hình quản trị]
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
nằm trong 5 tab chính.

## 2. Kiến trúc hệ thống

```mermaid
flowchart LR
    subgraph Client["Flutter App"]
        UI[Screens / Widgets]
        ApiClient["ApiClient<br/>(REST, lib/services/api_client.dart)"]
        WS["AnalyzeSocketService<br/>(WebSocket)"]
        TokenStorage["TokenStorage<br/>(Keychain / Keystore)"]
    end

    subgraph Backend["FastAPI Backend — port 9000"]
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

    UI --> ApiClient
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
