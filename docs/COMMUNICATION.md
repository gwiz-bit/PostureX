# Giao tiếp Flutter ⇄ Backend

Tài liệu này mô tả **thực tế** 4 luồng giao tiếp chính giữa app Flutter và
backend FastAPI — method, path, status code, và thứ tự message — lấy trực
tiếp từ code (`app/api/v1/routes/*.py`, `lib/services/api_client.dart`,
`lib/services/analyze_socket_service.dart`), không phải thiết kế trên giấy.

Mục đích: đọc hiểu "ai gửi gì cho ai, lúc nào" mà không cần chạy app hay
Postman. Base URL xem [lib/config/api_config.dart](../lib/config/api_config.dart)
(`http://localhost:9000` khi dev, override bằng `--dart-define=API_BASE_URL=...`
lúc build production).

---

## 1. Đăng ký + xác thực OTP

`RegisterScreen` → `OtpVerificationScreen` → `OnboardingFlow` (local) →
`PlanGeneratingScreen` → `MainShell`.

```mermaid
sequenceDiagram
    participant App as Flutter App
    participant API as FastAPI Backend
    participant SMTP as Gmail SMTP

    App->>API: POST /api/v1/auth/register {email, password, fullName}
    API->>API: tạo user (is_email_verified=false)
    API->>SMTP: gửi mã OTP
    alt gửi OTP thất bại
        API-->>App: 502 "Không gửi được email OTP"
    else email đã tồn tại
        API-->>App: 400 "Email đã được sử dụng."
    else thành công
        API-->>App: 201 UserOut
    end

    App->>API: POST /api/v1/auth/verify-otp {email, otp_code}
    alt OTP sai/hết hạn
        API-->>App: 400 "Mã OTP không đúng hoặc đã hết hạn."
    else đúng
        API->>API: is_email_verified = true
        API-->>App: 200 TokenResponse {access_token}
    end
    Note over App: verify-otp là API DUY NHẤT vừa xác thực<br/>vừa đăng nhập — không có bước login riêng sau đó

    opt người dùng bấm "Gửi lại mã"
        App->>API: POST /api/v1/auth/resend-otp {email}
        API->>SMTP: gửi mã OTP mới
        API-->>App: 200 MessageResponse
    end

    Note over App: OnboardingFlow — 14 bước, THUẦN LOCAL,<br/>không gọi API nào trong lúc điền

    App->>API: PUT /api/v1/users/me/profile {age, gender,<br/>height_cm, weight_kg, fitness_level, weekly_goal}
    Note over API: chỉ lưu subset có cột backend —<br/>phần còn lại của OnboardingProfile chỉ tồn tại client-side
    API-->>App: 200 ProfileData
```

---

## 2. Đăng nhập (thường + Google)

```mermaid
sequenceDiagram
    participant App as Flutter App
    participant API as FastAPI Backend
    participant Google as Google OAuth

    rect rgb(30, 30, 35)
    Note over App,API: Đăng nhập thường
    App->>API: POST /api/v1/auth/login {email, password}
    alt sai email/mật khẩu
        API-->>App: 401 "Email hoặc mật khẩu không đúng."
    else chưa xác thực email
        API-->>App: 403 "Email chưa được xác thực..."
    else thành công
        API-->>App: 200 TokenResponse {access_token}
    end
    end

    rect rgb(30, 30, 35)
    Note over App,Google: Đăng nhập Google — 1 lệnh vừa login vừa register
    App->>Google: GoogleSignIn (SDK, không qua backend)
    Google-->>App: id_token
    App->>API: POST /api/v1/auth/google {id_token}
    API->>Google: verify id_token (server-side, không tin client)
    Google-->>API: idinfo {email, email_verified, name}
    API->>API: tạo user mới nếu email chưa có
    API-->>App: 200 TokenResponse {access_token, is_new_user}
    Note over App: is_new_user=true → có thể cần đẩy qua Onboarding
    end
```

---

## 3. Upload video buổi tập

```mermaid
sequenceDiagram
    participant App as Flutter App
    participant API as FastAPI Backend

    App->>API: POST /api/v1/videos/upload?exercise=squat<br/>Authorization: Bearer <token><br/>multipart file
    alt định dạng/kích thước sai
        API-->>App: 400 ValueError detail
    else thành công
        API->>API: video_service.save() — lưu file + tạo row DB
        API-->>App: 201 VideoOut
    end

    Note over App,API: Khác hẳn luồng #4 — đây là REST thuần,<br/>phân tích chạy 1 lần sau khi upload xong,<br/>không phải stream frame-by-frame qua WebSocket

    App->>API: GET /api/v1/videos (Bearer token)
    API-->>App: 200 VideoOut[]
    App->>API: GET /api/v1/videos/{id} (Bearer token)
    alt không tìm thấy / không phải chủ sở hữu
        API-->>App: 404
    else
        API-->>App: 200 VideoOut
    end
```

---

## 4. Phiên phân tích tư thế realtime (WebSocket)

`AnalyzeSessionScreen` → `AnalyzeSocketService`. Xem
[backend/app/api/v1/routes/realtime.py](../backend/app/api/v1/routes/realtime.py).

```mermaid
sequenceDiagram
    participant App as Flutter App
    participant WS as Backend /ws/analyze

    App->>WS: connect ws://.../api/v1/ws/analyze?token=<access_token>
    Note over WS: decode_token(token) chạy TRƯỚC accept()
    alt thiếu/sai token
        WS-->>App: close(code=1008, "Token không hợp lệ...")
    else hợp lệ
        WS->>WS: accept()
        App->>WS: {"exercise": "squat"}  (JSON, text frame)
        WS-->>App: {"status": "ready", "exercise": "squat", "message": "..."}

        loop mỗi frame camera
            App->>WS: JPEG frame (base64 string HOẶC bytes thô)
            alt không giải mã được frame
                WS-->>App: {"error": "Không đọc được frame."}
            else không phát hiện người trong frame
                WS-->>App: {"rep_count", "errors": ["Không phát hiện được người..."],<br/>"correct": false, "key_angles": {tất cả null}, "phase", "keypoints": null}
            else phân tích được
                WS-->>App: FrameAnalysisResult JSON<br/>{rep_count, key_angles, errors, correct, phase, keypoints}
            end
        end

        App->>WS: đóng kết nối (rời màn hình / bấm dừng)
        Note over WS: log tổng kết phiên (reps, độ chính xác)<br/>KHÔNG gửi message cuối nào về client trước khi đóng
    end
```

**Điểm dễ nhầm:**
- Đây là endpoint duy nhất dùng token qua **query param**, không phải header
  `Authorization` — vì WebSocket handshake trên nhiều client (kể cả web)
  không set header tuỳ ý được lúc connect.
- `ANALYZER_REGISTRY` trong `realtime.py` hiện chỉ map ~10 bài tập cụ thể;
  tên bài tập không khớp sẽ tự fallback về `SquatAnalyzer` (log warning,
  không báo lỗi cho client).
- Không có message "kết thúc phiên" nào gửi về app — `WorkoutSummaryScreen`
  tự tổng hợp từ dữ liệu đã nhận được qua các frame trước đó, không đợi
  server gửi thêm gì sau khi đóng socket.
