/* =====================================================================
   POSTURE X  -  AI Real-time Posture Correction App
   MySQL 8 database script  —  BẢN GỘP (schema gốc trong repo + v2)
   ---------------------------------------------------------------------
   Gộp hai file:
     (1) backend/sql/postureX123_schema.sql  — bản gốc trong repo
     (2) postureX123_schema_v2.sql           — bản mở rộng (onboarding,
                                                giáo án mẫu, 412 bài tập)
   Lấy (2) làm nền, bổ sung những gì (1) và code backend cần mà (2) thiếu.
   Tên file, tên database (`poturex123`), tên bảng và tên cột giữ theo bản
   gốc / theo code, vì backend đang ràng buộc vào chúng:
     - scripts/run_schema.py đọc đúng file sql/postureX123_schema.sql
     - .env dùng DB_NAME=poturex123
     - các model SQLAlchemy map thẳng vào tên bảng/cột PascalCase

   NHỮNG GÌ ĐÃ SỬA SO VỚI v2 ĐỂ CHẠY ĐƯỢC VÀ KHỚP CODE
   ---------------------------------------------------
   1. VolumeModifiers.MaxValue: MAXVALUE là từ khoá của MySQL nên v2 lỗi cú
      pháp 1064 ngay ở bảng này. Đã bọc backtick `MinValue` / `MaxValue`.
   2. Thêm 6 bảng do backend quản lý (trước đây tạo qua create_tables.py /
      ensure_tables.py), đúng tên và cột như model SQLAlchemy:
        videos, workouts, email_otps, password_reset_tokens,
        device_tokens, coach_messages
      Các script đó chạy với checkfirst=True nên sẽ bỏ qua, không tạo trùng.
   3. Exercises.Name đổi theo đúng quy tắc sinh tên của
      scripts/import_exercise_videos.py (viết hoa chữ đầu mỗi từ, vd
      "Ez Bar Preacher Curl" thay vì "EZ Bar Preacher Curl"). Collation
      utf8mb4_unicode_ci không phân biệt hoa thường nên nếu để lệch, script
      import sẽ không khớp được bài cũ và dính lỗi trùng UQ_Exercises_Name.
   4. Trigger trg_Exercises_BeforeInsert: model Exercise của backend không
      biết cột Slug / MovementRoleId / ExcludedReason, nên khi admin tạo bài
      qua API hoặc chạy script import, INSERT sẽ vi phạm Slug NOT NULL và
      CK_Exercises_RoleOrReason. Trigger tự sinh Slug từ Name và ghi lý do
      mặc định khi bài chưa được gán vai trò.
   5. Giữ lại 5 bài mẫu của bản gốc (Squat, Push-up, Lunge, Plank, Bicep
      Curl) vì ANALYZER_REGISTRY và màn Workout của Flutter dùng đúng các
      tên này. Bài thứ 6 (Jumping Jack) trùng v2 nên chỉ bổ sung metadata.
      Luật góc và danh mục lỗi tư thế của bản gốc được seed lại vào đúng
      các bài đó.
   6. Bỏ dấu ; trong một câu trả lời AiQaPairs: run_schema.py tách câu lệnh
      theo dấu ; nên dấu ; nằm trong chuỗi làm vỡ câu INSERT.

   CẢNH BÁO: dòng đầu tiên xoá sạch database poturex123. Không chạy file
   này trên server đang có dữ liệu người dùng thật.
   ===================================================================== */

DROP DATABASE IF EXISTS poturex123;
CREATE DATABASE poturex123 CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE poturex123;

/* =====================================================================
   1. NHÓM TÀI KHOẢN & PHÂN QUYỀN   (giữ nguyên bản gốc)
   ===================================================================== */

CREATE TABLE Roles
(
    RoleId      INT          AUTO_INCREMENT PRIMARY KEY,
    RoleName    VARCHAR(50)  NOT NULL,
    Description VARCHAR(255) NULL,
    CONSTRAINT UQ_Roles_RoleName UNIQUE (RoleName)
);

CREATE TABLE Users
(
    UserId          INT            AUTO_INCREMENT PRIMARY KEY,
    RoleId          INT            NOT NULL,
    Username        VARCHAR(50)    NOT NULL,
    Email           VARCHAR(256)   NOT NULL,
    PhoneNumber     VARCHAR(20)    NULL,
    PasswordHash    VARCHAR(255)   NOT NULL,
    PasswordSalt    VARCHAR(255)   NULL,
    FullName        VARCHAR(100)   NULL,
    IsEmailVerified TINYINT(1)     NOT NULL DEFAULT 0,
    IsActive        TINYINT(1)     NOT NULL DEFAULT 1,
    RegisteredAt    DATETIME       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    LastLoginAt     DATETIME       NULL,

    CONSTRAINT FK_Users_Roles FOREIGN KEY (RoleId) REFERENCES Roles(RoleId),
    CONSTRAINT UQ_Users_Username UNIQUE (Username),
    CONSTRAINT UQ_Users_Email    UNIQUE (Email)
);

/* 1.3 SỬA: thêm TargetWeightKg / ActivityLevel / MotivationCode
   và chặn cân nặng mục tiêu rơi xuống dưới ngưỡng thiếu cân. */
CREATE TABLE UserProfiles
(
    UserId          INT          NOT NULL PRIMARY KEY,
    DateOfBirth     DATE         NULL,
    Gender          VARCHAR(10)  NULL,
    HeightCm        DECIMAL(5,2) NULL,
    WeightKg        DECIMAL(5,2) NULL,
    TargetWeightKg  DECIMAL(5,2) NULL,            -- MỚI: câu 10 onboarding
    FitnessLevel    VARCHAR(20)  NULL,
    ActivityLevel   VARCHAR(20)  NULL,            -- MỚI: câu 6 onboarding
    MotivationCode  VARCHAR(40)  NULL,            -- MỚI: câu 3, chỉ dùng cho nội dung nhắc
    AvatarUrl       VARCHAR(500) NULL,
    Bio             VARCHAR(500) NULL,
    OnboardedAt     DATETIME     NULL,            -- MỚI
    UpdatedAt       DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    CONSTRAINT FK_UserProfiles_Users FOREIGN KEY (UserId) REFERENCES Users(UserId) ON DELETE CASCADE,
    CONSTRAINT CK_UserProfiles_Gender CHECK (Gender IN ('Male', 'Female', 'Other')),
    CONSTRAINT CK_UserProfiles_Level  CHECK (FitnessLevel IN ('Beginner', 'Intermediate', 'Advanced')),
    CONSTRAINT CK_UserProfiles_Activity CHECK (ActivityLevel IN
        ('Sedentary', 'LightActive', 'ModerateActive', 'VeryActive', 'ExtraActive')),
    CONSTRAINT CK_UserProfiles_Height CHECK (HeightCm IS NULL OR HeightCm BETWEEN 140 AND 220),
    CONSTRAINT CK_UserProfiles_Weight CHECK (WeightKg IS NULL OR WeightKg BETWEEN 35 AND 180),
    CONSTRAINT CK_UserProfiles_Target CHECK (TargetWeightKg IS NULL OR TargetWeightKg BETWEEN 35 AND 180),
    /* CHẶN AN TOÀN: không cho đặt mục tiêu dưới BMI 18.5.
       Nếu bản MySQL của bạn từ chối POW() trong CHECK thì bỏ ràng buộc này
       và chặn ở tầng API — nhưng đừng bỏ cả hai chỗ. */
    CONSTRAINT CK_UserProfiles_TargetBmi CHECK (
        TargetWeightKg IS NULL OR HeightCm IS NULL
        OR TargetWeightKg >= 18.5 * POW(HeightCm / 100, 2))
);

CREATE TABLE Devices
(
    DeviceId    INT          AUTO_INCREMENT PRIMARY KEY,
    UserId      INT          NOT NULL,
    DeviceName  VARCHAR(100) NULL,
    Platform    VARCHAR(20)  NULL,
    OsVersion   VARCHAR(30)  NULL,
    AppVersion  VARCHAR(30)  NULL,
    PushToken   VARCHAR(500) NULL,
    LastUsedAt  DATETIME     NULL,
    CreatedAt   DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT FK_Devices_Users FOREIGN KEY (UserId) REFERENCES Users(UserId) ON DELETE CASCADE,
    CONSTRAINT CK_Devices_Platform CHECK (Platform IN ('iOS', 'Android', 'Web'))
);

CREATE TABLE UserSettings
(
    UserId            INT         NOT NULL PRIMARY KEY,
    Language          VARCHAR(10) NOT NULL DEFAULT 'vi',
    VoiceFeedback     TINYINT(1)  NOT NULL DEFAULT 1,
    SoundFeedback     TINYINT(1)  NOT NULL DEFAULT 1,
    VibrationFeedback TINYINT(1)  NOT NULL DEFAULT 1,
    PrivacyMode       TINYINT(1)  NOT NULL DEFAULT 0,
    DailyReminderTime TIME        NULL,
    UpdatedAt         DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    CONSTRAINT FK_UserSettings_Users FOREIGN KEY (UserId) REFERENCES Users(UserId) ON DELETE CASCADE
);

/* =====================================================================
   1b. BẢNG DO BACKEND QUẢN LÝ   (MỚI trong file này — lấy từ model SQLAlchemy)
   Tên bảng/cột snake_case là do code đặt (app/models/*.py), KHÔNG đổi sang
   PascalCase. Cột và kiểu dữ liệu khớp đúng những gì SQLAlchemy sinh ra, nên
   create_tables.py / ensure_tables.py (checkfirst=True) sẽ nhận là đã có.
   Riêng DEFAULT là thêm vào để chèn tay bằng SQL cũng chạy được — ORM vẫn tự
   gửi giá trị như cũ.
   ===================================================================== */

-- Video buổi tập người dùng tải lên (app/models/video.py)
CREATE TABLE videos
(
    id                INT          NOT NULL AUTO_INCREMENT,
    user_id           INT          NOT NULL,
    exercise          VARCHAR(100) NOT NULL,
    file_path         VARCHAR(500) NOT NULL,
    original_filename VARCHAR(255) NULL,
    duration_seconds  FLOAT        NULL,
    total_reps        INT          NOT NULL DEFAULT 0,
    accuracy_score    FLOAT        NULL,
    analysis_summary  TEXT         NULL,
    created_at        DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    CONSTRAINT FK_videos_Users FOREIGN KEY (user_id) REFERENCES Users(UserId)
);
CREATE INDEX ix_videos_id      ON videos (id);
CREATE INDEX ix_videos_user_id ON videos (user_id);

-- Lịch sử buổi tập của phiên phân tích realtime (app/models/workout.py)
CREATE TABLE workouts
(
    id               INT          NOT NULL AUTO_INCREMENT,
    user_id          INT          NOT NULL,
    exercise         VARCHAR(100) NOT NULL,
    total_reps       INT          NOT NULL DEFAULT 0,
    duration_seconds FLOAT        NULL,
    accuracy_score   FLOAT        NULL,
    started_at       DATETIME     NOT NULL,
    ended_at         DATETIME     NULL,
    created_at       DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    CONSTRAINT FK_workouts_Users FOREIGN KEY (user_id) REFERENCES Users(UserId)
);
CREATE INDEX ix_workouts_id      ON workouts (id);
CREATE INDEX ix_workouts_user_id ON workouts (user_id);

-- Mã OTP xác thực email khi đăng ký (app/models/email_otp.py)
CREATE TABLE email_otps
(
    id         INT         NOT NULL AUTO_INCREMENT,
    user_id    INT         NOT NULL,
    code       VARCHAR(10) NOT NULL,
    expires_at DATETIME    NOT NULL,
    is_used    TINYINT(1)  NOT NULL DEFAULT 0,
    attempts   INT         NOT NULL DEFAULT 0,
    created_at DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    CONSTRAINT FK_email_otps_Users FOREIGN KEY (user_id) REFERENCES Users(UserId) ON DELETE CASCADE
);
CREATE INDEX ix_email_otps_id      ON email_otps (id);
CREATE INDEX ix_email_otps_user_id ON email_otps (user_id);

-- Token đặt lại mật khẩu, chỉ lưu SHA-256 (app/models/password_reset_token.py)
CREATE TABLE password_reset_tokens
(
    id         INT         NOT NULL AUTO_INCREMENT,
    user_id    INT         NOT NULL,
    token_hash VARCHAR(64) NOT NULL,
    expires_at DATETIME    NOT NULL,
    used       TINYINT(1)  NOT NULL DEFAULT 0,
    created_at DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    CONSTRAINT FK_password_reset_tokens_Users FOREIGN KEY (user_id) REFERENCES Users(UserId) ON DELETE CASCADE
);
CREATE INDEX        ix_password_reset_tokens_id         ON password_reset_tokens (id);
CREATE INDEX        ix_password_reset_tokens_user_id    ON password_reset_tokens (user_id);
CREATE UNIQUE INDEX ix_password_reset_tokens_token_hash ON password_reset_tokens (token_hash);

-- Token FCM cho push notification (app/models/device_token.py).
-- Lưu ý: bảng Devices (PushToken) của schema gốc hiện KHÔNG được code dùng —
-- push thật đi qua bảng này.
CREATE TABLE device_tokens
(
    id         INT          NOT NULL AUTO_INCREMENT,
    user_id    INT          NOT NULL,
    token      VARCHAR(255) NOT NULL,
    platform   VARCHAR(20)  NULL,
    created_at DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    CONSTRAINT FK_device_tokens_Users FOREIGN KEY (user_id) REFERENCES Users(UserId),
    CONSTRAINT UQ_device_tokens_token UNIQUE (token)
);
CREATE INDEX ix_device_tokens_user_id ON device_tokens (user_id);

-- Lịch sử hội thoại AI Coach, role = 'user' | 'model' (app/models/coach_message.py)
CREATE TABLE coach_messages
(
    id         INT         NOT NULL AUTO_INCREMENT,
    user_id    INT         NOT NULL,
    `role`     VARCHAR(10) NOT NULL,
    content    TEXT        NOT NULL,
    created_at DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    CONSTRAINT FK_coach_messages_Users FOREIGN KEY (user_id) REFERENCES Users(UserId)
);
CREATE INDEX ix_coach_messages_id         ON coach_messages (id);
CREATE INDEX ix_coach_messages_user_id    ON coach_messages (user_id);
CREATE INDEX ix_coach_messages_created_at ON coach_messages (created_at);

/* =====================================================================
   2. THƯ VIỆN BÀI TẬP & LUẬT TƯ THẾ
   ===================================================================== */

/* 2.0 MỚI — Vai trò vận động.
   Đây là bảng quan trọng nhất được thêm vào. Ô trong giáo án mẫu trỏ tới
   VAI TRÒ chứ không trỏ tới bài cụ thể, nên đổi bài chỉ là tìm bài khác
   cùng MovementRoleId. */
CREATE TABLE MovementRoles
(
    MovementRoleId INT         AUTO_INCREMENT PRIMARY KEY,
    Code           VARCHAR(40) NOT NULL,
    NameVi         VARCHAR(60) NOT NULL,
    NameEn         VARCHAR(60) NOT NULL,
    Category       VARCHAR(20) NOT NULL,

    CONSTRAINT UQ_MovementRoles_Code UNIQUE (Code),
    CONSTRAINT CK_MovementRoles_Category CHECK (Category IN
        ('Compound', 'Isolation', 'Core', 'Cardio', 'Mobility'))
);

CREATE TABLE MuscleGroups
(
    MuscleGroupId INT          AUTO_INCREMENT PRIMARY KEY,
    Name          VARCHAR(50)  NOT NULL,
    NameVi        VARCHAR(50)  NULL,              -- MỚI
    CONSTRAINT UQ_MuscleGroups_Name UNIQUE (Name)
);

/* 2.2 SỬA: thêm 7 cột và mở rộng CK_Exercises_Type */
CREATE TABLE Exercises
(
    ExerciseId     INT           AUTO_INCREMENT PRIMARY KEY,
    Slug           VARCHAR(80)   NOT NULL,        -- MỚI: tên file video, khoá tự nhiên (trigger tự sinh nếu app không gửi)
    Name           VARCHAR(100)  NOT NULL,
    NameVi         VARCHAR(120)  NULL,            -- MỚI
    Description    VARCHAR(1000) NULL,
    MovementRoleId INT           NULL,            -- MỚI: NULL cho bài cố ý loại khỏi pool
    Category       VARCHAR(50)   NULL,
    Difficulty     VARCHAR(20)   NULL,
    ExerciseType   VARCHAR(20)   NOT NULL DEFAULT 'Standard',
    EquipmentTier  VARCHAR(2)    NOT NULL DEFAULT 'T2',  -- MỚI: T0 / T1 / T2
    Impact         VARCHAR(10)   NULL,            -- MỚI: Low / High
    SpineLoad      VARCHAR(10)   NULL,            -- MỚI: None / Low / High — cột lọc đau lưng
    SupportsAnalysis TINYINT(1)  NOT NULL DEFAULT 0,  -- MỚI: camera chấm tư thế được không
    ExcludedReason VARCHAR(255)  NULL,            -- MỚI: vì sao không gán vai trò
    DemoVideoUrl   VARCHAR(500)  NULL,
    ThumbnailUrl   VARCHAR(500)  NULL,
    Met            DECIMAL(4,2)  NULL,
    IsActive       TINYINT(1)    NOT NULL DEFAULT 1,
    CreatedAt      DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT FK_Exercises_MovementRole FOREIGN KEY (MovementRoleId)
        REFERENCES MovementRoles(MovementRoleId),
    CONSTRAINT UQ_Exercises_Name UNIQUE (Name),
    CONSTRAINT UQ_Exercises_Slug UNIQUE (Slug),
    CONSTRAINT CK_Exercises_Difficulty CHECK (Difficulty IN ('Beginner', 'Intermediate', 'Advanced')),
    /* SỬA: bản gốc chỉ có Standard/Duration nên 44 bài cardio không gán được kiểu */
    CONSTRAINT CK_Exercises_Type CHECK (ExerciseType IN ('Standard', 'Duration', 'Cardio')),
    CONSTRAINT CK_Exercises_Tier CHECK (EquipmentTier IN ('T0', 'T1', 'T2')),
    CONSTRAINT CK_Exercises_Impact CHECK (Impact IS NULL OR Impact IN ('Low', 'High')),
    CONSTRAINT CK_Exercises_SpineLoad CHECK (SpineLoad IS NULL OR SpineLoad IN ('None', 'Low', 'High')),
    /* Bài không có vai trò thì bắt buộc ghi lý do, để không bị lọt vào pool thay thế một cách im lặng */
    CONSTRAINT CK_Exercises_RoleOrReason CHECK (MovementRoleId IS NOT NULL OR ExcludedReason IS NOT NULL)
);

/* 2.2b Trigger cho các INSERT từ backend (ORM không biết Slug/MovementRoleId).
   Viết một câu lệnh SET duy nhất, không cần BEGIN...END, để run_schema.py
   (chỉ xử lý được một khối DELIMITER) vẫn tách câu đúng. */
CREATE TRIGGER trg_Exercises_BeforeInsert
BEFORE INSERT ON Exercises
FOR EACH ROW
SET NEW.Slug = IFNULL(NEW.Slug, LEFT(LOWER(REPLACE(TRIM(NEW.Name), ' ', '-')), 80)),
    NEW.ExcludedReason = IF(NEW.MovementRoleId IS NULL AND NEW.ExcludedReason IS NULL,
                            'Tạo từ app/admin, chưa gán vai trò vận động',
                            NEW.ExcludedReason);

CREATE TABLE ExerciseMuscleGroups
(
    ExerciseId    INT        NOT NULL,
    MuscleGroupId INT        NOT NULL,
    IsPrimary     TINYINT(1) NOT NULL DEFAULT 0,

    CONSTRAINT PK_ExerciseMuscleGroups PRIMARY KEY (ExerciseId, MuscleGroupId),
    CONSTRAINT FK_ExMuscle_Exercise FOREIGN KEY (ExerciseId)    REFERENCES Exercises(ExerciseId)    ON DELETE CASCADE,
    CONSTRAINT FK_ExMuscle_Muscle   FOREIGN KEY (MuscleGroupId) REFERENCES MuscleGroups(MuscleGroupId) ON DELETE CASCADE
);

CREATE TABLE ExercisePostureRules
(
    RuleId       INT          AUTO_INCREMENT PRIMARY KEY,
    ExerciseId   INT          NOT NULL,
    RuleName     VARCHAR(80)  NOT NULL,
    JointA       VARCHAR(40)  NOT NULL,
    JointB       VARCHAR(40)  NOT NULL,
    JointC       VARCHAR(40)  NOT NULL,
    MinAngle     DECIMAL(5,2) NULL,
    MaxAngle     DECIMAL(5,2) NULL,
    TargetAngle  DECIMAL(5,2) NULL,
    IsRepTrigger TINYINT(1)   NOT NULL DEFAULT 0,
    Tolerance    DECIMAL(5,2) NULL,

    CONSTRAINT FK_PostureRules_Exercise FOREIGN KEY (ExerciseId) REFERENCES Exercises(ExerciseId) ON DELETE CASCADE
);

CREATE TABLE PostureErrorTypes
(
    ErrorTypeId   INT          AUTO_INCREMENT PRIMARY KEY,
    ExerciseId    INT          NULL,
    ErrorCode     VARCHAR(50)  NOT NULL,
    ErrorName     VARCHAR(150) NOT NULL,
    Severity      VARCHAR(20)  NOT NULL DEFAULT 'Medium',
    CorrectionTip VARCHAR(500) NULL,
    VoicePrompt   VARCHAR(255) NULL,

    CONSTRAINT FK_ErrorTypes_Exercise FOREIGN KEY (ExerciseId) REFERENCES Exercises(ExerciseId),
    CONSTRAINT UQ_ErrorTypes_Code UNIQUE (ErrorCode),
    CONSTRAINT CK_ErrorTypes_Severity CHECK (Severity IN ('Low', 'Medium', 'High'))
);

/* =====================================================================
   3. ONBOARDING — 14 CÂU HỎI VÀ LỰA CHỌN   (toàn bộ MỚI)
   ===================================================================== */

-- 3.1 Câu 1: 12 mục tiêu. Tên bảng có tiền tố Onboarding vì bản gốc
--     đã dùng `Goals` cho mục tiêu cá nhân (GoalType/TargetValue).
CREATE TABLE OnboardingGoals
(
    GoalCode VARCHAR(30) NOT NULL PRIMARY KEY,
    Label    VARCHAR(60) NOT NULL
);

-- 3.2 Bảng chấm điểm: mỗi mục tiêu cộng bao nhiêu điểm cho mỗi hướng giáo án.
--     Để trong DB nên chỉnh điểm không cần deploy lại backend.
CREATE TABLE GoalDirectionScores
(
    GoalCode  VARCHAR(30) NOT NULL,
    Direction VARCHAR(20) NOT NULL,
    Score     TINYINT     NOT NULL DEFAULT 0,

    CONSTRAINT PK_GoalDirectionScores PRIMARY KEY (GoalCode, Direction),
    CONSTRAINT FK_GDS_Goal FOREIGN KEY (GoalCode) REFERENCES OnboardingGoals(GoalCode) ON DELETE CASCADE,
    CONSTRAINT CK_GDS_Direction CHECK (Direction IN ('BuildMuscle', 'LoseFat', 'StayFit', 'Endurance'))
);

-- 3.3 Câu 12: dụng cụ. Chọn nhiều thì lấy Tier cao nhất.
CREATE TABLE EquipmentOptions
(
    EquipmentCode VARCHAR(30) NOT NULL PRIMARY KEY,
    Label         VARCHAR(60) NOT NULL,
    Tier          VARCHAR(2)  NOT NULL,
    CONSTRAINT CK_EquipmentOptions_Tier CHECK (Tier IN ('T0', 'T1', 'T2'))
);

-- 3.4 Câu 4: vùng quan tâm
CREATE TABLE FocusAreas
(
    AreaCode VARCHAR(20) NOT NULL PRIMARY KEY,
    Label    VARCHAR(40) NOT NULL
);

CREATE TABLE FocusAreaAccessories
(
    AreaCode   VARCHAR(20) NOT NULL,
    ExerciseId INT         NOT NULL,

    CONSTRAINT PK_FocusAreaAccessories PRIMARY KEY (AreaCode, ExerciseId),
    CONSTRAINT FK_FAA_Area     FOREIGN KEY (AreaCode)   REFERENCES FocusAreas(AreaCode) ON DELETE CASCADE,
    CONSTRAINT FK_FAA_Exercise FOREIGN KEY (ExerciseId) REFERENCES Exercises(ExerciseId)
);

-- 3.5 Câu 11: vấn đề sức khoẻ
CREATE TABLE HealthIssues
(
    IssueCode         VARCHAR(30)  NOT NULL PRIMARY KEY,
    LabelVi           VARCHAR(80)  NOT NULL,
    ExtraConstraint   VARCHAR(255) NULL,
    ForceBeginnerPool TINYINT(1)   NOT NULL DEFAULT 0
);

/* Bài bị cấm. QUYỀN PHỦ QUYẾT: đã nằm ở đây thì không bao giờ được đưa lại,
   dù mục tiêu hay trình độ của user có đòi hỏi. */
CREATE TABLE HealthIssueExclusions
(
    IssueCode  VARCHAR(30) NOT NULL,
    ExerciseId INT         NOT NULL,

    CONSTRAINT PK_HealthIssueExclusions PRIMARY KEY (IssueCode, ExerciseId),
    CONSTRAINT FK_HIE_Issue    FOREIGN KEY (IssueCode)  REFERENCES HealthIssues(IssueCode) ON DELETE CASCADE,
    CONSTRAINT FK_HIE_Exercise FOREIGN KEY (ExerciseId) REFERENCES Exercises(ExerciseId)
);

CREATE TABLE HealthIssueReplacements
(
    IssueCode  VARCHAR(30) NOT NULL,
    ExerciseId INT         NOT NULL,

    CONSTRAINT PK_HealthIssueReplacements PRIMARY KEY (IssueCode, ExerciseId),
    CONSTRAINT FK_HIR_Issue    FOREIGN KEY (IssueCode)  REFERENCES HealthIssues(IssueCode) ON DELETE CASCADE,
    CONSTRAINT FK_HIR_Exercise FOREIGN KEY (ExerciseId) REFERENCES Exercises(ExerciseId)
);

-- 3.6 Hệ số khối lượng theo chỉ số cơ thể / tuổi / mức vận động.
--     Gộp ba chiều vào một bảng vì đều chỉ là một phép nhân.
CREATE TABLE VolumeModifiers
(
    ModifierId     INT          AUTO_INCREMENT PRIMARY KEY,
    Dimension      VARCHAR(10)  NOT NULL,
    `MinValue`     DECIMAL(6,2) NULL,         -- backtick: MAXVALUE là từ khoá của MySQL
    `MaxValue`     DECIMAL(6,2) NULL,
    EnumValue      VARCHAR(20)  NULL,
    Multiplier     DECIMAL(3,2) NOT NULL DEFAULT 1.00,
    RampWeeks      TINYINT      NOT NULL DEFAULT 0,
    AdjustmentNote VARCHAR(255) NULL,

    CONSTRAINT CK_VolumeModifiers_Dimension CHECK (Dimension IN ('Bmi', 'Age', 'Activity')),
    CONSTRAINT CK_VolumeModifiers_Range CHECK (
        (Dimension = 'Activity' AND EnumValue IS NOT NULL)
        OR (Dimension <> 'Activity' AND (`MinValue` IS NOT NULL OR `MaxValue` IS NOT NULL)))
);

-- 3.7 Câu 2: giới tính CHỈ đổi mức tạ khởi điểm gợi ý, không đổi bài hay set/rep.
CREATE TABLE StartingLoadHints
(
    ExerciseId INT         NOT NULL,
    Gender     VARCHAR(10) NOT NULL,
    LoadRange  VARCHAR(40) NOT NULL,

    CONSTRAINT PK_StartingLoadHints PRIMARY KEY (ExerciseId, Gender),
    CONSTRAINT FK_SLH_Exercise FOREIGN KEY (ExerciseId) REFERENCES Exercises(ExerciseId) ON DELETE CASCADE,
    CONSTRAINT CK_SLH_Gender CHECK (Gender IN ('Male', 'Female'))
);

/* =====================================================================
   4. CÂU TRẢ LỜI CỦA NGƯỜI DÙNG   (toàn bộ MỚI)
   ===================================================================== */

CREATE TABLE UserGoals
(
    UserId   INT         NOT NULL,
    GoalCode VARCHAR(30) NOT NULL,

    CONSTRAINT PK_UserGoals PRIMARY KEY (UserId, GoalCode),
    CONSTRAINT FK_UserGoals_User FOREIGN KEY (UserId)   REFERENCES Users(UserId) ON DELETE CASCADE,
    CONSTRAINT FK_UserGoals_Goal FOREIGN KEY (GoalCode) REFERENCES OnboardingGoals(GoalCode)
);

CREATE TABLE UserFocusAreas
(
    UserId   INT         NOT NULL,
    AreaCode VARCHAR(20) NOT NULL,

    CONSTRAINT PK_UserFocusAreas PRIMARY KEY (UserId, AreaCode),
    CONSTRAINT FK_UFA_User FOREIGN KEY (UserId)   REFERENCES Users(UserId) ON DELETE CASCADE,
    CONSTRAINT FK_UFA_Area FOREIGN KEY (AreaCode) REFERENCES FocusAreas(AreaCode)
);

CREATE TABLE UserHealthIssues
(
    UserId    INT         NOT NULL,
    IssueCode VARCHAR(30) NOT NULL,

    CONSTRAINT PK_UserHealthIssues PRIMARY KEY (UserId, IssueCode),
    CONSTRAINT FK_UHI_User  FOREIGN KEY (UserId)    REFERENCES Users(UserId) ON DELETE CASCADE,
    CONSTRAINT FK_UHI_Issue FOREIGN KEY (IssueCode) REFERENCES HealthIssues(IssueCode)
);

CREATE TABLE UserEquipment
(
    UserId        INT         NOT NULL,
    EquipmentCode VARCHAR(30) NOT NULL,

    CONSTRAINT PK_UserEquipment PRIMARY KEY (UserId, EquipmentCode),
    CONSTRAINT FK_UEq_User      FOREIGN KEY (UserId)        REFERENCES Users(UserId) ON DELETE CASCADE,
    CONSTRAINT FK_UEq_Equipment FOREIGN KEY (EquipmentCode) REFERENCES EquipmentOptions(EquipmentCode)
);

/* =====================================================================
   5. GIÁO ÁN MẪU   (toàn bộ MỚI)
   Admin seed một lần. Người dùng không bao giờ ghi vào mấy bảng này.
   ===================================================================== */

CREATE TABLE ProgramTemplates
(
    ProgramCode     CHAR(3)       NOT NULL PRIMARY KEY,   -- P01..P08
    Direction       VARCHAR(20)   NOT NULL,
    SessionsPerWeek TINYINT       NOT NULL,
    SplitName       VARCHAR(60)   NOT NULL,
    MinLevel        VARCHAR(20)   NOT NULL,
    Description     VARCHAR(1000) NULL,
    IsActive        TINYINT(1)    NOT NULL DEFAULT 1,

    CONSTRAINT CK_ProgramTemplates_Direction CHECK (Direction IN ('BuildMuscle', 'LoseFat', 'StayFit', 'Endurance')),
    CONSTRAINT CK_ProgramTemplates_Level     CHECK (MinLevel IN ('Beginner', 'Intermediate', 'Advanced')),
    CONSTRAINT CK_ProgramTemplates_Spw       CHECK (SessionsPerWeek BETWEEN 1 AND 7)
);

CREATE TABLE TemplateSessions
(
    TemplateSessionId INT          AUTO_INCREMENT PRIMARY KEY,
    ProgramCode       CHAR(3)      NOT NULL,
    SessionNo         TINYINT      NOT NULL,
    SessionName       VARCHAR(60)  NOT NULL,
    Focus             VARCHAR(120) NULL,
    EstMinutes        TINYINT      NULL,

    CONSTRAINT FK_TS_Program FOREIGN KEY (ProgramCode) REFERENCES ProgramTemplates(ProgramCode) ON DELETE CASCADE,
    CONSTRAINT UQ_TS_SessionNo UNIQUE (ProgramCode, SessionNo)
);

/* 5.3 Ô bài tập — BẢNG LÕI CỦA TOÀN BỘ THIẾT KẾ.
   MovementRoleId nói ô này cần loại vận động gì; bài cụ thể chỉ được chốt
   khi sinh giáo án cho user, dựa trên dụng cụ họ có và bộ lọc sức khoẻ. */
CREATE TABLE TemplateSlots
(
    SlotId            INT          AUTO_INCREMENT PRIMARY KEY,
    TemplateSessionId INT          NOT NULL,
    SlotNo            TINYINT      NOT NULL,
    MovementRoleId    INT          NOT NULL,
    SlotLabel         VARCHAR(60)  NULL,
    BaseSets          TINYINT      NOT NULL,
    RepScheme         VARCHAR(30)  NOT NULL,
    RestSeconds       SMALLINT     NOT NULL,      -- 0 = nối thẳng sang ô sau (superset)
    SupersetGroup     TINYINT      NULL,
    T0Warning         VARCHAR(255) NULL,          -- khi bản T0 phải mượn vai trò khác
    Note              VARCHAR(255) NULL,

    CONSTRAINT FK_Slots_Session FOREIGN KEY (TemplateSessionId) REFERENCES TemplateSessions(TemplateSessionId) ON DELETE CASCADE,
    CONSTRAINT FK_Slots_Role    FOREIGN KEY (MovementRoleId)    REFERENCES MovementRoles(MovementRoleId),
    CONSTRAINT UQ_Slots_SlotNo UNIQUE (TemplateSessionId, SlotNo),
    CONSTRAINT CK_Slots_BaseSets CHECK (BaseSets BETWEEN 1 AND 6)
);

-- 5.4 Bài mặc định của mỗi ô, một dòng cho mỗi mức dụng cụ
CREATE TABLE SlotDefaultExercises
(
    SlotId        INT        NOT NULL,
    EquipmentTier VARCHAR(2) NOT NULL,
    ExerciseId    INT        NOT NULL,

    CONSTRAINT PK_SlotDefaultExercises PRIMARY KEY (SlotId, EquipmentTier),
    CONSTRAINT FK_SDE_Slot     FOREIGN KEY (SlotId)     REFERENCES TemplateSlots(SlotId) ON DELETE CASCADE,
    CONSTRAINT FK_SDE_Exercise FOREIGN KEY (ExerciseId) REFERENCES Exercises(ExerciseId),
    CONSTRAINT CK_SDE_Tier CHECK (EquipmentTier IN ('T0', 'T1', 'T2'))
);

-- 5.5 Lộ trình 4 tuần
CREATE TABLE TemplateProgression
(
    ProgramCode         CHAR(3)       NOT NULL,
    WeekNo              TINYINT       NOT NULL,
    VolumePct           VARCHAR(12)   NOT NULL,
    SetsMain            VARCHAR(12)   NOT NULL,
    SetsAccessory       VARCHAR(12)   NOT NULL,
    LoadRule            VARCHAR(80)   NOT NULL,
    CardioPrescription  VARCHAR(120)  NULL,
    Instruction         VARCHAR(1000) NULL,

    CONSTRAINT PK_TemplateProgression PRIMARY KEY (ProgramCode, WeekNo),
    CONSTRAINT FK_TP_Program FOREIGN KEY (ProgramCode) REFERENCES ProgramTemplates(ProgramCode) ON DELETE CASCADE,
    CONSTRAINT CK_TP_WeekNo CHECK (WeekNo BETWEEN 1 AND 4)
);

/* =====================================================================
   6. GIÁO ÁN THỰC TẾ CỦA NGƯỜI DÙNG
   WorkoutPlans của bản gốc được giữ lại nhưng đổi vai trò: từ "plan tự tạo"
   thành "giáo án sinh từ ProgramTemplates".
   ===================================================================== */

/* 6.1 SỬA: thêm 6 cột nối về giáo án mẫu và lưu tham số đã chốt */
CREATE TABLE WorkoutPlans
(
    PlanId           INT           AUTO_INCREMENT PRIMARY KEY,
    UserId           INT           NULL,
    ProgramCode      CHAR(3)       NULL,          -- MỚI: sinh từ mẫu nào
    Name             VARCHAR(120)  NOT NULL,
    Description      VARCHAR(1000) NULL,
    Goal             VARCHAR(50)   NULL,
    EquipmentTier    VARCHAR(2)    NULL,          -- MỚI: mức dụng cụ đã chốt
    VolumeMultiplier DECIMAL(3,2)  NOT NULL DEFAULT 1.00,  -- MỚI
    CurrentWeek      TINYINT       NOT NULL DEFAULT 1,     -- MỚI
    Status           VARCHAR(20)   NOT NULL DEFAULT 'Active',  -- MỚI
    DurationDays     INT           NULL,
    IsSystemPlan     TINYINT(1)    NOT NULL DEFAULT 0,
    StartDate        DATE          NULL,          -- MỚI
    GeneratedAt      DATETIME      NULL,          -- MỚI: mốc chụp lại tham số
    CreatedAt        DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT FK_WorkoutPlans_Users   FOREIGN KEY (UserId)      REFERENCES Users(UserId),
    CONSTRAINT FK_WorkoutPlans_Program FOREIGN KEY (ProgramCode) REFERENCES ProgramTemplates(ProgramCode),
    CONSTRAINT CK_WorkoutPlans_Status CHECK (Status IN ('Active', 'Completed', 'Abandoned')),
    CONSTRAINT CK_WorkoutPlans_Tier   CHECK (EquipmentTier IS NULL OR EquipmentTier IN ('T0', 'T1', 'T2')),
    CONSTRAINT CK_WorkoutPlans_Week   CHECK (CurrentWeek BETWEEN 1 AND 4),
    CONSTRAINT CK_WorkoutPlans_Mult   CHECK (VolumeMultiplier BETWEEN 0.50 AND 1.30)
);

-- 6.2 MỚI: ngày tập trong tuần (câu 14 onboarding)
CREATE TABLE PlanWorkoutDays
(
    PlanId          INT        NOT NULL,
    DayOfWeek       TINYINT    NOT NULL,          -- 1 Thứ Hai .. 7 Chủ Nhật
    ReminderEnabled TINYINT(1) NOT NULL DEFAULT 1,

    CONSTRAINT PK_PlanWorkoutDays PRIMARY KEY (PlanId, DayOfWeek),
    CONSTRAINT FK_PWD_Plan FOREIGN KEY (PlanId) REFERENCES WorkoutPlans(PlanId) ON DELETE CASCADE,
    CONSTRAINT CK_PWD_DayOfWeek CHECK (DayOfWeek BETWEEN 1 AND 7)
);

/* 6.3 MỚI: lịch buổi tập đã lên kế hoạch.
   Bản gốc thiếu khái niệm này — chỉ có plan (tĩnh) và session (đã tập xong),
   không có chỗ nào chứa "buổi thứ 3 của tuần 2, dự kiến thứ Sáu". */
CREATE TABLE PlanScheduledSessions
(
    ScheduledSessionId INT      AUTO_INCREMENT PRIMARY KEY,
    PlanId             INT      NOT NULL,
    TemplateSessionId  INT      NOT NULL,
    WeekNo             TINYINT  NOT NULL,
    ScheduledDate      DATE     NOT NULL,
    Status             VARCHAR(20) NOT NULL DEFAULT 'Planned',

    CONSTRAINT FK_PSS_Plan     FOREIGN KEY (PlanId)            REFERENCES WorkoutPlans(PlanId) ON DELETE CASCADE,
    CONSTRAINT FK_PSS_Template FOREIGN KEY (TemplateSessionId) REFERENCES TemplateSessions(TemplateSessionId),
    CONSTRAINT CK_PSS_Status CHECK (Status IN ('Planned', 'Done', 'Skipped')),
    CONSTRAINT CK_PSS_WeekNo CHECK (WeekNo BETWEEN 1 AND 4)
);

/* 6.4 SỬA: thêm SlotId, WeekNo và hai cột lưu vết thay bài.
   Đây là nơi bài tập được CHỐT LẠI. Không join ngược lên SlotDefaultExercises
   khi đọc, để sau này sửa giáo án mẫu không làm đổi giáo án đang chạy. */
CREATE TABLE WorkoutPlanExercises
(
    PlanExerciseId           INT         AUTO_INCREMENT PRIMARY KEY,
    PlanId                   INT         NOT NULL,
    ScheduledSessionId       INT         NULL,     -- MỚI
    SlotId                   INT         NULL,     -- MỚI: lấp ô nào trong mẫu
    ExerciseId               INT         NOT NULL,
    SubstitutedFromExerciseId INT        NULL,     -- MỚI: bài gốc trước khi bị thay
    SubstitutionReason       VARCHAR(20) NULL,     -- MỚI
    WeekNo                   TINYINT     NULL,     -- MỚI
    DayNumber                INT         NULL,
    OrderIndex               INT         NULL,
    TargetSets               INT         NULL,
    TargetReps               INT         NULL,
    TargetRepsText           VARCHAR(30) NULL,     -- MỚI: '12 mỗi bên', '30 giây'
    TargetDurationSec        INT         NULL,
    RestSeconds              INT         NULL,
    IsAccessory              TINYINT(1)  NOT NULL DEFAULT 0,  -- MỚI

    CONSTRAINT FK_PlanExercises_Plan      FOREIGN KEY (PlanId)     REFERENCES WorkoutPlans(PlanId) ON DELETE CASCADE,
    CONSTRAINT FK_PlanExercises_Scheduled FOREIGN KEY (ScheduledSessionId) REFERENCES PlanScheduledSessions(ScheduledSessionId) ON DELETE CASCADE,
    CONSTRAINT FK_PlanExercises_Slot      FOREIGN KEY (SlotId)     REFERENCES TemplateSlots(SlotId),
    CONSTRAINT FK_PlanExercises_Exercise  FOREIGN KEY (ExerciseId) REFERENCES Exercises(ExerciseId),
    /* Khoá ngoại THỨ HAI cùng trỏ Exercises — nhớ đặt alias khác nhau khi JOIN */
    CONSTRAINT FK_PlanExercises_SubFrom   FOREIGN KEY (SubstitutedFromExerciseId) REFERENCES Exercises(ExerciseId),
    CONSTRAINT CK_PlanExercises_SubReason CHECK (
        (SubstitutedFromExerciseId IS NULL AND SubstitutionReason IS NULL)
        OR (SubstitutedFromExerciseId IS NOT NULL AND SubstitutionReason IS NOT NULL)),
    CONSTRAINT CK_PlanExercises_Reason CHECK (SubstitutionReason IS NULL OR SubstitutionReason IN
        ('HealthFilter', 'Equipment', 'UserChoice'))
);

/* =====================================================================
   7. BUỔI TẬP & DỮ LIỆU THỜI GIAN THỰC   (giữ nguyên, thêm 2 khoá ngoại)
   ===================================================================== */

CREATE TABLE WorkoutSessions
(
    SessionId          INT          AUTO_INCREMENT PRIMARY KEY,
    UserId             INT          NOT NULL,
    PlanId             INT          NULL,
    ScheduledSessionId INT          NULL,        -- MỚI: buổi này thực hiện lịch nào
    DeviceId           INT          NULL,
    StartedAt          DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    EndedAt            DATETIME     NULL,
    Status             VARCHAR(20)  NOT NULL DEFAULT 'InProgress',
    TotalDurationSec   INT          NULL,
    CaloriesBurned     DECIMAL(7,2) NULL,
    OverallFormScore   DECIMAL(5,2) NULL,
    Notes              VARCHAR(500) NULL,

    CONSTRAINT FK_WorkoutSessions_Users     FOREIGN KEY (UserId)   REFERENCES Users(UserId) ON DELETE CASCADE,
    CONSTRAINT FK_WorkoutSessions_Plans     FOREIGN KEY (PlanId)   REFERENCES WorkoutPlans(PlanId),
    CONSTRAINT FK_WorkoutSessions_Scheduled FOREIGN KEY (ScheduledSessionId) REFERENCES PlanScheduledSessions(ScheduledSessionId),
    CONSTRAINT FK_WorkoutSessions_Devices   FOREIGN KEY (DeviceId) REFERENCES Devices(DeviceId),
    CONSTRAINT CK_Sessions_Status    CHECK (Status IN ('InProgress', 'Completed', 'Discarded')),
    CONSTRAINT CK_Sessions_FormScore CHECK (OverallFormScore BETWEEN 0 AND 100)
);

CREATE TABLE SessionExercises
(
    SessionExerciseId INT          AUTO_INCREMENT PRIMARY KEY,
    SessionId         INT          NOT NULL,
    ExerciseId        INT          NOT NULL,
    PlanExerciseId    INT          NULL,          -- MỚI: nối thực tế về kế hoạch
    OrderIndex        INT          NULL,
    TotalReps         INT          NOT NULL DEFAULT 0,
    CleanReps         INT          NOT NULL DEFAULT 0,
    DurationSec       INT          NULL,
    FormScore         DECIMAL(5,2) NULL,
    WeightKg          DECIMAL(6,2) NULL,

    CONSTRAINT FK_SessionEx_Session  FOREIGN KEY (SessionId)      REFERENCES WorkoutSessions(SessionId) ON DELETE CASCADE,
    CONSTRAINT FK_SessionEx_Exercise FOREIGN KEY (ExerciseId)     REFERENCES Exercises(ExerciseId),
    CONSTRAINT FK_SessionEx_PlanEx   FOREIGN KEY (PlanExerciseId) REFERENCES WorkoutPlanExercises(PlanExerciseId),
    CONSTRAINT CK_SessionEx_FormScore CHECK (FormScore BETWEEN 0 AND 100)
);

CREATE TABLE SessionReps
(
    RepId             BIGINT       AUTO_INCREMENT PRIMARY KEY,
    SessionExerciseId INT          NOT NULL,
    RepNumber         INT          NOT NULL,
    IsClean           TINYINT(1)   NOT NULL DEFAULT 1,
    FormScore         DECIMAL(5,2) NULL,
    PeakAngle         DECIMAL(5,2) NULL,
    RangeOfMotion     DECIMAL(5,2) NULL,
    TempoSec          DECIMAL(5,2) NULL,
    RecordedAt        DATETIME(3)  NOT NULL DEFAULT CURRENT_TIMESTAMP(3),

    CONSTRAINT FK_Reps_SessionExercise FOREIGN KEY (SessionExerciseId) REFERENCES SessionExercises(SessionExerciseId) ON DELETE CASCADE,
    CONSTRAINT CK_Reps_FormScore CHECK (FormScore BETWEEN 0 AND 100)
);

CREATE TABLE RealtimeFeedback
(
    FeedbackId        BIGINT       AUTO_INCREMENT PRIMARY KEY,
    SessionExerciseId INT          NOT NULL,
    RepId             BIGINT       NULL,
    ErrorTypeId       INT          NULL,
    OccurredAt        DATETIME(3)  NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    ElapsedMs         INT          NULL,
    FeedbackType      VARCHAR(20)  NOT NULL DEFAULT 'Error',
    MeasuredAngle     DECIMAL(5,2) NULL,
    DeviationDegrees  DECIMAL(5,2) NULL,
    Channel           VARCHAR(20)  NULL,
    Message           VARCHAR(500) NULL,

    CONSTRAINT FK_Feedback_SessionExercise FOREIGN KEY (SessionExerciseId) REFERENCES SessionExercises(SessionExerciseId) ON DELETE CASCADE,
    CONSTRAINT FK_Feedback_Rep       FOREIGN KEY (RepId)       REFERENCES SessionReps(RepId),
    CONSTRAINT FK_Feedback_ErrorType FOREIGN KEY (ErrorTypeId) REFERENCES PostureErrorTypes(ErrorTypeId),
    CONSTRAINT CK_Feedback_Type CHECK (FeedbackType IN ('Error', 'Warning', 'Correction', 'Praise'))
);

/* =====================================================================
   8. TIẾN BỘ, MỤC TIÊU CÁ NHÂN, THÀNH TÍCH   (giữ nguyên bản gốc)
   Lưu ý: bảng Goals ở đây là MỤC TIÊU CÁ NHÂN của user (số buổi/tuần,
   điểm form...), khác hoàn toàn với OnboardingGoals ở mục 3.
   ===================================================================== */

CREATE TABLE Goals
(
    GoalId       INT           AUTO_INCREMENT PRIMARY KEY,
    UserId       INT           NOT NULL,
    GoalType     VARCHAR(40)   NOT NULL,
    TargetValue  DECIMAL(10,2) NOT NULL,
    CurrentValue DECIMAL(10,2) NOT NULL DEFAULT 0,
    StartDate    DATE          NOT NULL,
    EndDate      DATE          NULL,
    IsAchieved   TINYINT(1)    NOT NULL DEFAULT 0,

    CONSTRAINT FK_Goals_Users FOREIGN KEY (UserId) REFERENCES Users(UserId) ON DELETE CASCADE
);

CREATE TABLE Achievements
(
    AchievementId INT          AUTO_INCREMENT PRIMARY KEY,
    Code          VARCHAR(50)  NOT NULL,
    Name          VARCHAR(120) NOT NULL,
    Description   VARCHAR(500) NULL,
    IconUrl       VARCHAR(500) NULL,
    CONSTRAINT UQ_Achievements_Code UNIQUE (Code)
);

CREATE TABLE UserAchievements
(
    UserId        INT      NOT NULL,
    AchievementId INT      NOT NULL,
    AchievedAt    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT PK_UserAchievements PRIMARY KEY (UserId, AchievementId),
    CONSTRAINT FK_UserAch_Users        FOREIGN KEY (UserId)        REFERENCES Users(UserId) ON DELETE CASCADE,
    CONSTRAINT FK_UserAch_Achievements FOREIGN KEY (AchievementId) REFERENCES Achievements(AchievementId) ON DELETE CASCADE
);

CREATE TABLE BodyMeasurements
(
    MeasurementId INT          AUTO_INCREMENT PRIMARY KEY,
    UserId        INT          NOT NULL,
    MeasuredAt    DATE         NOT NULL,
    WeightKg      DECIMAL(5,2) NULL,
    BodyFatPct    DECIMAL(4,1) NULL,
    ChestCm       DECIMAL(5,2) NULL,
    WaistCm       DECIMAL(5,2) NULL,
    HipsCm        DECIMAL(5,2) NULL,
    PhotoUrl      VARCHAR(500) NULL,

    CONSTRAINT FK_Body_Users FOREIGN KEY (UserId) REFERENCES Users(UserId) ON DELETE CASCADE
);

/* =====================================================================
   9. GÓI DỊCH VỤ, THANH TOÁN, THÔNG BÁO   (giữ nguyên bản gốc)
   ===================================================================== */

CREATE TABLE SubscriptionPlans
(
    SubscriptionPlanId INT           AUTO_INCREMENT PRIMARY KEY,
    Name               VARCHAR(50)   NOT NULL,
    PriceMonthly       DECIMAL(10,2) NOT NULL DEFAULT 0,
    Currency           VARCHAR(10)   NOT NULL DEFAULT 'VND',
    Features           VARCHAR(1000) NULL,
    IsActive           TINYINT(1)    NOT NULL DEFAULT 1,
    CONSTRAINT UQ_SubPlan_Name UNIQUE (Name)
);

CREATE TABLE UserSubscriptions
(
    UserSubscriptionId INT         AUTO_INCREMENT PRIMARY KEY,
    UserId             INT         NOT NULL,
    SubscriptionPlanId INT         NOT NULL,
    StartDate          DATE        NOT NULL,
    EndDate            DATE        NULL,
    Status             VARCHAR(20) NOT NULL DEFAULT 'Active',
    AutoRenew          TINYINT(1)  NOT NULL DEFAULT 0,

    CONSTRAINT FK_UserSub_Users FOREIGN KEY (UserId)             REFERENCES Users(UserId) ON DELETE CASCADE,
    CONSTRAINT FK_UserSub_Plan  FOREIGN KEY (SubscriptionPlanId) REFERENCES SubscriptionPlans(SubscriptionPlanId),
    CONSTRAINT CK_UserSub_Status CHECK (Status IN ('Active', 'Expired', 'Cancelled'))
);

CREATE TABLE Payments
(
    PaymentId          INT           AUTO_INCREMENT PRIMARY KEY,
    UserSubscriptionId INT           NOT NULL,
    TransactionNo      VARCHAR(100)  NULL,
    Amount             DECIMAL(10,2) NOT NULL,
    Currency           VARCHAR(10)   NOT NULL DEFAULT 'VND',
    PaymentMethod      VARCHAR(50)   NOT NULL,
    Status             VARCHAR(20)   NOT NULL DEFAULT 'Pending',
    PaymentGatewayLog  TEXT          NULL,
    PaidAt             DATETIME      NULL,
    CreatedAt          DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT FK_Payments_UserSubscriptions FOREIGN KEY (UserSubscriptionId)
        REFERENCES UserSubscriptions(UserSubscriptionId) ON DELETE CASCADE,
    CONSTRAINT CK_Payments_Status CHECK (Status IN ('Pending', 'Completed', 'Failed', 'Refunded'))
);

CREATE TABLE Notifications
(
    NotificationId BIGINT       AUTO_INCREMENT PRIMARY KEY,
    UserId         INT          NOT NULL,
    Title          VARCHAR(150) NOT NULL,
    Body           VARCHAR(500) NULL,
    Type           VARCHAR(30)  NULL,
    IsRead         TINYINT(1)   NOT NULL DEFAULT 0,
    CreatedAt      DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT FK_Notif_Users FOREIGN KEY (UserId) REFERENCES Users(UserId) ON DELETE CASCADE
);

CREATE TABLE AuditLogs
(
    AuditLogId BIGINT        AUTO_INCREMENT PRIMARY KEY,
    UserId     INT           NULL,
    Action     VARCHAR(100)  NOT NULL,
    EntityName VARCHAR(100)  NULL,
    EntityId   VARCHAR(50)   NULL,
    Details    VARCHAR(1000) NULL,
    CreatedAt  DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT FK_Audit_Users FOREIGN KEY (UserId) REFERENCES Users(UserId)
);

/* =====================================================================
   10. TRỢ LÝ AI   (toàn bộ MỚI)
   ===================================================================== */

CREATE TABLE AiQaPairs
(
    QaId        INT          AUTO_INCREMENT PRIMARY KEY,
    Category    VARCHAR(40)  NOT NULL,
    Question    VARCHAR(500) NOT NULL,
    Answer      TEXT         NOT NULL,
    SourceTable VARCHAR(50)  NULL
    /* Nếu làm RAG: thêm cột Embedding VECTOR(768) trên MySQL 9,
       hoặc đẩy sang vector DB riêng. */
);

/* AI phải tuân thủ tuyệt đối. IsBlocking = 1 nghĩa là chặn cứng. */
CREATE TABLE AiSafetyRules
(
    SafetyRuleId      INT         AUTO_INCREMENT PRIMARY KEY,
    RuleType          VARCHAR(40) NOT NULL,
    Situation         TEXT        NOT NULL,
    RequiredBehaviour TEXT        NOT NULL,
    IsBlocking        TINYINT(1)  NOT NULL DEFAULT 1
);

/* =====================================================================
   11. CHỈ MỤC
   ===================================================================== */
CREATE INDEX IX_Users_RoleId              ON Users(RoleId);
CREATE INDEX IX_Exercises_RoleTier        ON Exercises(MovementRoleId, EquipmentTier, IsActive);
CREATE INDEX IX_Exercises_Filter          ON Exercises(SpineLoad, Impact, Difficulty);
CREATE INDEX IX_Slots_Role                ON TemplateSlots(MovementRoleId);
CREATE INDEX IX_SDE_Exercise              ON SlotDefaultExercises(ExerciseId);
CREATE INDEX IX_HIE_Exercise              ON HealthIssueExclusions(ExerciseId);
CREATE INDEX IX_Plans_UserStatus          ON WorkoutPlans(UserId, Status);
CREATE INDEX IX_PSS_Calendar              ON PlanScheduledSessions(PlanId, ScheduledDate);
CREATE INDEX IX_PSS_Status                ON PlanScheduledSessions(Status, ScheduledDate);
CREATE INDEX IX_PlanEx_Scheduled          ON WorkoutPlanExercises(ScheduledSessionId, OrderIndex);
CREATE INDEX IX_PlanEx_Exercise           ON WorkoutPlanExercises(ExerciseId);
CREATE INDEX IX_Sessions_UserId           ON WorkoutSessions(UserId, StartedAt DESC);
CREATE INDEX IX_SessionEx_SessionId       ON SessionExercises(SessionId);
CREATE INDEX IX_Reps_SessionExerciseId    ON SessionReps(SessionExerciseId);
CREATE INDEX IX_Feedback_SessionExercise  ON RealtimeFeedback(SessionExerciseId, OccurredAt);
CREATE INDEX IX_Feedback_ErrorType        ON RealtimeFeedback(ErrorTypeId);
CREATE INDEX IX_Payments_UserSubscriptionId ON Payments(UserSubscriptionId);
CREATE INDEX IX_Payments_Status           ON Payments(Status);
CREATE INDEX IX_Notifications_UserId      ON Notifications(UserId, IsRead);

/* =====================================================================
   12. STORED PROCEDURE: ĐĂNG KÝ TÀI KHOẢN   (giữ nguyên bản gốc)
   ===================================================================== */
DELIMITER $$

CREATE PROCEDURE sp_RegisterUser
(
    IN p_Username     VARCHAR(50),
    IN p_Email        VARCHAR(256),
    IN p_PasswordHash VARCHAR(255),
    IN p_PasswordSalt VARCHAR(255),
    IN p_FullName     VARCHAR(100),
    OUT p_NewUserId   INT
)
BEGIN
    DECLARE v_UserRoleId INT;
    DECLARE v_SubPlanId INT;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    IF EXISTS (SELECT 1 FROM Users WHERE Username = p_Username) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Tên đăng nhập đã tồn tại.';
    END IF;

    IF EXISTS (SELECT 1 FROM Users WHERE Email = p_Email) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Email đã được sử dụng.';
    END IF;

    SELECT RoleId INTO v_UserRoleId FROM Roles WHERE RoleName = 'User' LIMIT 1;
    SELECT SubscriptionPlanId INTO v_SubPlanId FROM SubscriptionPlans WHERE Name = 'Free' LIMIT 1;

    START TRANSACTION;

        INSERT INTO Users (RoleId, Username, Email, PasswordHash, PasswordSalt, FullName)
        VALUES (v_UserRoleId, p_Username, p_Email, p_PasswordHash, p_PasswordSalt, p_FullName);

        SET p_NewUserId = LAST_INSERT_ID();

        INSERT INTO UserProfiles (UserId, DateOfBirth) VALUES (p_NewUserId, NULL);
        INSERT INTO UserSettings (UserId, Language) VALUES (p_NewUserId, 'vi');

        IF v_SubPlanId IS NOT NULL THEN
            INSERT INTO UserSubscriptions (UserId, SubscriptionPlanId, StartDate)
            VALUES (p_NewUserId, v_SubPlanId, CURDATE());
        END IF;

    COMMIT;
END$$

DELIMITER ;

/* =====================================================================
   13. VIEW
   ===================================================================== */

-- 13.1 Tóm tắt buổi tập (giữ nguyên bản gốc)
CREATE OR REPLACE VIEW vw_SessionSummary
AS
SELECT
    s.SessionId, s.UserId, u.Username, s.StartedAt, s.EndedAt, s.Status,
    s.TotalDurationSec, s.OverallFormScore,
    IFNULL(SUM(se.TotalReps), 0) AS TotalReps,
    IFNULL(SUM(se.CleanReps), 0) AS CleanReps,
    (SELECT COUNT(*) FROM RealtimeFeedback rf
        JOIN SessionExercises se2 ON se2.SessionExerciseId = rf.SessionExerciseId
        WHERE se2.SessionId = s.SessionId AND rf.FeedbackType = 'Error') AS TotalErrors
FROM WorkoutSessions s
JOIN Users u ON u.UserId = s.UserId
LEFT JOIN SessionExercises se ON se.SessionId = s.SessionId
GROUP BY s.SessionId, s.UserId, u.Username, s.StartedAt, s.EndedAt,
         s.Status, s.TotalDurationSec, s.OverallFormScore;

-- 13.2 MỚI: pool bài thay thế cho từng ô, lọc sẵn theo mức dụng cụ
CREATE OR REPLACE VIEW vw_SlotSubstitutes
AS
SELECT ts.SlotId, ts.TemplateSessionId, ts.SlotNo,
       mr.NameVi AS RoleVi, e.ExerciseId, e.Slug, e.Name, e.EquipmentTier
FROM TemplateSlots ts
JOIN MovementRoles mr ON mr.MovementRoleId = ts.MovementRoleId
JOIN Exercises e      ON e.MovementRoleId  = ts.MovementRoleId AND e.IsActive = 1;

-- 13.3 MỚI: độ sâu pool theo vai trò — vai trò nào đang thiếu bài ở mức nào
CREATE OR REPLACE VIEW vw_PoolDepth
AS
SELECT mr.NameVi AS RoleVi, mr.NameEn AS RoleEn,
       SUM(e.EquipmentTier = 'T0') AS T0Count,
       SUM(e.EquipmentTier = 'T1') AS T1Count,
       SUM(e.EquipmentTier = 'T2') AS T2Count,
       COUNT(e.ExerciseId) AS Total
FROM MovementRoles mr
LEFT JOIN Exercises e ON e.MovementRoleId = mr.MovementRoleId AND e.IsActive = 1
GROUP BY mr.MovementRoleId, mr.NameVi, mr.NameEn;

-- 13.4 MỚI: buổi tập của user kèm bài gốc nếu đã bị thay.
--      Hai alias khác nhau vì cùng trỏ vào Exercises.
CREATE OR REPLACE VIEW vw_PlannedSession
AS
SELECT pss.ScheduledSessionId, pss.PlanId, pss.WeekNo, pss.ScheduledDate, pss.Status,
       pe.OrderIndex, pe.TargetSets, pe.TargetRepsText, pe.RestSeconds, pe.IsAccessory,
       ex.Slug AS ExerciseSlug, ex.Name AS ExerciseName,
       orig.Slug AS OriginalSlug, pe.SubstitutionReason
FROM PlanScheduledSessions pss
JOIN WorkoutPlanExercises pe ON pe.ScheduledSessionId = pss.ScheduledSessionId
JOIN Exercises ex            ON ex.ExerciseId  = pe.ExerciseId
LEFT JOIN Exercises orig     ON orig.ExerciseId = pe.SubstitutedFromExerciseId;

/* =====================================================================
   14. DỮ LIỆU MẪU
   ===================================================================== */

-- 14.1 Vai trò tài khoản
INSERT INTO Roles (RoleName, Description) VALUES
('Admin', N'Quản trị viên hệ thống'),
('User',  N'Người dùng thông thường');

-- 14.2 Gói dịch vụ
INSERT INTO SubscriptionPlans (Name, PriceMonthly, Currency, Features) VALUES
('Free',    0,      'VND', N'Phát hiện tư thế cơ bản, giới hạn 3 bài tập/ngày'),
('Premium', 99000,  'VND', N'Toàn bộ bài tập, phản hồi giọng nói, lịch sử không giới hạn'),
('Pro',     199000, 'VND', N'Toàn bộ tính năng Premium + chương trình cá nhân hóa AI + phân tích chuyên sâu');

-- 14.3 Thành tích
INSERT INTO Achievements (Code, Name, Description) VALUES
('FIRST_WORKOUT', N'Buổi tập đầu tiên', N'Hoàn thành buổi tập đầu tiên'),
('STREAK_7',      N'7 ngày liên tục',   N'Tập 7 ngày liên tiếp'),
('PERFECT_FORM',  N'Form hoàn hảo',     N'Đạt 100 điểm form trong một bài tập'),
('REPS_1000',     N'1000 reps',         N'Hoàn thành tổng cộng 1000 rep');

-- 14.4 Vai trò vận động (37)
INSERT INTO MovementRoles (MovementRoleId, Code, NameVi, NameEn, Category) VALUES
(1, N'PLYOMETRIC', N'Bật nhảy', N'Plyometric', N'Compound'),
(2, N'CARDIO_THRESHOLD', N'Cardio ngưỡng', N'Cardio — threshold', N'Cardio'),
(3, N'CARDIO_INTERVALS', N'Cardio ngắt quãng', N'Cardio — intervals', N'Cardio'),
(4, N'CARDIO_EASY', N'Cardio nhẹ', N'Cardio — easy', N'Cardio'),
(5, N'CORE_ANTI_EXTENSION', N'Core chống duỗi', N'Core anti-extension', N'Core'),
(6, N'CORE_ANTI_LATERAL_FLEXION', N'Core chống nghiêng', N'Core anti-lateral-flexion', N'Core'),
(7, N'CORE_ANTI_ROTATION', N'Core chống xoay', N'Core anti-rotation', N'Core'),
(8, N'CORE_FLEXION', N'Core gập', N'Core flexion', N'Core'),
(9, N'HIP_EXTENSION', N'Duỗi hông', N'Hip extension', N'Compound'),
(10, N'BACK_EXTENSION', N'Duỗi lưng', N'Back extension', N'Compound'),
(11, N'STRETCH_MOBILITY', N'Giãn cơ', N'Stretch / mobility', N'Mobility'),
(12, N'HIP_HINGE', N'Gập hông', N'Hip hinge', N'Compound'),
(13, N'VERTICAL_PULL', N'Kéo dọc', N'Vertical pull', N'Compound'),
(14, N'HORIZONTAL_PULL', N'Kéo ngang', N'Horizontal pull', N'Compound'),
(15, N'LUNGE_SINGLE_LEG', N'Lunge và một chân', N'Lunge / single leg', N'Compound'),
(16, N'LOADED_CARRY', N'Mang vác', N'Loaded carry', N'Compound'),
(17, N'SQUAT', N'Squat', N'Squat', N'Compound'),
(18, N'EXPLOSIVE_FULL_BODY', N'Toàn thân bùng nổ', N'Explosive full body', N'Compound'),
(19, N'REAR_DELT_EXTERNAL_ROTATION', N'Vai sau', N'Rear delt / external rotation', N'Compound'),
(20, N'ISOLATION_CALF', N'Đơn khớp bắp chân', N'Isolation — calf', N'Isolation'),
(21, N'ISOLATION_TIBIALIS', N'Đơn khớp cơ chày', N'Isolation — tibialis', N'Isolation'),
(22, N'ISOLATION_TRAP_SHRUG', N'Đơn khớp cầu vai', N'Isolation — trap / shrug', N'Isolation'),
(23, N'ISOLATION_FOREARM', N'Đơn khớp cẳng tay', N'Isolation — forearm', N'Isolation'),
(24, N'ISOLATION_NECK', N'Đơn khớp cổ', N'Isolation — neck', N'Isolation'),
(25, N'ISOLATION_HIP_ABDUCTION', N'Đơn khớp dang chân', N'Isolation — hip abduction', N'Isolation'),
(26, N'ISOLATION_HIP_ADDUCTION', N'Đơn khớp khép chân', N'Isolation — hip adduction', N'Isolation'),
(27, N'ISOLATION_LAT', N'Đơn khớp lưng rộng', N'Isolation — lat', N'Isolation'),
(28, N'ISOLATION_CHEST', N'Đơn khớp ngực', N'Isolation — chest', N'Isolation'),
(29, N'ISOLATION_TRICEPS', N'Đơn khớp tay sau', N'Isolation — triceps', N'Isolation'),
(30, N'ISOLATION_BICEPS', N'Đơn khớp tay trước', N'Isolation — biceps', N'Isolation'),
(31, N'ISOLATION_LATERAL_DELT', N'Đơn khớp vai bên', N'Isolation — lateral delt', N'Isolation'),
(32, N'ISOLATION_FRONT_DELT', N'Đơn khớp vai trước', N'Isolation — front delt', N'Isolation'),
(33, N'ISOLATION_HAMSTRING', N'Đơn khớp đùi sau', N'Isolation — hamstring', N'Isolation'),
(34, N'ISOLATION_QUAD', N'Đơn khớp đùi trước', N'Isolation — quad', N'Isolation'),
(35, N'VERTICAL_PUSH', N'Đẩy dọc', N'Vertical push', N'Compound'),
(36, N'HORIZONTAL_PUSH', N'Đẩy ngang', N'Horizontal push', N'Compound'),
(37, N'CLOSE_GRIP_PUSH', N'Đẩy ngang hẹp tay', N'Close-grip push', N'Compound');

-- 14.5 Nhóm cơ (16, lấy từ thư mục video — bản gốc chỉ có 10)
INSERT INTO MuscleGroups (MuscleGroupId, Name, NameVi) VALUES
(1, N'Adductors', N'Cơ khép đùi'),
(2, N'Back', N'Lưng'),
(3, N'Biceps', N'Tay trước'),
(4, N'Calves', N'Bắp chân'),
(5, N'Chest', N'Ngực'),
(6, N'Core', N'Cơ trung tâm'),
(7, N'Forearms', N'Cẳng tay'),
(8, N'Glutes', N'Mông'),
(9, N'Hamstrings', N'Đùi sau'),
(10, N'Lower Back', N'Lưng dưới'),
(11, N'Neck', N'Cổ'),
(12, N'Quadriceps', N'Đùi trước'),
(13, N'Shoulders', N'Vai'),
(14, N'Trapezius', N'Cầu vai'),
(15, N'Triceps', N'Tay sau'),
(16, N'tibialis', N'Cơ chày trước');

-- 14.6 Bài tập (412 bài — thay cho 6 bài mẫu của bản gốc)
INSERT INTO Exercises (ExerciseId, Slug, Name, NameVi, MovementRoleId, ExerciseType,
                       EquipmentTier, SupportsAnalysis, ExcludedReason) VALUES
(1, N'cossack-squat', N'Cossack Squat', NULL, 15, N'Standard', N'T0', 0, NULL),
(2, N'dumbbell-cossack-squat', N'Dumbbell Cossack Squat', NULL, 15, N'Standard', N'T1', 0, NULL),
(3, N'dumbbell-lateral-lunge', N'Dumbbell Lateral Lunge', NULL, 15, N'Standard', N'T1', 0, NULL),
(4, N'machine-hip-adduction', N'Machine Hip Adduction', NULL, 26, N'Standard', N'T2', 0, NULL),
(5, N'backstroke-swim', N'Backstroke Swim', NULL, 4, N'Cardio', N'T0', 0, NULL),
(6, N'band-assisted-pull-up', N'Band Assisted Pull Up', N'Hít xà có dây hỗ trợ', 13, N'Standard', N'T1', 0, NULL),
(7, N'band-kneeling-pulldown', N'Band Kneeling Pulldown', N'Kéo dây kháng lực từ trên xuống, tư thế quỳ', 13, N'Standard', N'T1', 0, NULL),
(8, N'band-pullover', N'Band Pullover', NULL, 27, N'Standard', N'T1', 0, NULL),
(9, N'band-row', N'Band Row', N'Kéo dây kháng lực', 14, N'Standard', N'T1', 0, NULL),
(10, N'band-seated-pulldown', N'Band Seated Pulldown', N'Kéo dây kháng lực từ trên xuống, tư thế ngồi', 13, N'Standard', N'T1', 0, NULL),
(11, N'barbell-bent-over-row-overhand', N'Barbell Bent Over Row Overhand', NULL, 14, N'Standard', N'T2', 0, NULL),
(12, N'barbell-bent-over-row', N'Barbell Bent Over Row', N'Kéo tạ đòn tư thế cúi người', 14, N'Standard', N'T2', 0, NULL),
(13, N'barbell-pullover', N'Barbell Pullover', NULL, 27, N'Standard', N'T2', 0, NULL),
(14, N'breaststroke-swim', N'Breaststroke Swim', NULL, 4, N'Cardio', N'T0', 0, NULL),
(15, N'butterfly-swim', N'Butterfly Swim', NULL, 4, N'Cardio', N'T0', 0, NULL),
(16, N'cable-rope-pullover', N'Cable Rope Pullover', NULL, 27, N'Standard', N'T2', 0, NULL),
(17, N'cable-row-bar-standing-row', N'Cable Row Bar Standing Row', NULL, 14, N'Standard', N'T2', 0, NULL),
(18, N'cable-single-arm-neutral-grip-row', N'Cable Single Arm Neutral Grip Row', NULL, 14, N'Standard', N'T2', 0, NULL),
(19, N'cable-single-arm-underhand-grip-row', N'Cable Single Arm Underhand Grip Row', NULL, 14, N'Standard', N'T2', 0, NULL),
(20, N'cable-supinating-row', N'Cable Supinating Row', NULL, 14, N'Standard', N'T2', 0, NULL),
(21, N'chest-supported-dumbbell-row', N'Chest Supported Dumbbell Row', N'Kéo tạ đơn có tựa ngực', 14, N'Standard', N'T1', 0, NULL),
(22, N'chest-supported-t-bar-row', N'Chest Supported T Bar Row', N'Kéo tạ chữ T có tựa ngực', 14, N'Standard', N'T2', 0, NULL),
(23, N'chin-ups', N'Chin Ups', N'Hít xà tay ngửa', 13, N'Standard', N'T0', 0, NULL),
(24, N'dumbbell-single-arm-row', N'Dumbbell Single Arm Row', N'Kéo tạ đơn một tay', 14, N'Standard', N'T1', 0, NULL),
(25, N'freestyle-swim', N'Freestyle Swim', NULL, 4, N'Cardio', N'T0', 0, NULL),
(26, N'hammer-strength-high-row', N'Hammer Strength High Row', NULL, 14, N'Standard', N'T2', 0, NULL),
(27, N'hammer-strength-iso-lateral-row', N'Hammer Strength Iso Lateral Row', NULL, 14, N'Standard', N'T2', 0, NULL),
(28, N'inverted-row', N'Inverted Row', N'Kéo người dưới thanh ngang hoặc bàn chắc', 14, N'Standard', N'T0', 1, NULL),
(29, N'kettlebell-gorilla-row', N'Kettlebell Gorilla Row', N'Kéo tạ ấm tư thế cúi người', 14, N'Standard', N'T1', 0, NULL),
(30, N'kettlebell-row-single', N'Kettlebell Row Single', NULL, 14, N'Standard', N'T1', 0, NULL),
(31, N'kettlebell-row', N'Kettlebell Row', NULL, 14, N'Standard', N'T1', 0, NULL),
(32, N'kettlebell-single-arm-row', N'Kettlebell Single Arm Row', NULL, 14, N'Standard', N'T1', 0, NULL),
(33, N'landmine-t-bar-rows', N'Landmine T Bar Rows', NULL, 14, N'Standard', N'T2', 0, NULL),
(34, N'lat-pulldown', N'Lat Pulldown', N'Kéo xô', 13, N'Standard', N'T2', 0, NULL),
(35, N'machine-assisted-pull-up', N'Machine Assisted Pull Up', N'Hít xà có máy hỗ trợ', 13, N'Standard', N'T2', 0, NULL),
(36, N'machine-lat-pullover', N'Machine Lat Pullover', NULL, 27, N'Standard', N'T2', 0, NULL),
(37, N'machine-neutral-row', N'Machine Neutral Row', N'Kéo tạ máy, tay song song', 14, N'Standard', N'T2', 0, NULL),
(38, N'machine-plate-loaded-t-bar-row', N'Machine Plate Loaded T Bar Row', NULL, 14, N'Standard', N'T2', 0, NULL),
(39, N'machine-pulldown', N'Machine Pulldown', NULL, 13, N'Standard', N'T2', 0, NULL),
(40, N'machine-seated-cable-row', N'Machine Seated Cable Row', N'Kéo cáp ngồi', 14, N'Standard', N'T2', 0, NULL),
(41, N'machine-underhand-row', N'Machine Underhand Row', NULL, 14, N'Standard', N'T2', 0, NULL),
(42, N'meadows-row', N'Meadows Row', NULL, 14, N'Standard', N'T2', 0, NULL),
(43, N'narrow-pulldown', N'Narrow Pulldown', NULL, 13, N'Standard', N'T2', 0, NULL),
(44, N'neutral-grip-lat-pulldown', N'Neutral Grip Lat Pulldown', N'Kéo xô tay song song', 13, N'Standard', N'T2', 0, NULL),
(45, N'neutral-grip-pull-up', N'Neutral Grip Pull Up', NULL, 13, N'Standard', N'T0', 0, NULL),
(46, N'pendlay-row', N'Pendlay Row', N'Kéo tạ đòn từ sàn (Pendlay)', 14, N'Standard', N'T2', 0, NULL),
(47, N'pull-ups', N'Pull Ups', NULL, 13, N'Standard', N'T0', 0, NULL),
(48, N'rowing-intervals', N'Rowing Intervals', N'Máy chèo ngắt quãng', 3, N'Cardio', N'T2', 0, NULL),
(49, N'rowing-machine-steady-state', N'Rowing Machine Steady State', N'Máy chèo đều tốc độ', 4, N'Cardio', N'T2', 0, NULL),
(50, N'rowing-sprint', N'Rowing Sprint', NULL, 3, N'Cardio', N'T2', 0, NULL),
(51, N'seal-row', N'Seal Row', N'Kéo tạ nằm sấp trên ghế', 14, N'Standard', N'T2', 0, NULL),
(52, N'single-arm-lat-pulldown', N'Single Arm Lat Pulldown', NULL, 13, N'Standard', N'T2', 0, NULL),
(53, N'ski-erg', N'Ski Erg', NULL, 3, N'Cardio', N'T2', 0, NULL),
(54, N'sled-pull', N'Sled Pull', NULL, 3, N'Cardio', N'T2', 0, NULL),
(55, N'smith-machine-bent-over-row', N'Smith Machine Bent Over Row', NULL, 14, N'Standard', N'T2', 0, NULL),
(56, N'straight-arm-lat-pulldown', N'Straight Arm Lat Pulldown', N'Kéo xô tay thẳng', 27, N'Standard', N'T2', 0, NULL),
(57, N'swim-kick-drill', N'Swim Kick Drill', NULL, 4, N'Cardio', N'T0', 0, NULL),
(58, N'swim-pull-drill', N'Swim Pull Drill', NULL, 4, N'Cardio', N'T0', 0, NULL),
(59, N'swim-sprint-intervals', N'Swim Sprint Intervals', NULL, 3, N'Cardio', N'T0', 0, NULL),
(60, N'underhand-barbell-row', N'Underhand Barbell Row', NULL, 14, N'Standard', N'T2', 0, NULL),
(61, N'weighted-pull-ups', N'Weighted Pull Ups', N'Hít xà có tạ', 13, N'Standard', N'T2', 0, NULL),
(62, N'wide-grip-lat-pulldown', N'Wide Grip Lat Pulldown', N'Kéo xô rộng tay', 13, N'Standard', N'T2', 0, NULL),
(63, N'wide-grip-pull-up', N'Wide Grip Pull Up', NULL, 13, N'Standard', N'T0', 0, NULL),
(64, N'wide-grip-seated-cable-row', N'Wide Grip Seated Cable Row', NULL, 14, N'Standard', N'T2', 0, NULL),
(65, N'yates-row', N'Yates Row', NULL, 14, N'Standard', N'T2', 0, NULL),
(66, N'band-curl', N'Band Curl', NULL, 30, N'Standard', N'T1', 0, NULL),
(67, N'barbell-curl', N'Barbell Curl', NULL, 30, N'Standard', N'T2', 0, NULL),
(68, N'barbell-drag-curl', N'Barbell Drag Curl', NULL, 30, N'Standard', N'T2', 0, NULL),
(69, N'bayesian-curl', N'Bayesian Curl', NULL, 30, N'Standard', N'T2', 0, NULL),
(70, N'cable-bar-curl', N'Cable Bar Curl', N'Cuốn tay trước với dây cáp', 30, N'Standard', N'T2', 0, NULL),
(71, N'close-grip-barbell-curl', N'Close Grip Barbell Curl', NULL, 30, N'Standard', N'T2', 0, NULL),
(72, N'cross-body-hammer-curl', N'Cross Body Hammer Curl', NULL, 30, N'Standard', N'T1', 0, NULL),
(73, N'dumbbell-concentration-curl', N'Dumbbell Concentration Curl', NULL, 30, N'Standard', N'T1', 0, NULL),
(74, N'dumbbell-curl', N'Dumbbell Curl', N'Cuốn tay trước với tạ đơn', 30, N'Standard', N'T1', 1, NULL),
(75, N'dumbbell-hammer-curl', N'Dumbbell Hammer Curl', N'Cuốn tay kiểu búa', 30, N'Standard', N'T1', 1, NULL),
(76, N'dumbbell-incline-curl', N'Dumbbell Incline Curl', N'Cuốn tay trên ghế nghiêng', 30, N'Standard', N'T1', 0, NULL),
(77, N'dumbbell-incline-hammer-curl', N'Dumbbell Incline Hammer Curl', NULL, 30, N'Standard', N'T1', 0, NULL),
(78, N'dumbbell-preacher-curl', N'Dumbbell Preacher Curl', NULL, 30, N'Standard', N'T1', 0, NULL),
(79, N'dumbbell-standing-single-arm-curl', N'Dumbbell Standing Single Arm Curl', NULL, 30, N'Standard', N'T1', 0, NULL),
(80, N'dumbbell-standing-single-arm-hammer-curl', N'Dumbbell Standing Single Arm Hammer Curl', NULL, 30, N'Standard', N'T1', 0, NULL),
(81, N'ez-bar-preacher-curl', N'Ez Bar Preacher Curl', N'Cuốn tay trước với đòn EZ, có tựa', 30, N'Standard', N'T2', 0, NULL),
(82, N'ez-bar-reverse-preacher-curl', N'Ez Bar Reverse Preacher Curl', NULL, 30, N'Standard', N'T2', 0, NULL),
(83, N'kettlebell-curl', N'Kettlebell Curl', NULL, 30, N'Standard', N'T1', 0, NULL),
(84, N'kettlebell-goblet-curl', N'Kettlebell Goblet Curl', NULL, 30, N'Standard', N'T1', 0, NULL),
(85, N'machine-preacher-curl', N'Machine Preacher Curl', NULL, 30, N'Standard', N'T2', 0, NULL),
(86, N'reverse-grip-barbell-curl', N'Reverse Grip Barbell Curl', NULL, 30, N'Standard', N'T2', 0, NULL),
(87, N'seated-dumbbell-curl', N'Seated Dumbbell Curl', NULL, 30, N'Standard', N'T1', 0, NULL),
(88, N'spider-curl', N'Spider Curl', N'Cuốn tay nằm sấp trên ghế nghiêng', 30, N'Standard', N'T1', 0, NULL),
(89, N'wide-grip-barbell-curl', N'Wide Grip Barbell Curl', NULL, 30, N'Standard', N'T2', 0, NULL),
(90, N'zottman-curl', N'Zottman Curl', NULL, 30, N'Standard', N'T1', 0, NULL),
(91, N'bodyweight-donkey-calf-raise', N'Bodyweight Donkey Calf Raise', N'Nhón bắp chân không tạ', 20, N'Standard', N'T0', 0, NULL),
(92, N'dumbbell-single-leg-calf-raise', N'Dumbbell Single Leg Calf Raise', N'Nhón bắp chân một chân với tạ đơn', 20, N'Standard', N'T1', 0, NULL),
(93, N'horizontal-leg-press-calf-press', N'Horizontal Leg Press Calf Press', N'Nhón bắp chân trên máy đạp đùi', 20, N'Standard', N'T2', 0, NULL),
(94, N'jump-rope', N'Jump Rope', N'Nhảy dây', 3, N'Cardio', N'T1', 0, NULL),
(95, N'kettlebell-calf-raise', N'Kettlebell Calf Raise', N'Nhón bắp chân với tạ ấm', 20, N'Standard', N'T1', 0, NULL),
(96, N'seated-calf-raise', N'Seated Calf Raise', N'Nhón bắp chân ngồi', 20, N'Standard', N'T2', 0, NULL),
(97, N'single-leg-standing-calf-raise', N'Single Leg Standing Calf Raise', N'Nhón bắp chân một chân', 20, N'Standard', N'T0', 0, NULL),
(98, N'smith-machine-calf-raise', N'Smith Machine Calf Raise', NULL, 20, N'Standard', N'T2', 0, NULL),
(99, N'standing-calf-raise-machine', N'Standing Calf Raise Machine', N'Nhón bắp chân đứng trên máy', 20, N'Standard', N'T2', 0, NULL),
(100, N'barbell-bench-press', N'Barbell Bench Press', N'Đẩy ngực với đòn tạ', 36, N'Standard', N'T2', 0, NULL),
(101, N'barbell-floor-press', N'Barbell Floor Press', NULL, 36, N'Standard', N'T2', 0, NULL),
(102, N'barbell-high-incline-bench-press', N'Barbell High Incline Bench Press', NULL, 36, N'Standard', N'T2', 0, NULL),
(103, N'barbell-incline-bench-press', N'Barbell Incline Bench Press', N'Đẩy ngực nghiêng với đòn tạ', 36, N'Standard', N'T2', 0, NULL),
(104, N'bodyweight-elevated-push-up', N'Bodyweight Elevated Push Up', NULL, 36, N'Standard', N'T0', 0, NULL),
(105, N'bodyweight-knee-push-ups', N'Bodyweight Knee Push Ups', N'Chống đẩy quỳ gối', 36, N'Standard', N'T0', 1, NULL),
(106, N'cable-bench-chest-fly', N'Cable Bench Chest Fly', NULL, 28, N'Standard', N'T2', 0, NULL),
(107, N'cable-bench-press', N'Cable Bench Press', NULL, 36, N'Standard', N'T2', 0, NULL),
(108, N'cable-chest-press', N'Cable Chest Press', NULL, 36, N'Standard', N'T2', 0, NULL),
(109, N'cable-decline-bench-press', N'Cable Decline Bench Press', NULL, 36, N'Standard', N'T2', 0, NULL),
(110, N'cable-high-to-low-fly', N'Cable High To Low Fly', NULL, 28, N'Standard', N'T2', 0, NULL),
(111, N'cable-incline-bench-press', N'Cable Incline Bench Press', NULL, 36, N'Standard', N'T2', 0, NULL),
(112, N'cable-low-to-high-fly', N'Cable Low To High Fly', NULL, 28, N'Standard', N'T2', 0, NULL),
(113, N'cable-pec-fly', N'Cable Pec Fly', N'Ép ngực với dây cáp', 28, N'Standard', N'T2', 0, NULL),
(114, N'cable-standing-single-arm-chest-press', N'Cable Standing Single Arm Chest Press', NULL, 36, N'Standard', N'T2', 0, NULL),
(115, N'decline-barbell-bench-press', N'Decline Barbell Bench Press', NULL, 36, N'Standard', N'T2', 0, NULL),
(116, N'decline-machine-chest-press', N'Decline Machine Chest Press', NULL, 36, N'Standard', N'T2', 0, NULL),
(117, N'decline-push-up', N'Decline Push Up', NULL, 36, N'Standard', N'T0', 0, NULL),
(118, N'dumbbell-bench-press', N'Dumbbell Bench Press', N'Đẩy ngực với tạ đơn', 36, N'Standard', N'T1', 0, NULL),
(119, N'dumbbell-chest-fly', N'Dumbbell Chest Fly', N'Ép ngực với tạ đơn', 28, N'Standard', N'T1', 0, NULL),
(120, N'dumbbell-decline-bench-press', N'Dumbbell Decline Bench Press', NULL, 36, N'Standard', N'T1', 0, NULL),
(121, N'dumbbell-decline-chest-fly', N'Dumbbell Decline Chest Fly', NULL, 28, N'Standard', N'T1', 0, NULL),
(122, N'dumbbell-incline-bench-press', N'Dumbbell Incline Bench Press', N'Đẩy ngực nghiêng với tạ đơn', 36, N'Standard', N'T1', 0, NULL),
(123, N'dumbbell-incline-chest-fly', N'Dumbbell Incline Chest Fly', N'Ép ngực nghiêng với tạ đơn', 28, N'Standard', N'T1', 0, NULL),
(124, N'dumbbell-single-arm-chest-press', N'Dumbbell Single Arm Chest Press', NULL, 36, N'Standard', N'T1', 0, NULL),
(125, N'floor-press', N'Floor Press', NULL, 36, N'Standard', N'T1', 0, NULL),
(126, N'incline-machine-chest-press', N'Incline Machine Chest Press', N'Đẩy ngực máy góc nghiêng', 36, N'Standard', N'T2', 0, NULL),
(127, N'incline-push-up', N'Incline Push Up', N'Chống đẩy nghiêng, tay cao hơn chân', 36, N'Standard', N'T0', 1, NULL),
(128, N'kettlebell-bench-press', N'Kettlebell Bench Press', NULL, 36, N'Standard', N'T1', 0, NULL),
(129, N'kettlebell-incline-bench-press', N'Kettlebell Incline Bench Press', NULL, 36, N'Standard', N'T1', 0, NULL),
(130, N'machine-chest-press', N'Machine Chest Press', N'Đẩy ngực máy', 36, N'Standard', N'T2', 0, NULL),
(131, N'machine-pec-fly', N'Machine Pec Fly', N'Ép ngực máy', 28, N'Standard', N'T2', 0, NULL),
(132, N'neutral-grip-dumbbell-bench-press', N'Neutral Grip Dumbbell Bench Press', NULL, 36, N'Standard', N'T1', 0, NULL),
(133, N'push-up', N'Push Up', N'Chống đẩy', 36, N'Standard', N'T0', 1, NULL),
(134, N'reverse-grip-barbell-bench-press', N'Reverse Grip Barbell Bench Press', NULL, 36, N'Standard', N'T2', 0, NULL),
(135, N'single-arm-cable-fly', N'Single Arm Cable Fly', NULL, 28, N'Standard', N'T2', 0, NULL),
(136, N'smith-machine-bench-press', N'Smith Machine Bench Press', NULL, 36, N'Standard', N'T2', 0, NULL),
(137, N'smith-machine-incline-bench-press', N'Smith Machine Incline Bench Press', NULL, 36, N'Standard', N'T2', 0, NULL),
(138, N'wide-grip-barbell-bench-press', N'Wide Grip Barbell Bench Press', NULL, 36, N'Standard', N'T2', 0, NULL),
(139, N'abdominals-stretch-variation-four', N'Abdominals Stretch Variation Four', NULL, 11, N'Duration', N'T0', 0, NULL),
(140, N'abdominals-stretch-variation-one', N'Abdominals Stretch Variation One', N'Giãn cơ bụng và hông, kiểu 1', 11, N'Duration', N'T0', 0, NULL),
(141, N'abdominals-stretch-variation-three', N'Abdominals Stretch Variation Three', N'Giãn cơ bụng và hông, kiểu 3', 11, N'Duration', N'T0', 0, NULL),
(142, N'abdominals-stretch-variation-two', N'Abdominals Stretch Variation Two', N'Giãn cơ bụng và hông, kiểu 2', 11, N'Duration', N'T0', 0, NULL),
(143, N'band-wood-chopper', N'Band Wood Chopper', NULL, 7, N'Standard', N'T1', 0, NULL),
(144, N'barbell-clean-and-press', N'Barbell Clean And Press', NULL, 18, N'Standard', N'T2', 0, NULL),
(145, N'barbell-muscle-snatch', N'Barbell Muscle Snatch', NULL, 18, N'Standard', N'T2', 0, NULL),
(146, N'barbell-power-snatch', N'Barbell Power Snatch', NULL, 18, N'Standard', N'T2', 0, NULL),
(147, N'barbell-snatch', N'Barbell Snatch', NULL, 18, N'Standard', N'T2', 0, NULL),
(148, N'barbell-spinal-jefferson-curl', N'Barbell Spinal Jefferson Curl', NULL, NULL, N'Cardio', N'T2', 0, N'Loaded spinal flexion — excluded from every program'),
(149, N'bird-dog', N'Bird Dog', N'Quỳ bốn điểm, duỗi tay chân chéo (bird dog)', 7, N'Standard', N'T0', 1, NULL),
(150, N'bodyweight-deadlift', N'Bodyweight Deadlift', NULL, 12, N'Standard', N'T0', 0, NULL),
(151, N'bodyweight-russian-twist', N'Bodyweight Russian Twist', NULL, 8, N'Standard', N'T0', 0, NULL),
(152, N'bodyweight-spinal-jefferson-curl', N'Bodyweight Spinal Jefferson Curl', NULL, NULL, N'Cardio', N'T0', 0, N'Loaded spinal flexion — excluded from every program'),
(153, N'burpee', N'Burpee', NULL, 18, N'Standard', N'T0', 0, NULL),
(154, N'cable-side-bend', N'Cable Side Bend', NULL, 6, N'Standard', N'T2', 0, NULL),
(155, N'cable-standing-low-to-high-wood-chopper', N'Cable Standing Low To High Wood Chopper', NULL, 7, N'Standard', N'T2', 0, NULL),
(156, N'cable-wood-chopper', N'Cable Wood Chopper', NULL, 7, N'Standard', N'T2', 0, NULL),
(157, N'captains-chair-knee-raise', N'Captains Chair Knee Raise', NULL, 8, N'Standard', N'T2', 0, NULL),
(158, N'dead-bug', N'Dead Bug', N'Nằm ngửa duỗi tay chân chéo (dead bug)', 5, N'Standard', N'T0', 1, NULL),
(159, N'decline-crunch', N'Decline Crunch', NULL, 8, N'Cardio', N'T0', 0, NULL),
(160, N'decline-sit-up', N'Decline Sit Up', NULL, 8, N'Standard', N'T0', 0, NULL),
(161, N'dumbbell-russian-twist', N'Dumbbell Russian Twist', NULL, 8, N'Standard', N'T1', 0, NULL),
(162, N'dumbbell-side-bend', N'Dumbbell Side Bend', NULL, 6, N'Standard', N'T1', 0, NULL),
(163, N'dumbbell-single-arm-clean-and-press', N'Dumbbell Single Arm Clean And Press', NULL, 18, N'Standard', N'T1', 0, NULL),
(164, N'dumbbell-situp', N'Dumbbell Situp', NULL, 8, N'Standard', N'T1', 0, NULL),
(165, N'dumbbell-spinal-jefferson-curl', N'Dumbbell Spinal Jefferson Curl', NULL, NULL, N'Cardio', N'T1', 0, N'Loaded spinal flexion — excluded from every program'),
(166, N'dumbbell-superman', N'Dumbbell Superman', NULL, 5, N'Standard', N'T1', 0, NULL),
(167, N'elbow-side-plank', N'Elbow Side Plank', N'Plank nghiêng chống khuỷu tay', 6, N'Duration', N'T0', 1, NULL),
(168, N'front-plank', N'Front Plank', N'Plank chống khuỷu tay', 5, N'Duration', N'T0', 1, NULL),
(169, N'hand-plank', N'Hand Plank', N'Plank chống bàn tay', 5, N'Duration', N'T0', 1, NULL),
(170, N'hang-snatch', N'Hang Snatch', NULL, 18, N'Standard', N'T2', 0, NULL),
(171, N'hanging-knee-raises', N'Hanging Knee Raises', N'Treo xà nâng gối', 8, N'Standard', N'T0', 0, NULL),
(172, N'jumping-jack', N'Jumping Jack', NULL, 1, N'Standard', N'T0', 0, NULL),
(173, N'kettlebell-spinal-jefferson-curl', N'Kettlebell Spinal Jefferson Curl', NULL, NULL, N'Cardio', N'T1', 0, N'Loaded spinal flexion — excluded from every program'),
(174, N'kettlebell-turkish-get-up', N'Kettlebell Turkish Get Up', NULL, 7, N'Standard', N'T1', 0, NULL),
(175, N'kettlebell-windmill', N'Kettlebell Windmill', NULL, 7, N'Standard', N'T1', 0, NULL),
(176, N'kneeling-cable-crunch', N'Kneeling Cable Crunch', NULL, 8, N'Cardio', N'T2', 0, NULL),
(177, N'machine-crunch', N'Machine Crunch', NULL, 8, N'Cardio', N'T2', 0, NULL),
(178, N'man-maker', N'Man Maker', NULL, 18, N'Standard', N'T0', 0, NULL),
(179, N'mountain-climber', N'Mountain Climber', N'Leo núi tại chỗ', 5, N'Standard', N'T0', 1, NULL),
(180, N'pallof-press', N'Pallof Press', N'Đẩy dây ra trước, chống xoay thân (Pallof press)', 7, N'Duration', N'T1', 0, NULL),
(181, N'snatch-grip-deadlift', N'Snatch Grip Deadlift', NULL, 18, N'Standard', N'T2', 0, NULL),
(182, N'snatch-grip-high-pull', N'Snatch Grip High Pull', NULL, 18, N'Standard', N'T2', 0, NULL),
(183, N'snatch-pull', N'Snatch Pull', NULL, 18, N'Standard', N'T2', 0, NULL),
(184, N'supermans', N'Supermans', N'Nằm sấp nâng tay và chân', 5, N'Standard', N'T0', 1, NULL),
(185, N'toes-to-bar', N'Toes To Bar', NULL, 8, N'Standard', N'T0', 0, NULL),
(186, N'v-up', N'V Up', N'Gập bụng chữ V', 8, N'Standard', N'T0', 1, NULL),
(187, N'barbell-wrist-curl', N'Barbell Wrist Curl', NULL, 23, N'Standard', N'T2', 0, NULL),
(188, N'cable-wrist-curl', N'Cable Wrist Curl', NULL, 23, N'Standard', N'T2', 0, NULL),
(189, N'dead-hang', N'Dead Hang', N'Treo xà thả lỏng', 11, N'Duration', N'T0', 0, NULL),
(190, N'dumbbell-wrist-curl', N'Dumbbell Wrist Curl', NULL, 23, N'Standard', N'T1', 0, NULL),
(191, N'dumbbell-wrist-extension', N'Dumbbell Wrist Extension', NULL, 23, N'Standard', N'T1', 0, NULL),
(192, N'plate-pinch', N'Plate Pinch', NULL, 23, N'Duration', N'T2', 0, NULL),
(193, N'wrist-roller', N'Wrist Roller', NULL, 23, N'Standard', N'T2', 0, NULL),
(194, N'b-stance-hip-thrust', N'B Stance Hip Thrust', NULL, 9, N'Standard', N'T0', 0, NULL),
(195, N'band-glute-bridge', N'Band Glute Bridge', NULL, 9, N'Standard', N'T1', 0, NULL),
(196, N'band-hip-abduction', N'Band Hip Abduction', N'Dang chân với dây kháng lực', 25, N'Standard', N'T1', 0, NULL),
(197, N'band-romanian-deadlift', N'Band Romanian Deadlift', N'Gập hông với dây kháng lực', 12, N'Standard', N'T1', 1, NULL),
(198, N'barbell-hip-thrust', N'Barbell Hip Thrust', N'Đẩy hông với đòn tạ', 9, N'Standard', N'T2', 1, NULL),
(199, N'barbell-split-squat', N'Barbell Split Squat', NULL, 15, N'Standard', N'T2', 0, NULL),
(200, N'barbell-stiff-leg-deadlifts', N'Barbell Stiff Leg Deadlifts', NULL, 12, N'Standard', N'T2', 0, NULL),
(201, N'barbell-thruster', N'Barbell Thruster', NULL, 18, N'Standard', N'T2', 0, NULL),
(202, N'bodyweight-alternating-lateral-lunge', N'Bodyweight Alternating Lateral Lunge', N'Lunge sang ngang, đổi bên', 15, N'Standard', N'T0', 1, NULL),
(203, N'bodyweight-alternating-reverse-lunges', N'Bodyweight Alternating Reverse Lunges', NULL, 15, N'Standard', N'T0', 0, NULL),
(204, N'bodyweight-box-squat', N'Bodyweight Box Squat', N'Squat ngồi xuống ghế rồi đứng lên', 17, N'Standard', N'T0', 1, NULL),
(205, N'bodyweight-hip-abduction', N'Bodyweight Hip Abduction', N'Dang chân nằm nghiêng', 25, N'Standard', N'T0', 0, NULL),
(206, N'bodyweight-reverse-lunge', N'Bodyweight Reverse Lunge', N'Lunge lùi', 15, N'Standard', N'T0', 1, NULL),
(207, N'cable-bench-straight-leg-kickback', N'Cable Bench Straight Leg Kickback', NULL, 9, N'Standard', N'T2', 0, NULL),
(208, N'cable-hip-abduction', N'Cable Hip Abduction', NULL, 25, N'Standard', N'T2', 0, NULL),
(209, N'cable-kickback', N'Cable Kickback', N'Đá chân sau với dây cáp', 9, N'Standard', N'T2', 0, NULL),
(210, N'cable-pull-through', N'Cable Pull Through', N'Kéo cáp qua háng', 12, N'Standard', N'T2', 0, NULL),
(211, N'dumbbell-bulgarian-split-squat', N'Dumbbell Bulgarian Split Squat', NULL, 15, N'Standard', N'T1', 0, NULL),
(212, N'dumbbell-feet-elevated-glute-bridge', N'Dumbbell Feet Elevated Glute Bridge', NULL, 9, N'Standard', N'T1', 0, NULL),
(213, N'dumbbell-figure-four-heels-elevated-hip-thrust', N'Dumbbell Figure Four Heels Elevated Hip Thrust', NULL, 9, N'Standard', N'T1', 0, NULL),
(214, N'dumbbell-goblet-alternating-curtsy-lunge', N'Dumbbell Goblet Alternating Curtsy Lunge', NULL, 15, N'Standard', N'T1', 0, NULL),
(215, N'dumbbell-goblet-bulgarian-split-squat', N'Dumbbell Goblet Bulgarian Split Squat', N'Squat một chân kiểu Bulgaria, ôm tạ', 15, N'Standard', N'T1', 1, NULL),
(216, N'dumbbell-goblet-forward-lunge', N'Dumbbell Goblet Forward Lunge', NULL, 15, N'Standard', N'T1', 0, NULL),
(217, N'dumbbell-goblet-reverse-lunge', N'Dumbbell Goblet Reverse Lunge', NULL, 15, N'Standard', N'T1', 0, NULL),
(218, N'dumbbell-goblet-split-squat', N'Dumbbell Goblet Split Squat', NULL, 15, N'Standard', N'T1', 0, NULL),
(219, N'dumbbell-goblet-squat', N'Dumbbell Goblet Squat', N'Squat ôm tạ trước ngực', 17, N'Standard', N'T1', 1, NULL),
(220, N'dumbbell-heels-elevated-hip-thrust', N'Dumbbell Heels Elevated Hip Thrust', NULL, 9, N'Standard', N'T1', 0, NULL),
(221, N'dumbbell-single-leg-hip-thrust', N'Dumbbell Single Leg Hip Thrust', NULL, 9, N'Standard', N'T1', 0, NULL),
(222, N'dumbbell-sumo-squat', N'Dumbbell Sumo Squat', NULL, 17, N'Standard', N'T1', 0, NULL),
(223, N'dumbbell-thruster', N'Dumbbell Thruster', NULL, 18, N'Standard', N'T1', 0, NULL),
(224, N'forward-lunge', N'Forward Lunge', NULL, 15, N'Standard', N'T0', 0, NULL),
(225, N'frog-pump', N'Frog Pump', N'Đẩy hông chụm gót, mở gối', 9, N'Standard', N'T0', 1, NULL),
(226, N'glute-bridge', N'Glute Bridge', N'Đẩy hông không tạ', 9, N'Standard', N'T0', 1, NULL),
(227, N'glute-kickback-machine', N'Glute Kickback Machine', NULL, 9, N'Standard', N'T2', 0, NULL),
(228, N'good-mornings', N'Good Mornings', NULL, 12, N'Standard', N'T2', 0, NULL),
(229, N'kettlebell-alternating-curtsy-lunge', N'Kettlebell Alternating Curtsy Lunge', NULL, 15, N'Standard', N'T1', 0, NULL),
(230, N'kettlebell-assisted-bulgarian-split-squat', N'Kettlebell Assisted Bulgarian Split Squat', NULL, 15, N'Standard', N'T1', 0, NULL),
(231, N'kettlebell-goblet-squat', N'Kettlebell Goblet Squat', NULL, 17, N'Standard', N'T1', 0, NULL),
(232, N'kettlebell-hip-thrust', N'Kettlebell Hip Thrust', N'Đẩy hông với tạ ấm', 9, N'Standard', N'T1', 1, NULL),
(233, N'kettlebell-sumo-deadlift', N'Kettlebell Sumo Deadlift', NULL, 12, N'Standard', N'T1', 0, NULL),
(234, N'kettlebell-swing', N'Kettlebell Swing', N'Vung tạ ấm', 12, N'Standard', N'T1', 0, NULL),
(235, N'kettlebell-thruster', N'Kettlebell Thruster', NULL, 18, N'Standard', N'T1', 0, NULL),
(236, N'lunge-walking', N'Lunge Walking', NULL, 15, N'Standard', N'T0', 0, NULL),
(237, N'machine-hip-abduction', N'Machine Hip Abduction', N'Dang chân trên máy', 25, N'Standard', N'T2', 0, NULL),
(238, N'machine-hip-thrust', N'Machine Hip Thrust', N'Đẩy hông máy', 9, N'Standard', N'T2', 0, NULL),
(239, N'plate-forward-lunge', N'Plate Forward Lunge', NULL, 15, N'Standard', N'T2', 0, NULL),
(240, N'single-leg-glute-bridge', N'Single Leg Glute Bridge', N'Đẩy hông một chân', 9, N'Standard', N'T0', 1, NULL),
(241, N'single-leg-hip-thrust', N'Single Leg Hip Thrust', NULL, 9, N'Standard', N'T0', 0, NULL),
(242, N'standing-cable-hip-abduction', N'Standing Cable Hip Abduction', NULL, 25, N'Standard', N'T2', 0, NULL),
(243, N'wall-ball', N'Wall Ball', NULL, 18, N'Standard', N'T2', 0, NULL),
(244, N'band-leg-curl', N'Band Leg Curl', NULL, 33, N'Standard', N'T1', 0, NULL),
(245, N'barbell-romanian-deadlift', N'Barbell Romanian Deadlift', N'Gập hông với đòn tạ (Romanian deadlift)', 12, N'Standard', N'T2', 1, NULL),
(246, N'cable-single-leg-laying-leg-curl', N'Cable Single Leg Laying Leg Curl', NULL, 33, N'Standard', N'T2', 0, NULL),
(247, N'deficit-deadlift', N'Deficit Deadlift', NULL, 12, N'Standard', N'T2', 0, NULL),
(248, N'deficit-dumbbell-romanian-deadlift', N'Deficit Dumbbell Romanian Deadlift', NULL, 12, N'Standard', N'T1', 0, NULL),
(249, N'dumbbell-cross-body-romanian-deadlift', N'Dumbbell Cross Body Romanian Deadlift', N'Gập hông với tạ đơn', 12, N'Standard', N'T1', 1, NULL),
(250, N'dumbbell-deadlift', N'Dumbbell Deadlift', NULL, 12, N'Standard', N'T1', 0, NULL),
(251, N'dumbbell-leg-curl', N'Dumbbell Leg Curl', N'Cuốn chân với tạ đơn kẹp bàn chân', 33, N'Standard', N'T1', 0, NULL),
(252, N'hamstring-curl', N'Hamstring Curl', NULL, 33, N'Standard', N'T2', 0, NULL),
(253, N'hip-hinge-speed-romanian-deadlift', N'Hip Hinge Speed Romanian Deadlift', NULL, 12, N'Standard', N'T0', 0, NULL),
(254, N'kettlebell-romanian-deadlift', N'Kettlebell Romanian Deadlift', NULL, 12, N'Standard', N'T1', 0, NULL),
(255, N'kickstand-dumbbell-romanian-deadlift', N'Kickstand Dumbbell Romanian Deadlift', NULL, 12, N'Standard', N'T1', 0, NULL),
(256, N'lying-leg-curl', N'Lying Leg Curl', N'Cuốn chân nằm', 33, N'Standard', N'T2', 0, NULL),
(257, N'nordic-hamstring-curl', N'Nordic Hamstring Curl', N'Ngả người ra trước, giữ bằng cơ đùi sau', 33, N'Standard', N'T0', 1, NULL),
(258, N'romanian-deadlift-hamstring-sweeps', N'Romanian Deadlift Hamstring Sweeps', NULL, 12, N'Standard', N'T0', 0, NULL),
(259, N'seated-leg-curl', N'Seated Leg Curl', N'Cuốn chân ngồi', 33, N'Standard', N'T2', 0, NULL),
(260, N'single-leg-dumbbell-romanian-deadlift', N'Single Leg Dumbbell Romanian Deadlift', NULL, 12, N'Standard', N'T1', 0, NULL),
(261, N'single-leg-kettlebell-romanian-deadlift-deficit', N'Single Leg Kettlebell Romanian Deadlift Deficit', NULL, 12, N'Standard', N'T1', 0, NULL),
(262, N'single-legged-romanian-deadlifts', N'Single Legged Romanian Deadlifts', NULL, 12, N'Standard', N'T0', 0, NULL),
(263, N'smith-machine-sumo-romanian-deadlift', N'Smith Machine Sumo Romanian Deadlift', NULL, 12, N'Standard', N'T2', 0, NULL),
(264, N'stability-ball-leg-curl', N'Stability Ball Leg Curl', NULL, 33, N'Standard', N'T2', 0, NULL),
(265, N'towel-slide-leg-curl', N'Towel Slide Leg Curl', NULL, 33, N'Standard', N'T2', 0, NULL),
(266, N'back-extension', N'Back Extension', N'Ngả người nâng thân trên (back extension)', 10, N'Standard', N'T2', 0, NULL),
(267, N'dumbbell-back-extension', N'Dumbbell Back Extension', NULL, 10, N'Standard', N'T1', 0, NULL),
(268, N'machine-45-degree-back-extension', N'Machine 45 Degree Back Extension', NULL, 10, N'Standard', N'T2', 0, NULL),
(269, N'reverse-hyperextension', N'Reverse Hyperextension', NULL, 10, N'Standard', N'T2', 0, NULL),
(270, N'single-leg-back-extension', N'Single Leg Back Extension', NULL, 10, N'Standard', N'T2', 0, NULL),
(271, N'neck-curl', N'Neck Curl', NULL, 24, N'Standard', N'T0', 0, NULL),
(272, N'neck-extension', N'Neck Extension', NULL, 24, N'Standard', N'T0', 0, NULL),
(273, N'arc-trainer', N'Arc Trainer', NULL, 4, N'Cardio', N'T2', 0, NULL),
(274, N'assault-bike', N'Assault Bike', N'Xe đạp tay chân (assault bike)', 3, N'Cardio', N'T2', 0, NULL),
(275, N'band-squat', N'Band Squat', NULL, 17, N'Standard', N'T1', 0, NULL),
(276, N'barbell-banded-back-squat', N'Barbell Banded Back Squat', NULL, 17, N'Standard', N'T2', 0, NULL),
(277, N'barbell-front-rack-step-up-knee-drive', N'Barbell Front Rack Step Up Knee Drive', NULL, 15, N'Standard', N'T2', 0, NULL),
(278, N'barbell-reverse-lunge', N'Barbell Reverse Lunge', NULL, 15, N'Standard', N'T2', 0, NULL),
(279, N'barbell-squat', N'Barbell Squat', N'Squat với đòn tạ sau gáy', 17, N'Standard', N'T2', 1, NULL),
(280, N'barbell-step-up-knee-drive', N'Barbell Step Up Knee Drive', NULL, 15, N'Standard', N'T2', 0, NULL),
(281, N'belt-squat', N'Belt Squat', NULL, 17, N'Standard', N'T2', 0, NULL),
(282, N'bodyweight-squat', N'Bodyweight Squat', N'Squat không tạ', 17, N'Standard', N'T0', 1, NULL),
(283, N'box-jump', N'Box Jump', NULL, 1, N'Standard', N'T0', 0, NULL),
(284, N'bulgarian-split-squat', N'Bulgarian Split Squat', N'Squat một chân kiểu Bulgaria', 15, N'Standard', N'T1', 1, NULL),
(285, N'cycling-cooldown', N'Cycling Cooldown', NULL, 4, N'Cardio', N'T2', 0, NULL),
(286, N'cycling-intervals', N'Cycling Intervals', N'Đạp xe ngắt quãng', 3, N'Cardio', N'T2', 0, NULL),
(287, N'cycling-sprint', N'Cycling Sprint', NULL, 3, N'Cardio', N'T2', 0, NULL),
(288, N'cycling-warmup', N'Cycling Warmup', NULL, 4, N'Cardio', N'T2', 0, NULL),
(289, N'dumbbell-alternating-forward-lunge', N'Dumbbell Alternating Forward Lunge', NULL, 15, N'Standard', N'T1', 0, NULL),
(290, N'dumbbell-front-squat-tempo', N'Dumbbell Front Squat Tempo', NULL, 17, N'Standard', N'T1', 0, NULL),
(291, N'dumbbell-front-squat', N'Dumbbell Front Squat', N'Squat với hai tạ đơn trên vai', 17, N'Standard', N'T1', 1, NULL),
(292, N'dumbbell-overhead-squat', N'Dumbbell Overhead Squat', NULL, 17, N'Standard', N'T1', 0, NULL),
(293, N'dumbbell-step-up-low', N'Dumbbell Step Up Low', N'Bước lên bục thấp với tạ đơn', 15, N'Standard', N'T1', 1, NULL),
(294, N'elliptical', N'Elliptical', N'Máy đi bộ trên không', 4, N'Cardio', N'T2', 0, NULL),
(295, N'front-foot-elevated-split-squat', N'Front Foot Elevated Split Squat', NULL, 15, N'Standard', N'T0', 0, NULL),
(296, N'front-squat', N'Front Squat', N'Squat với đòn tạ trước ngực', 17, N'Standard', N'T2', 1, NULL),
(297, N'hang-clean', N'Hang Clean', NULL, 18, N'Standard', N'T2', 0, NULL),
(298, N'hang-power-clean', N'Hang Power Clean', NULL, 18, N'Standard', N'T2', 0, NULL),
(299, N'hiking', N'Hiking', N'Đi bộ đường dài', 4, N'Cardio', N'T0', 0, NULL),
(300, N'hill-climb-repeats', N'Hill Climb Repeats', NULL, 2, N'Cardio', N'T2', 0, NULL),
(301, N'incline-treadmill-walk', N'Incline Treadmill Walk', N'Đi bộ nghiêng trên máy chạy', 4, N'Cardio', N'T2', 0, NULL),
(302, N'indoor-cycling-spin', N'Indoor Cycling Spin', NULL, 2, N'Cardio', N'T2', 0, NULL),
(303, N'jump-squats', N'Jump Squats', NULL, 1, N'Standard', N'T0', 0, NULL),
(304, N'long-run', N'Long Run', N'Chạy dài, tốc độ đều', 4, N'Cardio', N'T0', 0, NULL),
(305, N'machine-hack-squat', N'Machine Hack Squat', N'Squat máy hack', 17, N'Standard', N'T2', 0, NULL),
(306, N'machine-horizontal-leg-press', N'Machine Horizontal Leg Press', NULL, 17, N'Standard', N'T2', 0, NULL),
(307, N'machine-leg-extension', N'Machine Leg Extension', N'Duỗi chân máy', 34, N'Standard', N'T2', 0, NULL),
(308, N'machine-leg-press', N'Machine Leg Press', N'Đạp đùi máy', 17, N'Standard', N'T2', 0, NULL),
(309, N'machine-plate-loaded-leg-extension', N'Machine Plate Loaded Leg Extension', NULL, 34, N'Standard', N'T2', 0, NULL),
(310, N'pause-squat', N'Pause Squat', NULL, 17, N'Standard', N'T2', 0, NULL),
(311, N'pendulum-squat-v-squat', N'Pendulum Squat V Squat', NULL, 17, N'Standard', N'T2', 0, NULL),
(312, N'power-clean', N'Power Clean', NULL, 18, N'Standard', N'T2', 0, NULL),
(313, N'reverse-hack-squat', N'Reverse Hack Squat', NULL, 17, N'Standard', N'T2', 0, NULL),
(314, N'running-cooldown', N'Running Cooldown', NULL, 4, N'Cardio', N'T0', 0, NULL),
(315, N'running-intervals', N'Running Intervals', N'Chạy ngắt quãng', 3, N'Cardio', N'T0', 0, NULL),
(316, N'single-leg-press', N'Single Leg Press', NULL, 17, N'Standard', N'T2', 0, NULL),
(317, N'single-leg-step-down', N'Single Leg Step Down', NULL, 15, N'Standard', N'T0', 0, NULL),
(318, N'sissy-squat', N'Sissy Squat', NULL, 17, N'Standard', N'T2', 0, NULL),
(319, N'sled-push', N'Sled Push', NULL, 3, N'Cardio', N'T2', 0, NULL),
(320, N'smith-machine-front-squat', N'Smith Machine Front Squat', NULL, 17, N'Standard', N'T2', 0, NULL),
(321, N'smith-machine-squat', N'Smith Machine Squat', NULL, 17, N'Standard', N'T2', 0, NULL),
(322, N'split-squat-isometric-hold', N'Split Squat Isometric Hold', NULL, 17, N'Duration', N'T0', 0, NULL),
(323, N'stair-climber', N'Stair Climber', N'Máy leo cầu thang', 4, N'Cardio', N'T2', 0, NULL),
(324, N'steady-state-ride', N'Steady State Ride', N'Đạp xe đều tốc độ', 4, N'Cardio', N'T2', 0, NULL),
(325, N'tempo-run', N'Tempo Run', N'Chạy ở ngưỡng', 2, N'Cardio', N'T0', 0, NULL),
(326, N'trail-run', N'Trail Run', NULL, 4, N'Cardio', N'T0', 0, NULL),
(327, N'treadmill-run', N'Treadmill Run', NULL, 2, N'Cardio', N'T2', 0, NULL),
(328, N'versaclimber', N'Versaclimber', NULL, 3, N'Cardio', N'T2', 0, NULL),
(329, N'wall-sit', N'Wall Sit', N'Tựa lưng vào tường giữ tư thế squat', 17, N'Duration', N'T0', 1, NULL),
(330, N'zercher-squat', N'Zercher Squat', NULL, 17, N'Standard', N'T2', 0, NULL),
(331, N'arnold-press', N'Arnold Press', NULL, 35, N'Standard', N'T1', 0, NULL),
(332, N'band-external-rotation', N'Band External Rotation', N'Xoay ngoài vai với dây kháng lực', 19, N'Standard', N'T1', 0, NULL),
(333, N'band-high-face-pull', N'Band High Face Pull', N'Kéo dây kháng lực ngang mặt', 19, N'Standard', N'T1', 0, NULL),
(334, N'band-lateral-raise', N'Band Lateral Raise', NULL, 31, N'Standard', N'T1', 0, NULL),
(335, N'band-overhead-press', N'Band Overhead Press', NULL, 35, N'Standard', N'T1', 0, NULL),
(336, N'band-single-arm-lateral-raise', N'Band Single Arm Lateral Raise', NULL, 31, N'Standard', N'T1', 0, NULL),
(337, N'barbell-overhead-press', N'Barbell Overhead Press', N'Đẩy vai qua đầu với đòn tạ', 35, N'Standard', N'T2', 0, NULL),
(338, N'barbell-upright-row', N'Barbell Upright Row', NULL, NULL, N'Standard', N'T2', 0, N'Shoulder impingement risk, better alternatives exist — kept out of the pool'),
(339, N'battle-ropes', N'Battle Ropes', NULL, 3, N'Cardio', N'T2', 0, NULL),
(340, N'behind-the-neck-press', N'Behind The Neck Press', NULL, 35, N'Standard', N'T2', 0, NULL),
(341, N'cable-bar-face-pull', N'Cable Bar Face Pull', NULL, 19, N'Standard', N'T2', 0, NULL),
(342, N'cable-external-rotation', N'Cable External Rotation', N'Xoay ngoài vai với dây cáp', 19, N'Standard', N'T2', 0, NULL),
(343, N'cable-front-raise', N'Cable Front Raise', NULL, 32, N'Standard', N'T2', 0, NULL),
(344, N'cable-low-single-arm-lateral-raise', N'Cable Low Single Arm Lateral Raise', NULL, 31, N'Standard', N'T2', 0, NULL),
(345, N'cable-overhead-press', N'Cable Overhead Press', NULL, 35, N'Standard', N'T2', 0, NULL),
(346, N'cable-rope-hammer-curl', N'Cable Rope Hammer Curl', NULL, 30, N'Standard', N'T2', 0, NULL),
(347, N'cable-rope-kneeling-face-pull', N'Cable Rope Kneeling Face Pull', N'Kéo dây ngang mặt, tư thế quỳ', 19, N'Standard', N'T2', 0, NULL),
(348, N'cable-seated-rope-face-pull', N'Cable Seated Rope Face Pull', NULL, 19, N'Standard', N'T2', 0, NULL),
(349, N'cuban-press', N'Cuban Press', NULL, 35, N'Standard', N'T1', 0, NULL),
(350, N'dumbbell-front-raise', N'Dumbbell Front Raise', NULL, 32, N'Standard', N'T1', 0, NULL),
(351, N'dumbbell-incline-front-raise', N'Dumbbell Incline Front Raise', NULL, 32, N'Standard', N'T1', 0, NULL),
(352, N'dumbbell-lateral-raise', N'Dumbbell Lateral Raise', N'Nâng tạ đơn sang ngang', 31, N'Standard', N'T1', 1, NULL),
(353, N'dumbbell-laying-reverse-fly', N'Dumbbell Laying Reverse Fly', N'Ép vai sau nằm sấp với tạ đơn', 19, N'Standard', N'T1', 0, NULL),
(354, N'dumbbell-push-press', N'Dumbbell Push Press', NULL, 35, N'Standard', N'T1', 0, NULL),
(355, N'dumbbell-rear-delt-fly', N'Dumbbell Rear Delt Fly', N'Ép vai sau với tạ đơn', 19, N'Standard', N'T1', 0, NULL),
(356, N'dumbbell-seated-overhead-press', N'Dumbbell Seated Overhead Press', N'Đẩy vai qua đầu với tạ đơn, tư thế ngồi', 35, N'Standard', N'T1', 0, NULL),
(357, N'dumbbell-seated-rear-delt-fly', N'Dumbbell Seated Rear Delt Fly', NULL, 19, N'Standard', N'T1', 0, NULL),
(358, N'dumbbell-upright-row', N'Dumbbell Upright Row', NULL, NULL, N'Standard', N'T1', 0, N'Shoulder impingement risk, better alternatives exist — kept out of the pool'),
(359, N'kettlebell-front-raise', N'Kettlebell Front Raise', NULL, 32, N'Standard', N'T1', 0, NULL),
(360, N'kettlebell-push-press', N'Kettlebell Push Press', NULL, 35, N'Standard', N'T1', 0, NULL),
(361, N'kettlebell-seated-overhead-press', N'Kettlebell Seated Overhead Press', NULL, 35, N'Standard', N'T1', 0, NULL),
(362, N'landmine-press', N'Landmine Press', N'Đẩy đòn tạ chếch (landmine)', 35, N'Standard', N'T2', 0, NULL),
(363, N'leaning-cable-lateral-raise', N'Leaning Cable Lateral Raise', NULL, 31, N'Standard', N'T2', 0, NULL),
(364, N'machine-face-pulls', N'Machine Face Pulls', N'Kéo dây ngang mặt trên máy', 19, N'Standard', N'T2', 0, NULL),
(365, N'machine-front-military-press', N'Machine Front Military Press', N'Đẩy vai máy', 35, N'Standard', N'T2', 0, NULL),
(366, N'machine-lateral-raise', N'Machine Lateral Raise', N'Nâng tay sang ngang trên máy', 31, N'Standard', N'T2', 0, NULL),
(367, N'plate-front-raise', N'Plate Front Raise', NULL, 32, N'Standard', N'T2', 0, NULL),
(368, N'push-jerk', N'Push Jerk', NULL, 18, N'Standard', N'T2', 0, NULL),
(369, N'reverse-pec-deck', N'Reverse Pec Deck', N'Ép vai sau trên máy', 19, N'Standard', N'T2', 0, NULL),
(370, N'shadow-boxing', N'Shadow Boxing', NULL, 3, N'Cardio', N'T0', 0, NULL),
(371, N'single-arm-dumbbell-overhead-press', N'Single Arm Dumbbell Overhead Press', NULL, 35, N'Standard', N'T1', 0, NULL),
(372, N'single-arm-landmine-press', N'Single Arm Landmine Press', NULL, 35, N'Standard', N'T2', 0, NULL),
(373, N'smith-machine-seated-overhead-press', N'Smith Machine Seated Overhead Press', NULL, 35, N'Standard', N'T2', 0, NULL),
(374, N'split-jerk', N'Split Jerk', NULL, 18, N'Standard', N'T2', 0, NULL),
(375, N'z-press', N'Z Press', NULL, 35, N'Standard', N'T2', 0, NULL),
(376, N'band-shrug', N'Band Shrug', NULL, 22, N'Standard', N'T1', 0, NULL),
(377, N'barbell-behind-the-back-30-degree-shrug', N'Barbell Behind The Back 30 Degree Shrug', NULL, 22, N'Standard', N'T2', 0, NULL),
(378, N'barbell-deadlift', N'Barbell Deadlift', N'Nâng tạ từ sàn (deadlift)', 12, N'Standard', N'T2', 0, NULL),
(379, N'barbell-rack-pull', N'Barbell Rack Pull', NULL, 12, N'Standard', N'T2', 0, NULL),
(380, N'barbell-shrug', N'Barbell Shrug', NULL, 22, N'Standard', N'T2', 0, NULL),
(381, N'cable-30-degree-shrug', N'Cable 30 Degree Shrug', NULL, 22, N'Standard', N'T2', 0, NULL),
(382, N'dumbbell-row-bilateral', N'Dumbbell Row Bilateral', NULL, 14, N'Standard', N'T1', 0, NULL),
(383, N'dumbbell-row-unilateral', N'Dumbbell Row Unilateral', NULL, 14, N'Standard', N'T1', 0, NULL),
(384, N'dumbbell-seated-shrug', N'Dumbbell Seated Shrug', NULL, 22, N'Standard', N'T1', 0, NULL),
(385, N'dumbbell-shrug', N'Dumbbell Shrug', NULL, 22, N'Standard', N'T1', 0, NULL),
(386, N'kettlebell-farmers-carry', N'Kettlebell Farmers Carry', N'Xách tạ đi bộ', 16, N'Duration', N'T1', 0, NULL),
(387, N'kettlebell-shrug', N'Kettlebell Shrug', NULL, 22, N'Standard', N'T1', 0, NULL),
(388, N'smith-machine-standing-shrugs', N'Smith Machine Standing Shrugs', NULL, 22, N'Standard', N'T2', 0, NULL),
(389, N'trap-bar-deadlift', N'Trap Bar Deadlift', NULL, 12, N'Standard', N'T2', 0, NULL),
(390, N'trap-bar-shrug', N'Trap Bar Shrug', NULL, 22, N'Standard', N'T2', 0, NULL),
(391, N'barbell-close-grip-bench-press', N'Barbell Close Grip Bench Press', N'Đẩy ngực hẹp tay', 37, N'Standard', N'T2', 0, NULL),
(392, N'bench-dips', N'Bench Dips', NULL, 37, N'Standard', N'T0', 0, NULL),
(393, N'cable-bar-pushdown', N'Cable Bar Pushdown', NULL, 29, N'Standard', N'T2', 0, NULL),
(394, N'cable-rope-overhead-tricep-extension', N'Cable Rope Overhead Tricep Extension', NULL, 29, N'Standard', N'T2', 0, NULL),
(395, N'cable-rope-pushdown', N'Cable Rope Pushdown', N'Duỗi tay sau với dây cáp', 29, N'Standard', N'T2', 0, NULL),
(396, N'cable-single-arm-rope-pushdown', N'Cable Single Arm Rope Pushdown', NULL, 29, N'Standard', N'T2', 0, NULL),
(397, N'diamond-push-ups', N'Diamond Push Ups', NULL, 36, N'Standard', N'T0', 0, NULL),
(398, N'dumbbell-decline-skullcrusher', N'Dumbbell Decline Skullcrusher', NULL, 29, N'Standard', N'T1', 0, NULL),
(399, N'dumbbell-seated-overhead-tricep-extension', N'Dumbbell Seated Overhead Tricep Extension', N'Duỗi tay sau đầu với tạ đơn', 29, N'Standard', N'T1', 0, NULL),
(400, N'dumbbell-skullcrusher', N'Dumbbell Skullcrusher', N'Duỗi tay sau nằm với tạ đơn', 29, N'Standard', N'T1', 0, NULL),
(401, N'dumbbell-tricep-kickback', N'Dumbbell Tricep Kickback', N'Đá tay sau với tạ đơn', 29, N'Standard', N'T1', 0, NULL),
(402, N'jm-press', N'Jm Press', NULL, 29, N'Standard', N'T2', 0, NULL),
(403, N'machine-cable-v-bar-push-downs', N'Machine Cable V Bar Push Downs', NULL, 29, N'Standard', N'T2', 0, NULL),
(404, N'machine-dips', N'Machine Dips', NULL, 37, N'Standard', N'T2', 0, NULL),
(405, N'machine-tricep-extension', N'Machine Tricep Extension', N'Duỗi tay sau trên máy', 29, N'Standard', N'T2', 0, NULL),
(406, N'parralel-bar-dips', N'Parralel Bar Dips', NULL, 37, N'Standard', N'T0', 0, NULL),
(407, N'reverse-grip-tricep-pushdown', N'Reverse Grip Tricep Pushdown', NULL, 29, N'Standard', N'T2', 0, NULL),
(408, N'single-arm-overhead-cable-extension', N'Single Arm Overhead Cable Extension', NULL, 29, N'Standard', N'T2', 0, NULL),
(409, N'single-arm-tricep-extension', N'Single Arm Tricep Extension', NULL, 29, N'Standard', N'T2', 0, NULL),
(410, N'smith-machine-close-grip-bench-press', N'Smith Machine Close Grip Bench Press', NULL, 37, N'Standard', N'T2', 0, NULL),
(411, N'tate-press', N'Tate Press', NULL, 29, N'Standard', N'T1', 0, NULL),
(412, N'tibialis-raise', N'Tibialis Raise', NULL, 21, N'Standard', N'T0', 0, NULL);

-- 14.7 Nhóm cơ chính của từng bài
INSERT INTO ExerciseMuscleGroups (ExerciseId, MuscleGroupId, IsPrimary) VALUES
(1, 1, 1),
(2, 1, 1),
(3, 1, 1),
(4, 1, 1),
(5, 2, 1),
(6, 2, 1),
(7, 2, 1),
(8, 2, 1),
(9, 2, 1),
(10, 2, 1),
(11, 2, 1),
(12, 2, 1),
(13, 2, 1),
(14, 2, 1),
(15, 2, 1),
(16, 2, 1),
(17, 2, 1),
(18, 2, 1),
(19, 2, 1),
(20, 2, 1),
(21, 2, 1),
(22, 2, 1),
(23, 2, 1),
(24, 2, 1),
(25, 2, 1),
(26, 2, 1),
(27, 2, 1),
(28, 2, 1),
(29, 2, 1),
(30, 2, 1),
(31, 2, 1),
(32, 2, 1),
(33, 2, 1),
(34, 2, 1),
(35, 2, 1),
(36, 2, 1),
(37, 2, 1),
(38, 2, 1),
(39, 2, 1),
(40, 2, 1),
(41, 2, 1),
(42, 2, 1),
(43, 2, 1),
(44, 2, 1),
(45, 2, 1),
(46, 2, 1),
(47, 2, 1),
(48, 2, 1),
(49, 2, 1),
(50, 2, 1),
(51, 2, 1),
(52, 2, 1),
(53, 2, 1),
(54, 2, 1),
(55, 2, 1),
(56, 2, 1),
(57, 2, 1),
(58, 2, 1),
(59, 2, 1),
(60, 2, 1),
(61, 2, 1),
(62, 2, 1),
(63, 2, 1),
(64, 2, 1),
(65, 2, 1),
(66, 3, 1),
(67, 3, 1),
(68, 3, 1),
(69, 3, 1),
(70, 3, 1),
(71, 3, 1),
(72, 3, 1),
(73, 3, 1),
(74, 3, 1),
(75, 3, 1),
(76, 3, 1),
(77, 3, 1),
(78, 3, 1),
(79, 3, 1),
(80, 3, 1),
(81, 3, 1),
(82, 3, 1),
(83, 3, 1),
(84, 3, 1),
(85, 3, 1),
(86, 3, 1),
(87, 3, 1),
(88, 3, 1),
(89, 3, 1),
(90, 3, 1),
(91, 4, 1),
(92, 4, 1),
(93, 4, 1),
(94, 4, 1),
(95, 4, 1),
(96, 4, 1),
(97, 4, 1),
(98, 4, 1),
(99, 4, 1),
(100, 5, 1),
(101, 5, 1),
(102, 5, 1),
(103, 5, 1),
(104, 5, 1),
(105, 5, 1),
(106, 5, 1),
(107, 5, 1),
(108, 5, 1),
(109, 5, 1),
(110, 5, 1),
(111, 5, 1),
(112, 5, 1),
(113, 5, 1),
(114, 5, 1),
(115, 5, 1),
(116, 5, 1),
(117, 5, 1),
(118, 5, 1),
(119, 5, 1),
(120, 5, 1),
(121, 5, 1),
(122, 5, 1),
(123, 5, 1),
(124, 5, 1),
(125, 5, 1),
(126, 5, 1),
(127, 5, 1),
(128, 5, 1),
(129, 5, 1),
(130, 5, 1),
(131, 5, 1),
(132, 5, 1),
(133, 5, 1),
(134, 5, 1),
(135, 5, 1),
(136, 5, 1),
(137, 5, 1),
(138, 5, 1),
(139, 6, 1),
(140, 6, 1),
(141, 6, 1),
(142, 6, 1),
(143, 6, 1),
(144, 6, 1),
(145, 6, 1),
(146, 6, 1),
(147, 6, 1),
(148, 6, 1),
(149, 6, 1),
(150, 6, 1),
(151, 6, 1),
(152, 6, 1),
(153, 6, 1),
(154, 6, 1),
(155, 6, 1),
(156, 6, 1),
(157, 6, 1),
(158, 6, 1),
(159, 6, 1),
(160, 6, 1),
(161, 6, 1),
(162, 6, 1),
(163, 6, 1),
(164, 6, 1),
(165, 6, 1),
(166, 6, 1),
(167, 6, 1),
(168, 6, 1),
(169, 6, 1),
(170, 6, 1),
(171, 6, 1),
(172, 6, 1),
(173, 6, 1),
(174, 6, 1),
(175, 6, 1),
(176, 6, 1),
(177, 6, 1),
(178, 6, 1),
(179, 6, 1),
(180, 6, 1),
(181, 6, 1),
(182, 6, 1),
(183, 6, 1),
(184, 6, 1),
(185, 6, 1),
(186, 6, 1),
(187, 7, 1),
(188, 7, 1),
(189, 7, 1),
(190, 7, 1),
(191, 7, 1),
(192, 7, 1),
(193, 7, 1),
(194, 8, 1),
(195, 8, 1),
(196, 8, 1),
(197, 8, 1),
(198, 8, 1),
(199, 8, 1),
(200, 8, 1),
(201, 8, 1),
(202, 8, 1),
(203, 8, 1),
(204, 8, 1),
(205, 8, 1),
(206, 8, 1),
(207, 8, 1),
(208, 8, 1),
(209, 8, 1),
(210, 8, 1),
(211, 8, 1),
(212, 8, 1),
(213, 8, 1),
(214, 8, 1),
(215, 8, 1),
(216, 8, 1),
(217, 8, 1),
(218, 8, 1),
(219, 8, 1),
(220, 8, 1),
(221, 8, 1),
(222, 8, 1),
(223, 8, 1),
(224, 8, 1),
(225, 8, 1),
(226, 8, 1),
(227, 8, 1),
(228, 8, 1),
(229, 8, 1),
(230, 8, 1),
(231, 8, 1),
(232, 8, 1),
(233, 8, 1),
(234, 8, 1),
(235, 8, 1),
(236, 8, 1),
(237, 8, 1),
(238, 8, 1),
(239, 8, 1),
(240, 8, 1),
(241, 8, 1),
(242, 8, 1),
(243, 8, 1),
(244, 9, 1),
(245, 9, 1),
(246, 9, 1),
(247, 9, 1),
(248, 9, 1),
(249, 9, 1),
(250, 9, 1),
(251, 9, 1),
(252, 9, 1),
(253, 9, 1),
(254, 9, 1),
(255, 9, 1),
(256, 9, 1),
(257, 9, 1),
(258, 9, 1),
(259, 9, 1),
(260, 9, 1),
(261, 9, 1),
(262, 9, 1),
(263, 9, 1),
(264, 9, 1),
(265, 9, 1),
(266, 10, 1),
(267, 10, 1),
(268, 10, 1),
(269, 10, 1),
(270, 10, 1),
(271, 11, 1),
(272, 11, 1),
(273, 12, 1),
(274, 12, 1),
(275, 12, 1),
(276, 12, 1),
(277, 12, 1),
(278, 12, 1),
(279, 12, 1),
(280, 12, 1),
(281, 12, 1),
(282, 12, 1),
(283, 12, 1),
(284, 12, 1),
(285, 12, 1),
(286, 12, 1),
(287, 12, 1),
(288, 12, 1),
(289, 12, 1),
(290, 12, 1),
(291, 12, 1),
(292, 12, 1),
(293, 12, 1),
(294, 12, 1),
(295, 12, 1),
(296, 12, 1),
(297, 12, 1),
(298, 12, 1),
(299, 12, 1),
(300, 12, 1),
(301, 12, 1),
(302, 12, 1),
(303, 12, 1),
(304, 12, 1),
(305, 12, 1),
(306, 12, 1),
(307, 12, 1),
(308, 12, 1),
(309, 12, 1),
(310, 12, 1),
(311, 12, 1),
(312, 12, 1),
(313, 12, 1),
(314, 12, 1),
(315, 12, 1),
(316, 12, 1),
(317, 12, 1),
(318, 12, 1),
(319, 12, 1),
(320, 12, 1),
(321, 12, 1),
(322, 12, 1),
(323, 12, 1),
(324, 12, 1),
(325, 12, 1),
(326, 12, 1),
(327, 12, 1),
(328, 12, 1),
(329, 12, 1),
(330, 12, 1),
(331, 13, 1),
(332, 13, 1),
(333, 13, 1),
(334, 13, 1),
(335, 13, 1),
(336, 13, 1),
(337, 13, 1),
(338, 13, 1),
(339, 13, 1),
(340, 13, 1),
(341, 13, 1),
(342, 13, 1),
(343, 13, 1),
(344, 13, 1),
(345, 13, 1),
(346, 13, 1),
(347, 13, 1),
(348, 13, 1),
(349, 13, 1),
(350, 13, 1),
(351, 13, 1),
(352, 13, 1),
(353, 13, 1),
(354, 13, 1),
(355, 13, 1),
(356, 13, 1),
(357, 13, 1),
(358, 13, 1),
(359, 13, 1),
(360, 13, 1),
(361, 13, 1),
(362, 13, 1),
(363, 13, 1),
(364, 13, 1),
(365, 13, 1),
(366, 13, 1),
(367, 13, 1),
(368, 13, 1),
(369, 13, 1),
(370, 13, 1),
(371, 13, 1),
(372, 13, 1),
(373, 13, 1),
(374, 13, 1),
(375, 13, 1),
(376, 14, 1),
(377, 14, 1),
(378, 14, 1),
(379, 14, 1),
(380, 14, 1),
(381, 14, 1),
(382, 14, 1),
(383, 14, 1),
(384, 14, 1),
(385, 14, 1),
(386, 14, 1),
(387, 14, 1),
(388, 14, 1),
(389, 14, 1),
(390, 14, 1),
(391, 15, 1),
(392, 15, 1),
(393, 15, 1),
(394, 15, 1),
(395, 15, 1),
(396, 15, 1),
(397, 15, 1),
(398, 15, 1),
(399, 15, 1),
(400, 15, 1),
(401, 15, 1),
(402, 15, 1),
(403, 15, 1),
(404, 15, 1),
(405, 15, 1),
(406, 15, 1),
(407, 15, 1),
(408, 15, 1),
(409, 15, 1),
(410, 15, 1),
(411, 15, 1),
(412, 16, 1);

/* 14.7b KẾ THỪA TỪ SCHEMA GỐC — 6 bài mẫu, luật góc và danh mục lỗi tư thế.
   - 5 bài Squat / Push-up / Lunge / Plank / Bicep Curl được giữ nguyên tên vì
     ANALYZER_REGISTRY (app/ml/analyzers/registry.py) và màn Workout của Flutter
     dùng đúng các tên họ động tác này. Chúng không có video riêng nên
     MovementRoleId = NULL (không lọt vào pool thay bài) kèm lý do.
   - Jumping Jack đã có trong 412 bài của v2 → chỉ bổ sung metadata của bản gốc. */
INSERT INTO Exercises (ExerciseId, Slug, Name, NameVi, Description, MovementRoleId, Category, Difficulty,
                       ExerciseType, EquipmentTier, SupportsAnalysis, ExcludedReason, Met) VALUES
(413, N'legacy-squat',      N'Squat',      N'Squat',            N'Đứng lên ngồi xuống, giữ lưng thẳng, đầu gối theo mũi chân', NULL, N'Strength', N'Beginner',     N'Standard', N'T0', 1, N'Bài mẫu từ schema gốc, không có video — giữ vì analyzer dùng tên này', 5.0),
(414, N'legacy-push-up',    N'Push-up',    N'Chống đẩy',        N'Chống đẩy, thân người thẳng, khuỷu tay khoảng 45 độ',       NULL, N'Strength', N'Intermediate', N'Standard', N'T0', 1, N'Bài mẫu từ schema gốc, không có video — giữ vì analyzer dùng tên này', 3.8),
(415, N'legacy-lunge',      N'Lunge',      N'Lunge',            N'Bước trùng chân, gối trước vuông góc',                      NULL, N'Strength', N'Beginner',     N'Standard', N'T0', 1, N'Bài mẫu từ schema gốc, không có video — giữ vì analyzer dùng tên này', 4.0),
(416, N'legacy-plank',      N'Plank',      N'Plank',            N'Giữ tư thế tấm ván, thân thẳng từ đầu đến gót',              NULL, N'Core',     N'Beginner',     N'Duration', N'T0', 1, N'Bài mẫu từ schema gốc, không có video — giữ vì analyzer dùng tên này', 3.3),
(417, N'legacy-bicep-curl', N'Bicep Curl', N'Cuốn tay trước',   N'Cuốn tạ tay, giữ khuỷu cố định',                            NULL, N'Strength', N'Beginner',     N'Standard', N'T1', 1, N'Bài mẫu từ schema gốc, không có video — giữ vì analyzer dùng tên này', 3.5);

UPDATE Exercises
SET Description = N'Nhảy dang tay chân, vận động toàn thân',
    Category    = N'Cardio',
    Difficulty  = N'Beginner',
    Met         = 8.0
WHERE Slug = N'jumping-jack';

-- Nhóm cơ chính của 5 bài mẫu (giống bản gốc) + Calves là nhóm phụ của Jumping Jack
INSERT INTO ExerciseMuscleGroups (ExerciseId, MuscleGroupId, IsPrimary)
SELECT e.ExerciseId, m.MuscleGroupId, 1
FROM Exercises e JOIN MuscleGroups m ON
    (e.Slug = N'legacy-squat'      AND m.Name = N'Quadriceps') OR
    (e.Slug = N'legacy-push-up'    AND m.Name = N'Chest') OR
    (e.Slug = N'legacy-lunge'      AND m.Name = N'Glutes') OR
    (e.Slug = N'legacy-plank'      AND m.Name = N'Core') OR
    (e.Slug = N'legacy-bicep-curl' AND m.Name = N'Biceps');

INSERT INTO ExerciseMuscleGroups (ExerciseId, MuscleGroupId, IsPrimary)
SELECT e.ExerciseId, m.MuscleGroupId, 0
FROM Exercises e JOIN MuscleGroups m ON e.Slug = N'jumping-jack' AND m.Name = N'Calves';

/* Luật góc khớp của bản gốc (Squat & Push-up).
   Lưu ý: RuleName ở đây là mô tả tiếng Việt nên analyzer BỎ QUA có chủ đích
   (xem app/ml/analyzers/thresholds.py — chỉ đọc khoá máy như back_straight_min).
   Giữ lại làm tài liệu. Ngưỡng thật cho từng bài nạp bằng scripts/seed_posture_rules.py. */
SET @SquatId = (SELECT ExerciseId FROM Exercises WHERE Slug = N'legacy-squat'   LIMIT 1);
SET @PushId  = (SELECT ExerciseId FROM Exercises WHERE Slug = N'legacy-push-up' LIMIT 1);

INSERT INTO ExercisePostureRules
    (ExerciseId, RuleName, JointA, JointB, JointC, MinAngle, MaxAngle, TargetAngle, IsRepTrigger, Tolerance)
VALUES
(@SquatId, N'Góc đầu gối (hip-knee-ankle)',          N'Hip',      N'Knee',  N'Ankle', 70,  100, 90,  1, 10),
(@SquatId, N'Độ thẳng lưng (shoulder-hip-knee)',     N'Shoulder', N'Hip',   N'Knee',  160, 185, 175, 0, 8),
(@PushId,  N'Góc khuỷu tay (shoulder-elbow-wrist)',  N'Shoulder', N'Elbow', N'Wrist', 80,  100, 90,  1, 10),
(@PushId,  N'Thân thẳng (shoulder-hip-ankle)',       N'Shoulder', N'Hip',   N'Ankle', 165, 185, 178, 0, 8);

-- Danh mục lỗi tư thế + câu nhắc của AI (bản gốc)
INSERT INTO PostureErrorTypes (ExerciseId, ErrorCode, ErrorName, Severity, CorrectionTip, VoicePrompt) VALUES
(@SquatId, N'KNEE_VALGUS',   N'Đầu gối đổ vào trong', N'High',   N'Đẩy đầu gối ra ngoài theo hướng mũi chân',      N'Đẩy đầu gối ra ngoài!'),
(@SquatId, N'SQUAT_SHALLOW', N'Ngồi chưa đủ sâu',     N'Medium', N'Hạ hông xuống thấp hơn, đùi song song mặt sàn', N'Xuống sâu hơn chút nữa!'),
(@SquatId, N'BACK_ROUNDING', N'Lưng bị cong',         N'High',   N'Giữ ngực mở, lưng thẳng',                       N'Giữ thẳng lưng!'),
(@PushId,  N'HIP_SAGGING',   N'Hông bị võng xuống',   N'High',   N'Siết cơ bụng, giữ thân thẳng',                  N'Siết bụng, giữ thân thẳng!'),
(@PushId,  N'ELBOW_FLARE',   N'Khuỷu tay xòe quá rộng', N'Medium', N'Khép khuỷu tay gần thân khoảng 45 độ',        N'Khép khuỷu tay lại!');

-- 14.8 Câu 1: 12 mục tiêu onboarding
INSERT INTO OnboardingGoals (GoalCode, Label) VALUES
(N'GOAL_MUSCLE', N'Build muscle'),
(N'GOAL_BURNFAT', N'Burn fat'),
(N'GOAL_WEIGHTLOSS', N'Weight loss'),
(N'GOAL_POSTURE', N'Improve posture'),
(N'GOAL_BACKPAIN', N'Reduce back pain'),
(N'GOAL_STRESS', N'Relieve stress'),
(N'GOAL_MENTAL', N'Boost mental strength'),
(N'GOAL_BALANCE', N'Balance'),
(N'GOAL_FLEX', N'Flexibility'),
(N'GOAL_ENDURANCE', N'Increase endurance'),
(N'GOAL_AGILITY', N'Agility'),
(N'GOAL_OPTIMIZE', N'Optimize workouts');

-- 14.9 Bảng chấm điểm mục tiêu -> hướng giáo án
INSERT INTO GoalDirectionScores (GoalCode, Direction, Score) VALUES
(N'GOAL_MUSCLE', N'BuildMuscle', 3),
(N'GOAL_MUSCLE', N'LoseFat', 0),
(N'GOAL_MUSCLE', N'StayFit', 0),
(N'GOAL_MUSCLE', N'Endurance', 0),
(N'GOAL_BURNFAT', N'BuildMuscle', 0),
(N'GOAL_BURNFAT', N'LoseFat', 3),
(N'GOAL_BURNFAT', N'StayFit', 0),
(N'GOAL_BURNFAT', N'Endurance', 0),
(N'GOAL_WEIGHTLOSS', N'BuildMuscle', 0),
(N'GOAL_WEIGHTLOSS', N'LoseFat', 3),
(N'GOAL_WEIGHTLOSS', N'StayFit', 0),
(N'GOAL_WEIGHTLOSS', N'Endurance', 0),
(N'GOAL_POSTURE', N'BuildMuscle', 0),
(N'GOAL_POSTURE', N'LoseFat', 0),
(N'GOAL_POSTURE', N'StayFit', 3),
(N'GOAL_POSTURE', N'Endurance', 0),
(N'GOAL_BACKPAIN', N'BuildMuscle', 0),
(N'GOAL_BACKPAIN', N'LoseFat', 0),
(N'GOAL_BACKPAIN', N'StayFit', 3),
(N'GOAL_BACKPAIN', N'Endurance', 0),
(N'GOAL_STRESS', N'BuildMuscle', 0),
(N'GOAL_STRESS', N'LoseFat', 0),
(N'GOAL_STRESS', N'StayFit', 3),
(N'GOAL_STRESS', N'Endurance', 0),
(N'GOAL_MENTAL', N'BuildMuscle', 0),
(N'GOAL_MENTAL', N'LoseFat', 0),
(N'GOAL_MENTAL', N'StayFit', 2),
(N'GOAL_MENTAL', N'Endurance', 0),
(N'GOAL_BALANCE', N'BuildMuscle', 0),
(N'GOAL_BALANCE', N'LoseFat', 0),
(N'GOAL_BALANCE', N'StayFit', 2),
(N'GOAL_BALANCE', N'Endurance', 0),
(N'GOAL_FLEX', N'BuildMuscle', 0),
(N'GOAL_FLEX', N'LoseFat', 0),
(N'GOAL_FLEX', N'StayFit', 2),
(N'GOAL_FLEX', N'Endurance', 0),
(N'GOAL_ENDURANCE', N'BuildMuscle', 0),
(N'GOAL_ENDURANCE', N'LoseFat', 0),
(N'GOAL_ENDURANCE', N'StayFit', 0),
(N'GOAL_ENDURANCE', N'Endurance', 3),
(N'GOAL_AGILITY', N'BuildMuscle', 0),
(N'GOAL_AGILITY', N'LoseFat', 0),
(N'GOAL_AGILITY', N'StayFit', 0),
(N'GOAL_AGILITY', N'Endurance', 2),
(N'GOAL_OPTIMIZE', N'BuildMuscle', 1),
(N'GOAL_OPTIMIZE', N'LoseFat', 0),
(N'GOAL_OPTIMIZE', N'StayFit', 0),
(N'GOAL_OPTIMIZE', N'Endurance', 1);

-- 14.10 Câu 12: dụng cụ
INSERT INTO EquipmentOptions (EquipmentCode, Label, Tier) VALUES
(N'NONE', N'None of the above', N'T0'),
(N'EQ_BAND', N'Resistance bands', N'T1'),
(N'EQ_DUMBBELL', N'Dumbbells', N'T1'),
(N'EQ_KETTLEBELL', N'Kettlebells', N'T1'),
(N'EQ_MACHINE', N'Machines', N'T2'),
(N'EQ_BARBELL', N'Barbells', N'T2'),
(N'EQ_FULLGYM', N'Full gym', N'T2');

-- 14.11 Câu 4: vùng quan tâm
INSERT INTO FocusAreas (AreaCode, Label) VALUES
(N'BACK', N'Back'),
(N'ARM', N'Arm'),
(N'SHOULDER', N'Shoulder'),
(N'ABS', N'Abs'),
(N'CHEST', N'Chest'),
(N'LEG', N'Leg'),
(N'GLUTES', N'Glutes'),
(N'FULLBODY', N'Full body');

INSERT INTO FocusAreaAccessories (AreaCode, ExerciseId) VALUES
(N'ABS', 158),
(N'ABS', 171),
(N'ABS', 180),
(N'ABS', 186),
(N'ARM', 395),
(N'ARM', 75),
(N'ARM', 88),
(N'BACK', 51),
(N'BACK', 56),
(N'BACK', 9),
(N'CHEST', 113),
(N'CHEST', 123),
(N'CHEST', 131),
(N'GLUTES', 209),
(N'GLUTES', 225),
(N'GLUTES', 237),
(N'LEG', 256),
(N'LEG', 307),
(N'LEG', 96),
(N'SHOULDER', 352),
(N'SHOULDER', 355),
(N'SHOULDER', 366);

-- 14.12 Câu 11: vấn đề sức khoẻ
INSERT INTO HealthIssues (IssueCode, LabelVi, ExtraConstraint, ForceBeginnerPool) VALUES
(N'HI_BACK', N'Back or hernia — lưng hoặc thoát vị', N'Mọi buổi phải có tối thiểu 2 bài kéo lưng trên và core chống chuyển động', 0),
(N'HI_ARMSHOULDER', N'Arms and shoulders — tay và vai', N'Nâng tạ sang ngang giữ tải nhẹ, không quá ngang vai', 0),
(N'HI_HIP', N'Hip joints — khớp háng', N'Biên độ chọn theo mức thoải mái, không ép xuống sâu', 0),
(N'HI_KNEE', N'Knee — đầu gối', N'Mọi bài cardio chuyển sang loại không va đập', 0),
(N'HI_POSTINJURY', N'Post-injury recovery — đang hồi phục sau chấn thương', N'Khối lượng còn 50-60%. Thêm một ngày nghỉ so với tần suất người dùng chọn', 1);

/* Bài bị cấm theo từng vấn đề sức khoẻ.
   Lưu ý: HI_KNEE KHÔNG cấm machine-leg-extension nữa — pool 'Đơn khớp đùi trước'
   chỉ có 2 bài, cấm hết là ô đó trống ở mọi mức dụng cụ. Thay bằng ràng buộc
   tải nhẹ ở tầng ứng dụng. */
INSERT INTO HealthIssueExclusions (IssueCode, ExerciseId) VALUES
(N'HI_BACK', 197),
(N'HI_BACK', 12),
(N'HI_BACK', 11),
(N'HI_BACK', 144),
(N'HI_BACK', 378),
(N'HI_BACK', 145),
(N'HI_BACK', 146),
(N'HI_BACK', 379),
(N'HI_BACK', 245),
(N'HI_BACK', 147),
(N'HI_BACK', 148),
(N'HI_BACK', 279),
(N'HI_BACK', 201),
(N'HI_BACK', 150),
(N'HI_BACK', 151),
(N'HI_BACK', 152),
(N'HI_BACK', 159),
(N'HI_BACK', 160),
(N'HI_BACK', 247),
(N'HI_BACK', 248),
(N'HI_BACK', 249),
(N'HI_BACK', 250),
(N'HI_BACK', 161),
(N'HI_BACK', 163),
(N'HI_BACK', 164),
(N'HI_BACK', 165),
(N'HI_BACK', 223),
(N'HI_BACK', 296),
(N'HI_BACK', 228),
(N'HI_BACK', 297),
(N'HI_BACK', 298),
(N'HI_BACK', 170),
(N'HI_BACK', 253),
(N'HI_BACK', 254),
(N'HI_BACK', 173),
(N'HI_BACK', 233),
(N'HI_BACK', 234),
(N'HI_BACK', 235),
(N'HI_BACK', 255),
(N'HI_BACK', 42),
(N'HI_BACK', 46),
(N'HI_BACK', 312),
(N'HI_BACK', 368),
(N'HI_BACK', 269),
(N'HI_BACK', 260),
(N'HI_BACK', 55),
(N'HI_BACK', 263),
(N'HI_BACK', 181),
(N'HI_BACK', 182),
(N'HI_BACK', 183),
(N'HI_BACK', 374),
(N'HI_BACK', 389),
(N'HI_BACK', 60),
(N'HI_BACK', 65),
(N'HI_BACK', 330),
(N'HI_ARMSHOULDER', 145),
(N'HI_ARMSHOULDER', 337),
(N'HI_ARMSHOULDER', 146),
(N'HI_ARMSHOULDER', 147),
(N'HI_ARMSHOULDER', 338),
(N'HI_ARMSHOULDER', 340),
(N'HI_ARMSHOULDER', 392),
(N'HI_ARMSHOULDER', 354),
(N'HI_ARMSHOULDER', 358),
(N'HI_ARMSHOULDER', 170),
(N'HI_ARMSHOULDER', 360),
(N'HI_ARMSHOULDER', 404),
(N'HI_ARMSHOULDER', 406),
(N'HI_ARMSHOULDER', 368),
(N'HI_ARMSHOULDER', 181),
(N'HI_ARMSHOULDER', 182),
(N'HI_ARMSHOULDER', 183),
(N'HI_ARMSHOULDER', 374),
(N'HI_ARMSHOULDER', 138),
(N'HI_HIP', 202),
(N'HI_HIP', 283),
(N'HI_HIP', 1),
(N'HI_HIP', 2),
(N'HI_HIP', 214),
(N'HI_HIP', 3),
(N'HI_HIP', 222),
(N'HI_HIP', 303),
(N'HI_HIP', 229),
(N'HI_HIP', 233),
(N'HI_HIP', 236),
(N'HI_HIP', 318),
(N'HI_HIP', 263),
(N'HI_KNEE', 283),
(N'HI_KNEE', 284),
(N'HI_KNEE', 211),
(N'HI_KNEE', 215),
(N'HI_KNEE', 300),
(N'HI_KNEE', 94),
(N'HI_KNEE', 303),
(N'HI_KNEE', 230),
(N'HI_KNEE', 304),
(N'HI_KNEE', 311),
(N'HI_KNEE', 315),
(N'HI_KNEE', 318),
(N'HI_KNEE', 325),
(N'HI_KNEE', 326),
(N'HI_KNEE', 327),
(N'HI_POSTINJURY', 144),
(N'HI_POSTINJURY', 378),
(N'HI_POSTINJURY', 145),
(N'HI_POSTINJURY', 146),
(N'HI_POSTINJURY', 147),
(N'HI_POSTINJURY', 201),
(N'HI_POSTINJURY', 339),
(N'HI_POSTINJURY', 283),
(N'HI_POSTINJURY', 153),
(N'HI_POSTINJURY', 163),
(N'HI_POSTINJURY', 223),
(N'HI_POSTINJURY', 297),
(N'HI_POSTINJURY', 298),
(N'HI_POSTINJURY', 170),
(N'HI_POSTINJURY', 94),
(N'HI_POSTINJURY', 303),
(N'HI_POSTINJURY', 172),
(N'HI_POSTINJURY', 235),
(N'HI_POSTINJURY', 178),
(N'HI_POSTINJURY', 312),
(N'HI_POSTINJURY', 368),
(N'HI_POSTINJURY', 54),
(N'HI_POSTINJURY', 319),
(N'HI_POSTINJURY', 181),
(N'HI_POSTINJURY', 182),
(N'HI_POSTINJURY', 183),
(N'HI_POSTINJURY', 374),
(N'HI_POSTINJURY', 243);

INSERT INTO HealthIssueReplacements (IssueCode, ExerciseId) VALUES
(N'HI_ARMSHOULDER', 118),
(N'HI_ARMSHOULDER', 332),
(N'HI_ARMSHOULDER', 342),
(N'HI_ARMSHOULDER', 347),
(N'HI_ARMSHOULDER', 356),
(N'HI_ARMSHOULDER', 362),
(N'HI_ARMSHOULDER', 364),
(N'HI_BACK', 149),
(N'HI_BACK', 158),
(N'HI_BACK', 168),
(N'HI_BACK', 180),
(N'HI_BACK', 198),
(N'HI_BACK', 21),
(N'HI_BACK', 226),
(N'HI_BACK', 305),
(N'HI_BACK', 308),
(N'HI_BACK', 40),
(N'HI_BACK', 51),
(N'HI_HIP', 196),
(N'HI_HIP', 204),
(N'HI_HIP', 226),
(N'HI_HIP', 237),
(N'HI_HIP', 240),
(N'HI_HIP', 293),
(N'HI_HIP', 308),
(N'HI_KNEE', 198),
(N'HI_KNEE', 226),
(N'HI_KNEE', 238),
(N'HI_KNEE', 245),
(N'HI_KNEE', 256),
(N'HI_KNEE', 259),
(N'HI_KNEE', 294),
(N'HI_KNEE', 301),
(N'HI_KNEE', 308),
(N'HI_KNEE', 324);

-- 14.13 Hệ số khối lượng
INSERT INTO VolumeModifiers (Dimension, `MinValue`, `MaxValue`, EnumValue, Multiplier, RampWeeks, AdjustmentNote) VALUES
('Bmi', NULL, 18.49, NULL, 1.00, 0, N'Không mở giáo án Giảm mỡ. Chuyển sang Tăng cơ. Bỏ phần cardio.'),
('Bmi', 18.5, 22.9, NULL, 1.00, 0, N'Không điều chỉnh.'),
('Bmi', 23.0, 24.9, NULL, 1.00, 0, N'Bỏ bài bật nhảy. Cardio ưu tiên đi bộ nghiêng và đạp xe.'),
('Bmi', 25.0, NULL, NULL, 0.70, 0, N'Tuần 1 chỉ tập 2 buổi. Bỏ hẳn bài nhảy và chạy. Ưu tiên bài máy. Thay chống đẩy sàn bằng chống lên bàn.'),
('Age', NULL, 17, NULL, 1.00, 0, N'Không thử tải tối đa. RPE tối đa 8. Ưu tiên bài trọng lượng cơ thể và tạ đơn. Không đặt mục tiêu giảm cân.'),
('Age', 18, 39, NULL, 1.00, 0, N'Không điều chỉnh.'),
('Age', 40, 54, NULL, 1.00, 0, N'Khởi động 8-10 phút thay vì 5. Bỏ bài bật nhảy.'),
('Age', 55, NULL, NULL, 0.85, 0, N'Bỏ bài bật nhảy. Mỗi buổi thêm một bài thăng bằng. Ưu tiên bài máy ở trình độ Người mới.'),
('Activity', NULL, NULL, N'Sedentary', 0.70, 3, N'Bắt đầu ở cận dưới của khoảng set'),
('Activity', NULL, NULL, N'LightActive', 0.85, 2, NULL),
('Activity', NULL, NULL, N'ModerateActive', 1.00, 1, N'Mốc chuẩn'),
('Activity', NULL, NULL, N'VeryActive', 1.10, 0, N'Có thể bắt đầu ở cận trên của khoảng set'),
('Activity', NULL, NULL, N'ExtraActive', 1.15, 0, N'Ưu tiên thêm ngày nghỉ hơn là thêm set');

-- 14.14 Câu 2: mức tạ khởi điểm gợi ý
INSERT INTO StartingLoadHints (ExerciseId, Gender, LoadRange) VALUES
(118, 'Female', N'3-5 kg mỗi tay'),
(118, 'Male', N'7-10 kg mỗi tay'),
(24, 'Female', N'5-7 kg'),
(24, 'Male', N'10-14 kg'),
(352, 'Female', N'2-4 kg mỗi tay'),
(352, 'Male', N'5-8 kg mỗi tay'),
(219, 'Female', N'6-10 kg'),
(219, 'Male', N'12-16 kg'),
(356, 'Female', N'3-5 kg mỗi tay'),
(356, 'Male', N'7-10 kg mỗi tay'),
(249, 'Female', N'6-10 kg'),
(249, 'Male', N'12-18 kg');

-- 14.15 Giáo án mẫu (8)
INSERT INTO ProgramTemplates (ProgramCode, Direction, SessionsPerWeek, SplitName, MinLevel, Description) VALUES
(N'P01', N'BuildMuscle', 3, N'Toàn thân A/B/C', N'Beginner', N'Ba buổi toàn thân, mỗi nhóm cơ được tập 3 lần mỗi tuần. Tải nặng, rep thấp, nghỉ dài. Không có cardio.'),
(N'P02', N'BuildMuscle', 4, N'Thân trên / Thân dưới × 2', N'Beginner', N'Bốn buổi chia trên dưới. Mỗi buổi mở đầu bằng hai bài đa khớp nặng rồi mới đến bài đơn khớp.'),
(N'P03', N'LoseFat', 3, N'Toàn thân A/B/C', N'Beginner', N'Ba buổi toàn thân có ghép cặp đẩy kéo, mỗi buổi kết thúc bằng cardio nhẹ. Phần tạ giữ nguyên để không mất cơ.'),
(N'P04', N'LoseFat', 4, N'Thân trên / Thân dưới × 2', N'Beginner', N'Hai buổi thân trên ghép cặp, hai buổi thân dưới có cardio nối tiếp. Nghỉ ngắn để tăng mật độ buổi tập.'),
(N'P05', N'StayFit', 3, N'Toàn thân A/B/C', N'Beginner', N'Ba buổi toàn thân ngắn dưới 40 phút, không tập tới thất bại, luôn kết thúc bằng giãn cơ. Làm được hoàn toàn tại nhà.'),
(N'P06', N'StayFit', 4, N'Thân trên / Thân dưới × 2', N'Beginner', N'Bốn buổi nhẹ, cân bằng sức mạnh và vận động linh hoạt. Tỉ lệ kéo trên đẩy giữ ít nhất 1,5 trên 1.'),
(N'P07', N'Endurance', 3, N'2 cardio + 1 tạ', N'Beginner', N'Hai buổi cardio (một nhẹ, một ngắt quãng) và một buổi tạ toàn thân để chống chấn thương.'),
(N'P08', N'Endurance', 4, N'2 cardio + 2 tạ', N'Beginner', N'Hai buổi cardio và hai buổi tạ. Buổi tạ thứ hai tập một bên chân để sửa mất cân bằng hai chân.');

-- 14.16 Buổi trong giáo án mẫu (28)
INSERT INTO TemplateSessions (TemplateSessionId, ProgramCode, SessionNo, SessionName, Focus, EstMinutes) VALUES
(1, N'P01', 1, N'Toàn thân A', N'Squat, đẩy ngang, kéo ngang', 55),
(2, N'P01', 2, N'Toàn thân B', N'Gập hông, kéo dọc, đẩy dọc', 55),
(3, N'P01', 3, N'Toàn thân C', N'Duỗi hông, lunge, tay', 55),
(4, N'P02', 1, N'Thân trên — đẩy nhiều', N'Ngực, vai, tay sau', 60),
(5, N'P02', 2, N'Thân dưới', N'Đùi trước, đùi sau, bắp chân', 55),
(6, N'P02', 3, N'Thân trên — kéo nhiều', N'Lưng, vai sau, tay trước', 60),
(7, N'P02', 4, N'Thân dưới', N'Mông, đùi, bắp chân', 55),
(8, N'P03', 1, N'Toàn thân A', N'Ghép cặp đẩy kéo + cardio', 50),
(9, N'P03', 2, N'Toàn thân B', N'Chân và mông + cardio', 50),
(10, N'P03', 3, N'Toàn thân C', N'Ghép cặp đẩy kéo + ngắt quãng', 50),
(11, N'P04', 1, N'Thân trên', N'Ghép cặp đẩy kéo', 45),
(12, N'P04', 2, N'Thân dưới + cardio', N'Chân, mông, đi bộ nghiêng', 55),
(13, N'P04', 3, N'Thân trên', N'Ghép cặp đẩy kéo', 45),
(14, N'P04', 4, N'Thân dưới + ngắt quãng', N'Chân, mông, cardio ngắt quãng', 50),
(15, N'P05', 1, N'Toàn thân A', N'Squat, đẩy, kéo, core', 35),
(16, N'P05', 2, N'Toàn thân B', N'Lunge, đẩy, core, mông', 35),
(17, N'P05', 3, N'Toàn thân C', N'Squat, đẩy, lưng + đi bộ', 40),
(18, N'P06', 1, N'Thân trên', N'Đẩy, kéo, vai sau', 40),
(19, N'P06', 2, N'Thân dưới', N'Chân, mông, core', 40),
(20, N'P06', 3, N'Thân trên', N'Kéo nhiều hơn đẩy', 40),
(21, N'P06', 4, N'Thân dưới + đi bộ', N'Chân một bên, core, cardio nhẹ', 45),
(22, N'P07', 1, N'Cardio nền', N'Cường độ nói chuyện được', 40),
(23, N'P07', 2, N'Tạ toàn thân', N'Chống chấn thương', 40),
(24, N'P07', 3, N'Cardio ngắt quãng', N'Buổi nặng duy nhất trong tuần', 35),
(25, N'P08', 1, N'Cardio nền', N'Cường độ nói chuyện được', 45),
(26, N'P08', 2, N'Tạ toàn thân', N'Chống chấn thương', 40),
(27, N'P08', 3, N'Cardio ngắt quãng', N'Buổi nặng duy nhất trong tuần', 35),
(28, N'P08', 4, N'Tạ chân một bên + core', N'Cân bằng hai chân, ổn định thân', 40);

-- 14.17 Ô bài tập (141) — MovementRoleId là cột lõi
INSERT INTO TemplateSlots (SlotId, TemplateSessionId, SlotNo, MovementRoleId, SlotLabel,
                           BaseSets, RepScheme, RestSeconds, SupersetGroup, T0Warning, Note) VALUES
(1, 1, 1, 17, N'Squat', 4, N'6-8', 120, NULL, NULL, N'Bài nặng, làm đầu buổi khi còn khoẻ'),
(2, 1, 2, 36, N'Đẩy ngang', 4, N'6-8', 120, NULL, NULL, N'Bài nặng thứ hai'),
(3, 1, 3, 14, N'Kéo ngang', 3, N'10-12', 90, NULL, NULL, NULL),
(4, 1, 4, 35, N'Đẩy dọc', 3, N'10-12', 90, NULL, N'Bản T0 thuộc vai trò Đẩy ngang — thư viện tay không có bài Đẩy dọc tương đương', NULL),
(5, 1, 5, 30, N'Đơn khớp tay', 3, N'10-12', 60, NULL, N'Bản T0 thuộc vai trò Kéo ngang — thư viện tay không có bài Đơn khớp tay trước tương đương', N'T0 không có bài cuốn tay riêng, dùng kéo người thay'),
(6, 1, 6, 5, N'Core chống duỗi', 3, N'30 giây', 60, NULL, NULL, N'Kiểu giữ thời gian'),
(7, 2, 1, 12, N'Gập hông', 4, N'6-8', 120, NULL, N'Bản T0 thuộc vai trò Duỗi hông — thư viện tay không có bài Gập hông tương đương', NULL),
(8, 2, 2, 13, N'Kéo dọc', 4, N'6-8', 120, NULL, NULL, NULL),
(9, 2, 3, 36, N'Đẩy ngang nghiêng', 3, N'10-12', 90, NULL, NULL, NULL),
(10, 2, 4, 17, N'Squat phụ', 3, N'10-12', 90, NULL, N'Bản T0 thuộc vai trò Lunge và một chân — thư viện tay không có bài Squat tương đương', NULL),
(11, 2, 5, 29, N'Đơn khớp tay sau', 3, N'10-12', 60, NULL, N'Bản T0 thuộc vai trò Đẩy ngang — thư viện tay không có bài Đơn khớp tay sau tương đương', NULL),
(12, 2, 6, 7, N'Core chống xoay', 3, N'8 mỗi bên', 60, NULL, NULL, NULL),
(13, 3, 1, 9, N'Duỗi hông', 4, N'8-10', 120, NULL, NULL, NULL),
(14, 3, 2, 14, N'Kéo ngang nặng', 4, N'6-8', 120, NULL, NULL, N'Bỏ bài này nếu người dùng khai có vấn đề lưng'),
(15, 3, 3, 15, N'Lunge', 3, N'10-12 mỗi bên', 90, NULL, NULL, NULL),
(16, 3, 4, 19, N'Vai sau', 3, N'12-15', 60, NULL, N'Bản T0 thuộc vai trò Core chống duỗi — thư viện tay không có bài Vai sau tương đương', NULL),
(17, 3, 5, 20, N'Bắp chân', 3, N'12-15', 60, NULL, NULL, NULL),
(18, 3, 6, 30, N'Đơn khớp tay', 3, N'10-12', 60, NULL, N'Bản T0 thuộc vai trò Giãn cơ — thư viện tay không có bài Đơn khớp tay trước tương đương', NULL),
(19, 4, 1, 36, N'Đẩy ngang', 4, N'6-8', 120, NULL, NULL, N'Bài nặng'),
(20, 4, 2, 35, N'Đẩy dọc', 4, N'6-8', 120, NULL, N'Bản T0 thuộc vai trò Đẩy ngang — thư viện tay không có bài Đẩy dọc tương đương', N'Bài nặng'),
(21, 4, 3, 13, N'Kéo dọc', 3, N'10-12', 90, NULL, NULL, NULL),
(22, 4, 4, 36, N'Đẩy ngang nghiêng', 3, N'10-12', 90, NULL, NULL, NULL),
(23, 4, 5, 31, N'Vai bên', 3, N'12-15', 60, NULL, N'Bản T0 thuộc vai trò Đẩy ngang — thư viện tay không có bài Đơn khớp vai bên tương đương', NULL),
(24, 4, 6, 29, N'Tay sau', 3, N'10-12', 60, NULL, N'Bản T0 thuộc vai trò Đẩy ngang — thư viện tay không có bài Đơn khớp tay sau tương đương', NULL),
(25, 5, 1, 17, N'Squat', 4, N'6-8', 120, NULL, NULL, N'Bài nặng'),
(26, 5, 2, 12, N'Gập hông', 4, N'6-8', 120, NULL, N'Bản T0 thuộc vai trò Duỗi hông — thư viện tay không có bài Gập hông tương đương', N'Bài nặng'),
(27, 5, 3, 17, N'Squat phụ', 3, N'10-12', 90, NULL, N'Bản T0 thuộc vai trò Lunge và một chân — thư viện tay không có bài Squat tương đương', NULL),
(28, 5, 4, 33, N'Cuốn chân', 3, N'10-12', 60, NULL, NULL, NULL),
(29, 5, 5, 20, N'Bắp chân', 3, N'12-15', 60, NULL, NULL, NULL),
(30, 6, 1, 14, N'Kéo ngang', 4, N'6-8', 120, NULL, NULL, N'Bỏ nếu có vấn đề lưng'),
(31, 6, 2, 13, N'Kéo dọc', 4, N'6-8', 120, NULL, NULL, NULL),
(32, 6, 3, 36, N'Đẩy ngang nghiêng', 3, N'10-12', 90, NULL, NULL, NULL),
(33, 6, 4, 14, N'Kéo ngang có tựa', 3, N'10-12', 90, NULL, NULL, NULL),
(34, 6, 5, 19, N'Vai sau', 3, N'12-15', 60, NULL, N'Bản T0 thuộc vai trò Core chống duỗi — thư viện tay không có bài Vai sau tương đương', NULL),
(35, 6, 6, 30, N'Tay trước', 3, N'10-12', 60, NULL, N'Bản T0 thuộc vai trò Kéo dọc — thư viện tay không có bài Đơn khớp tay trước tương đương', NULL),
(36, 7, 1, 9, N'Duỗi hông', 4, N'8-10', 120, NULL, NULL, N'Bài nặng'),
(37, 7, 2, 17, N'Squat trước', 4, N'6-8', 120, NULL, NULL, N'Bài nặng'),
(38, 7, 3, 15, N'Lunge', 3, N'10-12 mỗi bên', 90, NULL, NULL, NULL),
(39, 7, 4, 33, N'Cuốn chân', 3, N'10-12', 60, NULL, NULL, NULL),
(40, 7, 5, 20, N'Bắp chân', 3, N'12-15', 60, NULL, NULL, NULL),
(41, 8, 1, 36, N'Đẩy ngang (cặp 1)', 3, N'12-15', 0, 1, NULL, N'Làm xong chuyển ngay sang thứ tự 2'),
(42, 8, 2, 14, N'Kéo ngang (cặp 1)', 3, N'12-15', 60, 1, NULL, N'Nghỉ sau khi xong cả cặp'),
(43, 8, 3, 17, N'Squat (cặp 2)', 3, N'12-15', 0, 2, NULL, NULL),
(44, 8, 4, 9, N'Duỗi hông (cặp 2)', 3, N'12-15', 60, 2, NULL, NULL),
(45, 8, 5, 5, N'Core chống duỗi', 3, N'30 giây', 45, NULL, NULL, NULL),
(46, 8, 6, 4, N'Cardio nhẹ', 1, N'20 phút', 0, NULL, NULL, N'Cường độ nói chuyện được'),
(47, 9, 1, 12, N'Gập hông (cặp 1)', 3, N'12-15', 0, 1, N'Bản T0 thuộc vai trò Duỗi hông — thư viện tay không có bài Gập hông tương đương', NULL),
(48, 9, 2, 13, N'Kéo dọc (cặp 1)', 3, N'12-15', 60, 1, N'Bản T0 thuộc vai trò Kéo ngang — thư viện tay không có bài Kéo dọc tương đương', NULL),
(49, 9, 3, 15, N'Lunge (cặp 2)', 3, N'12 mỗi bên', 0, 2, NULL, NULL),
(50, 9, 4, 35, N'Đẩy dọc (cặp 2)', 3, N'12-15', 60, 2, N'Bản T0 thuộc vai trò Đẩy ngang — thư viện tay không có bài Đẩy dọc tương đương', NULL),
(51, 9, 5, 25, N'Dang chân', 3, N'15', 45, NULL, NULL, NULL),
(52, 9, 6, 4, N'Cardio nhẹ', 1, N'20 phút', 0, NULL, NULL, NULL),
(53, 10, 1, 36, N'Đẩy ngang nghiêng (cặp 1)', 3, N'12-15', 0, 1, NULL, NULL),
(54, 10, 2, 14, N'Kéo ngang (cặp 1)', 3, N'12-15', 60, 1, NULL, NULL),
(55, 10, 3, 17, N'Squat (cặp 2)', 3, N'12-15', 0, 2, NULL, NULL),
(56, 10, 4, 19, N'Vai sau (cặp 2)', 3, N'15', 60, 2, N'Bản T0 thuộc vai trò Core chống duỗi — thư viện tay không có bài Vai sau tương đương', NULL),
(57, 10, 5, 6, N'Core chống nghiêng', 3, N'25 giây mỗi bên', 45, NULL, NULL, NULL),
(58, 10, 6, 3, N'Cardio ngắt quãng', 1, N'8 phút', 0, NULL, N'Bản T0 thuộc vai trò Core chống duỗi — thư viện tay không có bài Cardio ngắt quãng tương đương', N'30 giây tập, 60 giây nghỉ'),
(59, 11, 1, 36, N'Đẩy ngang (cặp 1)', 3, N'12-15', 0, 1, NULL, NULL),
(60, 11, 2, 14, N'Kéo ngang (cặp 1)', 3, N'12-15', 60, 1, NULL, NULL),
(61, 11, 3, 31, N'Vai bên (cặp 2)', 3, N'12-15', 0, 2, N'Bản T0 thuộc vai trò Đẩy ngang — thư viện tay không có bài Đơn khớp vai bên tương đương', NULL),
(62, 11, 4, 29, N'Tay sau (cặp 2)', 3, N'12-15', 60, 2, N'Bản T0 thuộc vai trò Đẩy ngang — thư viện tay không có bài Đơn khớp tay sau tương đương', NULL),
(63, 11, 5, 30, N'Tay trước', 3, N'12-15', 45, NULL, N'Bản T0 thuộc vai trò Kéo ngang — thư viện tay không có bài Đơn khớp tay trước tương đương', NULL),
(64, 11, 6, 5, N'Core chống duỗi', 3, N'30 giây', 45, NULL, NULL, NULL),
(65, 12, 1, 17, N'Squat', 3, N'12-15', 60, NULL, NULL, NULL),
(66, 12, 2, 9, N'Duỗi hông', 3, N'12-15', 60, NULL, NULL, NULL),
(67, 12, 3, 33, N'Cuốn chân', 3, N'12-15', 60, NULL, N'Bản T0 thuộc vai trò Duỗi hông — thư viện tay không có bài Đơn khớp đùi sau tương đương', NULL),
(68, 12, 4, 25, N'Dang chân', 3, N'15', 45, NULL, NULL, NULL),
(69, 12, 5, 4, N'Cardio nhẹ', 1, N'25 phút', 0, NULL, NULL, N'Cường độ nói chuyện được'),
(70, 13, 1, 36, N'Đẩy ngang nghiêng (cặp 1)', 3, N'12-15', 0, 1, NULL, NULL),
(71, 13, 2, 13, N'Kéo dọc (cặp 1)', 3, N'12-15', 60, 1, N'Bản T0 thuộc vai trò Kéo ngang — thư viện tay không có bài Kéo dọc tương đương', NULL),
(72, 13, 3, 19, N'Vai sau (cặp 2)', 3, N'15', 0, 2, N'Bản T0 thuộc vai trò Core chống duỗi — thư viện tay không có bài Vai sau tương đương', NULL),
(73, 13, 4, 29, N'Tay sau (cặp 2)', 3, N'12-15', 60, 2, N'Bản T0 thuộc vai trò Đẩy ngang — thư viện tay không có bài Đơn khớp tay sau tương đương', NULL),
(74, 13, 5, 30, N'Tay trước', 3, N'12-15', 45, NULL, N'Bản T0 thuộc vai trò Kéo ngang — thư viện tay không có bài Đơn khớp tay trước tương đương', NULL),
(75, 13, 6, 6, N'Core chống nghiêng', 3, N'25 giây mỗi bên', 45, NULL, NULL, NULL),
(76, 14, 1, 17, N'Squat', 3, N'12-15', 60, NULL, N'Bản T0 thuộc vai trò Lunge và một chân — thư viện tay không có bài Squat tương đương', NULL),
(77, 14, 2, 12, N'Gập hông', 3, N'12-15', 60, NULL, N'Bản T0 thuộc vai trò Duỗi hông — thư viện tay không có bài Gập hông tương đương', NULL),
(78, 14, 3, 34, N'Duỗi chân', 3, N'12-15', 60, NULL, N'Bản T0 thuộc vai trò Squat — thư viện tay không có bài Đơn khớp đùi trước tương đương', NULL),
(79, 14, 4, 12, N'Gập hông nhanh', 3, N'15', 60, NULL, N'Bản T0 thuộc vai trò Duỗi hông — thư viện tay không có bài Gập hông tương đương', N'Bỏ nếu có vấn đề lưng'),
(80, 14, 5, 3, N'Cardio ngắt quãng', 1, N'10 phút', 0, NULL, N'Bản T0 thuộc vai trò Core chống duỗi — thư viện tay không có bài Cardio ngắt quãng tương đương', N'30 giây tập, 60 giây nghỉ'),
(81, 15, 1, 17, N'Squat', 3, N'10-12', 60, NULL, NULL, N'Không tập tới thất bại'),
(82, 15, 2, 36, N'Đẩy ngang', 3, N'10-12', 60, NULL, NULL, NULL),
(83, 15, 3, 14, N'Kéo ngang', 3, N'10-12', 60, NULL, NULL, NULL),
(84, 15, 4, 9, N'Duỗi hông', 3, N'10-12', 60, NULL, NULL, NULL),
(85, 15, 5, 5, N'Core chống duỗi', 3, N'8 mỗi bên', 45, NULL, NULL, NULL),
(86, 15, 6, 11, N'Giãn cơ', 2, N'30 giây', 0, NULL, NULL, N'Kết thúc buổi'),
(87, 16, 1, 15, N'Lunge', 3, N'10-12 mỗi bên', 60, NULL, NULL, NULL),
(88, 16, 2, 36, N'Đẩy ngang', 3, N'10-12', 60, NULL, NULL, NULL),
(89, 16, 3, 7, N'Core chống xoay', 3, N'8 mỗi bên', 45, NULL, NULL, NULL),
(90, 16, 4, 9, N'Duỗi hông một bên', 3, N'10-12 mỗi bên', 60, NULL, NULL, NULL),
(91, 16, 5, 5, N'Core chống duỗi', 3, N'25 giây', 45, NULL, NULL, NULL),
(92, 16, 6, 11, N'Giãn cơ', 2, N'30 giây', 0, NULL, NULL, NULL),
(93, 17, 1, 17, N'Squat', 3, N'12-15', 60, NULL, NULL, NULL),
(94, 17, 2, 36, N'Đẩy ngang', 3, N'12-15', 60, NULL, NULL, NULL),
(95, 17, 3, 10, N'Duỗi lưng', 3, N'12-15', 60, NULL, N'Bản T0 thuộc vai trò Core chống duỗi — thư viện tay không có bài Duỗi lưng tương đương', NULL),
(96, 17, 4, 25, N'Dang chân', 3, N'15', 45, NULL, NULL, NULL),
(97, 17, 5, 6, N'Core chống nghiêng', 3, N'20 giây mỗi bên', 45, NULL, NULL, NULL),
(98, 17, 6, 4, N'Cardio nhẹ', 1, N'20 phút', 0, NULL, NULL, NULL),
(99, 18, 1, 36, N'Đẩy ngang', 3, N'10-12', 60, NULL, NULL, NULL),
(100, 18, 2, 14, N'Kéo ngang', 3, N'10-12', 60, NULL, NULL, NULL),
(101, 18, 3, 35, N'Đẩy dọc', 3, N'10-12', 60, NULL, N'Bản T0 thuộc vai trò Đẩy ngang — thư viện tay không có bài Đẩy dọc tương đương', NULL),
(102, 18, 4, 13, N'Kéo dọc', 3, N'10-12', 60, NULL, N'Bản T0 thuộc vai trò Kéo ngang — thư viện tay không có bài Kéo dọc tương đương', NULL),
(103, 18, 5, 19, N'Vai sau', 3, N'12-15', 45, NULL, N'Bản T0 thuộc vai trò Core chống duỗi — thư viện tay không có bài Vai sau tương đương', NULL),
(104, 18, 6, 5, N'Core chống duỗi', 3, N'30 giây', 45, NULL, NULL, NULL),
(105, 19, 1, 17, N'Squat', 3, N'10-12', 60, NULL, NULL, NULL),
(106, 19, 2, 12, N'Gập hông', 3, N'10-12', 60, NULL, N'Bản T0 thuộc vai trò Duỗi hông — thư viện tay không có bài Gập hông tương đương', NULL),
(107, 19, 3, 15, N'Lunge', 3, N'10-12 mỗi bên', 60, NULL, NULL, NULL),
(108, 19, 4, 33, N'Cuốn chân', 3, N'10-12', 60, NULL, NULL, NULL),
(109, 19, 5, 20, N'Bắp chân', 3, N'12-15', 45, NULL, NULL, NULL),
(110, 19, 6, 5, N'Core chống xoay', 3, N'8 mỗi bên', 45, NULL, NULL, NULL),
(111, 20, 1, 14, N'Kéo ngang có tựa', 3, N'10-12', 60, NULL, NULL, N'Buổi này kéo nhiều hơn đẩy'),
(112, 20, 2, 13, N'Kéo dọc', 3, N'10-12', 60, NULL, NULL, NULL),
(113, 20, 3, 36, N'Đẩy ngang nghiêng', 3, N'10-12', 60, NULL, NULL, NULL),
(114, 20, 4, 19, N'Vai sau', 3, N'12-15', 45, NULL, N'Bản T0 thuộc vai trò Core chống duỗi — thư viện tay không có bài Vai sau tương đương', NULL),
(115, 20, 5, 19, N'Xoay ngoài vai', 3, N'15 mỗi bên', 45, NULL, N'Bản T0 thuộc vai trò Core chống xoay — thư viện tay không có bài Vai sau tương đương', NULL),
(116, 20, 6, 11, N'Giãn cơ', 2, N'30 giây', 0, NULL, NULL, NULL),
(117, 21, 1, 9, N'Duỗi hông', 3, N'10-12', 60, NULL, NULL, NULL),
(118, 21, 2, 15, N'Lunge một bên', 3, N'10-12 mỗi bên', 60, NULL, NULL, NULL),
(119, 21, 3, 25, N'Dang chân', 3, N'15', 45, NULL, NULL, NULL),
(120, 21, 4, 6, N'Core chống nghiêng', 3, N'25 giây mỗi bên', 45, NULL, NULL, NULL),
(121, 21, 5, 4, N'Cardio nhẹ', 1, N'20 phút', 0, NULL, NULL, NULL),
(122, 22, 1, 4, N'Cardio nền', 1, N'30 phút', 0, NULL, NULL, N'Vẫn nói được nguyên câu khi đang tập'),
(123, 23, 1, 17, N'Squat', 3, N'12-15', 45, NULL, NULL, NULL),
(124, 23, 2, 14, N'Kéo ngang', 3, N'12-15', 45, NULL, NULL, NULL),
(125, 23, 3, 36, N'Đẩy ngang', 3, N'12-15', 45, NULL, NULL, NULL),
(126, 23, 4, 12, N'Gập hông', 3, N'12-15', 45, NULL, N'Bản T0 thuộc vai trò Duỗi hông — thư viện tay không có bài Gập hông tương đương', NULL),
(127, 23, 5, 20, N'Bắp chân một bên', 3, N'15 mỗi bên', 45, NULL, NULL, N'Phòng đau ống đồng'),
(128, 23, 6, 5, N'Core chống duỗi', 3, N'30 giây', 45, NULL, NULL, NULL),
(129, 24, 1, 3, N'Cardio ngắt quãng', 1, N'6 hiệp x 2 phút', 120, NULL, NULL, N'Buổi nặng duy nhất trong tuần'),
(130, 25, 1, 4, N'Cardio nền', 1, N'35 phút', 0, NULL, NULL, N'Vẫn nói được nguyên câu khi đang tập'),
(131, 26, 1, 17, N'Squat', 3, N'12-15', 45, NULL, NULL, NULL),
(132, 26, 2, 14, N'Kéo ngang', 3, N'12-15', 45, NULL, NULL, NULL),
(133, 26, 3, 36, N'Đẩy ngang', 3, N'12-15', 45, NULL, NULL, NULL),
(134, 26, 4, 12, N'Gập hông', 3, N'12-15', 45, NULL, N'Bản T0 thuộc vai trò Duỗi hông — thư viện tay không có bài Gập hông tương đương', NULL),
(135, 26, 5, 5, N'Core chống duỗi', 3, N'30 giây', 45, NULL, NULL, NULL),
(136, 27, 1, 3, N'Cardio ngắt quãng', 1, N'6 hiệp x 2 phút', 120, NULL, NULL, N'Buổi nặng duy nhất trong tuần'),
(137, 28, 1, 15, N'Lunge một bên', 3, N'10-12 mỗi bên', 60, NULL, NULL, N'Sửa mất cân bằng hai chân'),
(138, 28, 2, 9, N'Duỗi hông một bên', 3, N'12 mỗi bên', 60, NULL, NULL, NULL),
(139, 28, 3, 20, N'Bắp chân một bên', 3, N'15 mỗi bên', 45, NULL, NULL, N'Phòng đau ống đồng'),
(140, 28, 4, 7, N'Core chống xoay', 3, N'20 giây mỗi bên', 45, NULL, NULL, NULL),
(141, 28, 5, 6, N'Core chống nghiêng', 3, N'25 giây mỗi bên', 45, NULL, NULL, NULL);

-- 14.18 Bài mặc định cho từng ô (423 = 141 ô x 3 mức dụng cụ)
INSERT INTO SlotDefaultExercises (SlotId, EquipmentTier, ExerciseId) VALUES
(1, N'T2', 279),
(1, N'T1', 219),
(1, N'T0', 282),
(2, N'T2', 100),
(2, N'T1', 118),
(2, N'T0', 133),
(3, N'T2', 40),
(3, N'T1', 24),
(3, N'T0', 28),
(4, N'T2', 356),
(4, N'T1', 356),
(4, N'T0', 127),
(5, N'T2', 81),
(5, N'T1', 74),
(5, N'T0', 28),
(6, N'T2', 168),
(6, N'T1', 168),
(6, N'T0', 168),
(7, N'T2', 245),
(7, N'T1', 249),
(7, N'T0', 240),
(8, N'T2', 62),
(8, N'T1', 10),
(8, N'T0', 23),
(9, N'T2', 103),
(9, N'T1', 122),
(9, N'T0', 127),
(10, N'T2', 308),
(10, N'T1', 215),
(10, N'T0', 206),
(11, N'T2', 395),
(11, N'T1', 400),
(11, N'T0', 133),
(12, N'T2', 149),
(12, N'T1', 149),
(12, N'T0', 149),
(13, N'T2', 198),
(13, N'T1', 232),
(13, N'T0', 226),
(14, N'T2', 12),
(14, N'T1', 29),
(14, N'T0', 28),
(15, N'T2', 284),
(15, N'T1', 215),
(15, N'T0', 206),
(16, N'T2', 347),
(16, N'T1', 333),
(16, N'T0', 184),
(17, N'T2', 96),
(17, N'T1', 92),
(17, N'T0', 91),
(18, N'T2', 75),
(18, N'T1', 75),
(18, N'T0', 189),
(19, N'T2', 100),
(19, N'T1', 118),
(19, N'T0', 133),
(20, N'T2', 337),
(20, N'T1', 356),
(20, N'T0', 127),
(21, N'T2', 62),
(21, N'T1', 10),
(21, N'T0', 23),
(22, N'T2', 122),
(22, N'T1', 122),
(22, N'T0', 127),
(23, N'T2', 352),
(23, N'T1', 352),
(23, N'T0', 127),
(24, N'T2', 395),
(24, N'T1', 400),
(24, N'T0', 105),
(25, N'T2', 279),
(25, N'T1', 291),
(25, N'T0', 282),
(26, N'T2', 245),
(26, N'T1', 249),
(26, N'T0', 240),
(27, N'T2', 308),
(27, N'T1', 215),
(27, N'T0', 206),
(28, N'T2', 259),
(28, N'T1', 251),
(28, N'T0', 257),
(29, N'T2', 96),
(29, N'T1', 95),
(29, N'T0', 91),
(30, N'T2', 12),
(30, N'T1', 24),
(30, N'T0', 28),
(31, N'T2', 35),
(31, N'T1', 6),
(31, N'T0', 23),
(32, N'T2', 103),
(32, N'T1', 122),
(32, N'T0', 127),
(33, N'T2', 22),
(33, N'T1', 21),
(33, N'T0', 28),
(34, N'T2', 347),
(34, N'T1', 333),
(34, N'T0', 184),
(35, N'T2', 81),
(35, N'T1', 76),
(35, N'T0', 23),
(36, N'T2', 198),
(36, N'T1', 232),
(36, N'T0', 226),
(37, N'T2', 296),
(37, N'T1', 219),
(37, N'T0', 204),
(38, N'T2', 284),
(38, N'T1', 215),
(38, N'T0', 206),
(39, N'T2', 256),
(39, N'T1', 251),
(39, N'T0', 257),
(40, N'T2', 93),
(40, N'T1', 92),
(40, N'T0', 97),
(41, N'T2', 130),
(41, N'T1', 118),
(41, N'T0', 127),
(42, N'T2', 40),
(42, N'T1', 24),
(42, N'T0', 28),
(43, N'T2', 308),
(43, N'T1', 219),
(43, N'T0', 282),
(44, N'T2', 238),
(44, N'T1', 232),
(44, N'T0', 226),
(45, N'T2', 168),
(45, N'T1', 168),
(45, N'T0', 168),
(46, N'T2', 301),
(46, N'T1', 299),
(46, N'T0', 299),
(47, N'T2', 210),
(47, N'T1', 197),
(47, N'T0', 240),
(48, N'T2', 34),
(48, N'T1', 10),
(48, N'T0', 28),
(49, N'T2', 284),
(49, N'T1', 215),
(49, N'T0', 206),
(50, N'T2', 365),
(50, N'T1', 356),
(50, N'T0', 127),
(51, N'T2', 237),
(51, N'T1', 196),
(51, N'T0', 205),
(52, N'T2', 324),
(52, N'T1', 299),
(52, N'T0', 299),
(53, N'T2', 126),
(53, N'T1', 122),
(53, N'T0', 127),
(54, N'T2', 37),
(54, N'T1', 9),
(54, N'T0', 28),
(55, N'T2', 305),
(55, N'T1', 219),
(55, N'T0', 204),
(56, N'T2', 364),
(56, N'T1', 333),
(56, N'T0', 184),
(57, N'T2', 167),
(57, N'T1', 167),
(57, N'T0', 167),
(58, N'T2', 48),
(58, N'T1', 94),
(58, N'T0', 179),
(59, N'T2', 130),
(59, N'T1', 118),
(59, N'T0', 127),
(60, N'T2', 40),
(60, N'T1', 24),
(60, N'T0', 28),
(61, N'T2', 352),
(61, N'T1', 352),
(61, N'T0', 127),
(62, N'T2', 395),
(62, N'T1', 401),
(62, N'T0', 105),
(63, N'T2', 70),
(63, N'T1', 74),
(63, N'T0', 28),
(64, N'T2', 168),
(64, N'T1', 168),
(64, N'T0', 168),
(65, N'T2', 308),
(65, N'T1', 219),
(65, N'T0', 282),
(66, N'T2', 238),
(66, N'T1', 232),
(66, N'T0', 226),
(67, N'T2', 256),
(67, N'T1', 251),
(67, N'T0', 240),
(68, N'T2', 237),
(68, N'T1', 196),
(68, N'T0', 205),
(69, N'T2', 301),
(69, N'T1', 299),
(69, N'T0', 299),
(70, N'T2', 126),
(70, N'T1', 122),
(70, N'T0', 127),
(71, N'T2', 34),
(71, N'T1', 10),
(71, N'T0', 28),
(72, N'T2', 364),
(72, N'T1', 333),
(72, N'T0', 184),
(73, N'T2', 405),
(73, N'T1', 399),
(73, N'T0', 105),
(74, N'T2', 75),
(74, N'T1', 75),
(74, N'T0', 28),
(75, N'T2', 167),
(75, N'T1', 167),
(75, N'T0', 167),
(76, N'T2', 305),
(76, N'T1', 219),
(76, N'T0', 206),
(77, N'T2', 210),
(77, N'T1', 197),
(77, N'T0', 240),
(78, N'T2', 307),
(78, N'T1', 215),
(78, N'T0', 204),
(79, N'T2', 234),
(79, N'T1', 234),
(79, N'T0', 226),
(80, N'T2', 48),
(80, N'T1', 94),
(80, N'T0', 179),
(81, N'T2', 219),
(81, N'T1', 219),
(81, N'T0', 282),
(82, N'T2', 130),
(82, N'T1', 118),
(82, N'T0', 127),
(83, N'T2', 40),
(83, N'T1', 24),
(83, N'T0', 28),
(84, N'T2', 238),
(84, N'T1', 232),
(84, N'T0', 226),
(85, N'T2', 158),
(85, N'T1', 158),
(85, N'T0', 158),
(86, N'T2', 140),
(86, N'T1', 140),
(86, N'T0', 140),
(87, N'T2', 284),
(87, N'T1', 215),
(87, N'T0', 206),
(88, N'T2', 126),
(88, N'T1', 122),
(88, N'T0', 105),
(89, N'T2', 149),
(89, N'T1', 149),
(89, N'T0', 149),
(90, N'T2', 238),
(90, N'T1', 240),
(90, N'T0', 240),
(91, N'T2', 168),
(91, N'T1', 168),
(91, N'T0', 168),
(92, N'T2', 142),
(92, N'T1', 142),
(92, N'T0', 142),
(93, N'T2', 308),
(93, N'T1', 219),
(93, N'T0', 204),
(94, N'T2', 130),
(94, N'T1', 118),
(94, N'T0', 127),
(95, N'T2', 266),
(95, N'T1', 184),
(95, N'T0', 184),
(96, N'T2', 237),
(96, N'T1', 196),
(96, N'T0', 205),
(97, N'T2', 167),
(97, N'T1', 167),
(97, N'T0', 167),
(98, N'T2', 301),
(98, N'T1', 299),
(98, N'T0', 299),
(99, N'T2', 130),
(99, N'T1', 118),
(99, N'T0', 127),
(100, N'T2', 40),
(100, N'T1', 24),
(100, N'T0', 28),
(101, N'T2', 356),
(101, N'T1', 356),
(101, N'T0', 127),
(102, N'T2', 34),
(102, N'T1', 10),
(102, N'T0', 28),
(103, N'T2', 364),
(103, N'T1', 333),
(103, N'T0', 184),
(104, N'T2', 168),
(104, N'T1', 168),
(104, N'T0', 168),
(105, N'T2', 219),
(105, N'T1', 219),
(105, N'T0', 282),
(106, N'T2', 245),
(106, N'T1', 249),
(106, N'T0', 240),
(107, N'T2', 284),
(107, N'T1', 215),
(107, N'T0', 206),
(108, N'T2', 256),
(108, N'T1', 251),
(108, N'T0', 257),
(109, N'T2', 96),
(109, N'T1', 92),
(109, N'T0', 91),
(110, N'T2', 158),
(110, N'T1', 158),
(110, N'T0', 158),
(111, N'T2', 22),
(111, N'T1', 21),
(111, N'T0', 28),
(112, N'T2', 44),
(112, N'T1', 7),
(112, N'T0', 23),
(113, N'T2', 126),
(113, N'T1', 122),
(113, N'T0', 105),
(114, N'T2', 369),
(114, N'T1', 353),
(114, N'T0', 184),
(115, N'T2', 342),
(115, N'T1', 332),
(115, N'T0', 149),
(116, N'T2', 141),
(116, N'T1', 141),
(116, N'T0', 141),
(117, N'T2', 238),
(117, N'T1', 232),
(117, N'T0', 226),
(118, N'T2', 284),
(118, N'T1', 293),
(118, N'T0', 206),
(119, N'T2', 237),
(119, N'T1', 196),
(119, N'T0', 205),
(120, N'T2', 167),
(120, N'T1', 167),
(120, N'T0', 167),
(121, N'T2', 301),
(121, N'T1', 299),
(121, N'T0', 299),
(122, N'T2', 304),
(122, N'T1', 324),
(122, N'T0', 299),
(123, N'T2', 219),
(123, N'T1', 219),
(123, N'T0', 282),
(124, N'T2', 40),
(124, N'T1', 24),
(124, N'T0', 28),
(125, N'T2', 118),
(125, N'T1', 118),
(125, N'T0', 133),
(126, N'T2', 245),
(126, N'T1', 249),
(126, N'T0', 240),
(127, N'T2', 97),
(127, N'T1', 92),
(127, N'T0', 97),
(128, N'T2', 168),
(128, N'T1', 168),
(128, N'T0', 168),
(129, N'T2', 315),
(129, N'T1', 286),
(129, N'T0', 94),
(130, N'T2', 304),
(130, N'T1', 324),
(130, N'T0', 299),
(131, N'T2', 219),
(131, N'T1', 219),
(131, N'T0', 282),
(132, N'T2', 40),
(132, N'T1', 24),
(132, N'T0', 28),
(133, N'T2', 118),
(133, N'T1', 118),
(133, N'T0', 133),
(134, N'T2', 245),
(134, N'T1', 249),
(134, N'T0', 240),
(135, N'T2', 168),
(135, N'T1', 168),
(135, N'T0', 168),
(136, N'T2', 315),
(136, N'T1', 286),
(136, N'T0', 94),
(137, N'T2', 284),
(137, N'T1', 215),
(137, N'T0', 206),
(138, N'T2', 240),
(138, N'T1', 240),
(138, N'T0', 240),
(139, N'T2', 97),
(139, N'T1', 92),
(139, N'T0', 97),
(140, N'T2', 180),
(140, N'T1', 180),
(140, N'T0', 149),
(141, N'T2', 167),
(141, N'T1', 167),
(141, N'T0', 167);

-- 14.19 Lộ trình 4 tuần (32)
INSERT INTO TemplateProgression (ProgramCode, WeekNo, VolumePct, SetsMain, SetsAccessory,
                                 LoadRule, CardioPrescription, Instruction) VALUES
(N'P01', 1, N'60-70%', N'3 set', N'2 set', N'Nhẹ hơn mức làm được', N'Không', N'Làm quen động tác. Ghi lại mức tạ của từng bài để cả tháng so sánh.'),
(N'P01', 2, N'85%', N'4 set', N'3 set', N'Giữ nguyên tuần 1', N'Không', N'Giữ nguyên tạ, tăng số lần lặp lên cận trên của khoảng.'),
(N'P01', 3, N'100%', N'4 set', N'3 set', N'Tăng khoảng 5%', N'15 phút đi bộ sau buổi 2', N'Tuần nặng nhất. Tăng tạ. Vẫn phải làm đủ số lần.'),
(N'P01', 4, N'50-60%', N'2 set', N'2 set', N'Giữ nguyên tuần 3', N'Không', N'Giảm tải. Bỏ bớt set, giữ nguyên tạ và số buổi. Đo lại các chỉ số.'),
(N'P02', 1, N'60-70%', N'3 set', N'2 set', N'Nhẹ hơn mức làm được', N'Không', N'Làm quen động tác. Ghi lại mức tạ của từng bài để cả tháng so sánh.'),
(N'P02', 2, N'85%', N'4 set', N'3 set', N'Giữ nguyên tuần 1', N'Không', N'Giữ nguyên tạ, tăng số lần lặp lên cận trên của khoảng.'),
(N'P02', 3, N'100%', N'4 set', N'3 set', N'Tăng khoảng 5%', N'15 phút đi bộ sau buổi 2', N'Tuần nặng nhất. Tăng tạ. Vẫn phải làm đủ số lần.'),
(N'P02', 4, N'50-60%', N'2 set', N'2 set', N'Giữ nguyên tuần 3', N'Không', N'Giảm tải. Bỏ bớt set, giữ nguyên tạ và số buổi. Đo lại các chỉ số.'),
(N'P03', 1, N'60-70%', N'2 set', N'2 set', N'Nhẹ hơn mức làm được', N'15 phút', N'Làm quen động tác. Ghi lại mức tạ của từng bài để cả tháng so sánh.'),
(N'P03', 2, N'85%', N'3 set', N'3 set', N'Giữ nguyên tuần 1', N'20 phút', N'Giữ nguyên tạ, tăng số lần lặp lên cận trên của khoảng.'),
(N'P03', 3, N'100%', N'3 set', N'3 set', N'Tăng khoảng 5%', N'25 phút + 8 phút ngắt quãng', N'Tuần nặng nhất. Tăng tạ. Vẫn phải làm đủ số lần.'),
(N'P03', 4, N'50-60%', N'2 set', N'2 set', N'Giữ nguyên tuần 3', N'20 phút', N'Giảm tải. Bỏ bớt set, giữ nguyên tạ và số buổi. Đo lại các chỉ số.'),
(N'P04', 1, N'60-70%', N'2 set', N'2 set', N'Nhẹ hơn mức làm được', N'15 phút', N'Làm quen động tác. Ghi lại mức tạ của từng bài để cả tháng so sánh.'),
(N'P04', 2, N'85%', N'3 set', N'3 set', N'Giữ nguyên tuần 1', N'20 phút', N'Giữ nguyên tạ, tăng số lần lặp lên cận trên của khoảng.'),
(N'P04', 3, N'100%', N'3 set', N'3 set', N'Tăng khoảng 5%', N'25 phút + 10 phút ngắt quãng', N'Tuần nặng nhất. Tăng tạ. Vẫn phải làm đủ số lần.'),
(N'P04', 4, N'50-60%', N'2 set', N'2 set', N'Giữ nguyên tuần 3', N'20 phút', N'Giảm tải. Bỏ bớt set, giữ nguyên tạ và số buổi. Đo lại các chỉ số.'),
(N'P05', 1, N'60-70%', N'2 set', N'2 set', N'Nhẹ hơn mức làm được', N'15 phút', N'Làm quen động tác. Ghi lại mức tạ của từng bài để cả tháng so sánh.'),
(N'P05', 2, N'85%', N'2 set', N'2 set', N'Giữ nguyên tuần 1', N'20 phút', N'Giữ nguyên tạ, tăng số lần lặp lên cận trên của khoảng.'),
(N'P05', 3, N'100%', N'3 set', N'3 set', N'Tăng khoảng 5%', N'20 phút', N'Tuần nặng nhất. Tăng tạ. Vẫn phải làm đủ số lần.'),
(N'P05', 4, N'50-60%', N'2 set', N'2 set', N'Giữ nguyên tuần 3', N'20 phút', N'Giảm tải. Bỏ bớt set, giữ nguyên tạ và số buổi. Đo lại các chỉ số.'),
(N'P06', 1, N'60-70%', N'2 set', N'2 set', N'Nhẹ hơn mức làm được', N'15 phút', N'Làm quen động tác. Ghi lại mức tạ của từng bài để cả tháng so sánh.'),
(N'P06', 2, N'85%', N'2 set', N'2 set', N'Giữ nguyên tuần 1', N'20 phút', N'Giữ nguyên tạ, tăng số lần lặp lên cận trên của khoảng.'),
(N'P06', 3, N'100%', N'3 set', N'3 set', N'Tăng khoảng 5%', N'20 phút', N'Tuần nặng nhất. Tăng tạ. Vẫn phải làm đủ số lần.'),
(N'P06', 4, N'50-60%', N'2 set', N'2 set', N'Giữ nguyên tuần 3', N'20 phút', N'Giảm tải. Bỏ bớt set, giữ nguyên tạ và số buổi. Đo lại các chỉ số.'),
(N'P07', 1, N'60-70%', N'2 set', N'2 set', N'Nhẹ hơn mức làm được', N'Nền 25 phút · Ngắt quãng 4 hiệp x 1 phút', N'Làm quen động tác. Ghi lại mức tạ của từng bài để cả tháng so sánh.'),
(N'P07', 2, N'85%', N'3 set', N'3 set', N'Giữ nguyên tuần 1', N'Nền 30 phút · Ngắt quãng 5 hiệp x 1 phút', N'Giữ nguyên tạ, tăng số lần lặp lên cận trên của khoảng.'),
(N'P07', 3, N'100%', N'3 set', N'3 set', N'Tăng khoảng 5%', N'Nền 35 phút · Ngắt quãng 6 hiệp x 2 phút', N'Tuần nặng nhất. Tăng tạ. Vẫn phải làm đủ số lần.'),
(N'P07', 4, N'50-60%', N'2 set', N'2 set', N'Giữ nguyên tuần 3', N'Nền 25 phút · Ngắt quãng 4 hiệp x 1 phút', N'Giảm tải. Bỏ bớt set, giữ nguyên tạ và số buổi. Đo lại các chỉ số.'),
(N'P08', 1, N'60-70%', N'2 set', N'2 set', N'Nhẹ hơn mức làm được', N'Nền 25 phút · Ngắt quãng 4 hiệp x 1 phút', N'Làm quen động tác. Ghi lại mức tạ của từng bài để cả tháng so sánh.'),
(N'P08', 2, N'85%', N'3 set', N'3 set', N'Giữ nguyên tuần 1', N'Nền 30 phút · Ngắt quãng 5 hiệp x 1 phút', N'Giữ nguyên tạ, tăng số lần lặp lên cận trên của khoảng.'),
(N'P08', 3, N'100%', N'3 set', N'3 set', N'Tăng khoảng 5%', N'Nền 35 phút · Ngắt quãng 6 hiệp x 2 phút', N'Tuần nặng nhất. Tăng tạ. Vẫn phải làm đủ số lần.'),
(N'P08', 4, N'50-60%', N'2 set', N'2 set', N'Giữ nguyên tuần 3', N'Nền 25 phút · Ngắt quãng 4 hiệp x 1 phút', N'Giảm tải. Bỏ bớt set, giữ nguyên tạ và số buổi. Đo lại các chỉ số.');

-- 14.20 Hỏi đáp mẫu cho trợ lý AI (49)
INSERT INTO AiQaPairs (Category, Question, Answer, SourceTable) VALUES
(N'Giáo án', N'Vì sao giáo án của tôi có bài này?', N'Mỗi ô trong buổi tập được gán sẵn một vai trò vận động — ví dụ đẩy ngang, kéo dọc, gập hông. Bài cụ thể được chọn từ vai trò đó, lọc theo dụng cụ bạn có và trình độ bạn khai. Bạn có thể xem vai trò của từng bài ở cột Vai trò trong giáo án của mình.', N'TemplateSlots'),
(N'Giáo án', N'Tôi có thể đổi bài không?', N'Được, miễn là đổi sang bài cùng vai trò vận động. Mỗi ô trong giáo án có một Vai trò chuẩn, lọc tab 08 theo vai trò đó sẽ ra toàn bộ bài thay thế được, chọn bài hợp với dụng cụ bạn có. Ví dụ ô Duỗi hông có 16 bài để chọn. Đổi sang bài khác vai trò sẽ làm mất cân bằng buổi tập.', N'Exercises'),
(N'Giáo án', N'Có bao nhiêu bài để tôi chọn thay thế?', N'Toàn bộ 406 bài trong thư viện đã được gán vai trò vận động. Tuỳ vai trò mà số lựa chọn khác nhau — Kéo ngang và Đẩy ngang mỗi vai trò có 31 bài, còn Đơn khớp đùi trước chỉ có 2 bài.', N'MovementRoles'),
(N'Giáo án', N'Vì sao bản không dụng cụ của tôi khác hẳn bản phòng gym?', N'Có một số vai trò mà thư viện không có bài tay không tương đương — ví dụ Đẩy dọc, Vai sau, Đơn khớp tay trước đều không có bài nào ở mức không dụng cụ. Với các ô đó, app thay bằng bài gần nhất thuộc vai trò khác và ghi rõ ở cột Cảnh báo bản T0.', N'TemplateSlots'),
(N'Giáo án', N'Vì sao bài tập cả tháng không đổi?', N'Người mới cần lặp lại cùng một động tác nhiều lần thì cơ thể mới học được, và cần cùng một bài thì mới so sánh được tiến bộ. Đổi bài mỗi tuần thì không biết mình có khá hơn hay không. Cái thay đổi là số set, số lần lặp và mức tạ.', N'TemplateProgression'),
(N'Giáo án', N'Tôi tập được bao nhiêu buổi một tuần?', N'App lấy số buổi bạn chọn ở onboarding. Bộ giáo án này có sẵn bản 3 buổi và 4 buổi cho cả bốn mục tiêu. Nếu bạn chọn nhiều hơn, hãy giữ ở mức 4 buổi trong tháng đầu rồi mới tăng.', N'ProgramTemplates'),
(N'Giáo án', N'Buổi tập của tôi kéo dài bao lâu?', N'Tuỳ mục tiêu: Tăng cơ khoảng 55-60 phút, Giảm mỡ 45-55 phút, Giữ dáng 35-40 phút, Tăng sức bền 35-45 phút. Thời lượng dự kiến của từng buổi có trong giáo án.', N'TemplateSessions'),
(N'Giáo án', N'Thứ tự bài tập có quan trọng không?', N'Có. Bài đa khớp nặng luôn xếp đầu buổi khi bạn còn khoẻ, bài đơn khớp xếp cuối. Đổi thứ tự sẽ làm giảm chất lượng bài chính.', N'TemplateSlots'),
(N'Giáo án', N'Superset là gì?', N'Là hai bài làm liền nhau không nghỉ, xong cả cặp mới nghỉ. Trong giáo án Giảm mỡ, các ô ghi cặp 1 hoặc cặp 2 là để ghép như vậy. Mục đích là rút ngắn buổi tập mà không giảm khối lượng.', N'TemplateSlots'),
(N'Mức tạ', N'Tôi nên bắt đầu với bao nhiêu kg?', N'Chọn mức tạ mà bạn làm được đúng số lần yêu cầu và vẫn còn dư khoảng 2-3 lần. Nếu làm xong thấy thừa sức nhiều thì tăng, không đủ số lần thì giảm. Bảng gợi ý mức khởi điểm cho người mới có ở tab hệ số.', N'VolumeModifiers'),
(N'Mức tạ', N'Khi nào tôi nên tăng tạ?', N'Khi bạn hoàn thành đủ số lần ở tất cả các set mà vẫn còn dư sức. Trong tháng đầu, lịch tăng đã định sẵn: tuần 1 và 2 giữ nguyên tạ, tuần 3 mới tăng khoảng 5%, tuần 4 giữ nguyên và giảm set.', N'TemplateProgression'),
(N'Mức tạ', N'Tăng bao nhiêu kg mỗi lần?', N'Bài thân dưới cộng khoảng 2,5 kg, bài thân trên cộng khoảng 1,25 kg. Với tạ đơn thì lên nấc tiếp theo có sẵn. Tăng nhảy vọt sẽ làm hỏng kỹ thuật.', N'TemplateProgression'),
(N'Mức tạ', N'Vì sao tuần đầu không được tăng tạ?', N'Giai đoạn đau nhức nặng nhất của người mới rơi vào tuần 1 và 2. Tăng tạ đúng lúc đó khiến cảm giác là càng tập càng đau, và đây là lý do phổ biến nhất khiến người ta bỏ trong tháng đầu.', N'TemplateProgression'),
(N'Mức tạ', N'Nữ có nên tập tạ nhẹ hơn nam không?', N'Nam và nữ tập cùng bài, cùng số set và số lần lặp, cùng cấu trúc buổi. Chỉ khác con số tạ khởi điểm. Nữ tập tạ nặng không dẫn đến to con vì mức hormone làm to cơ ở nữ thấp hơn nam nhiều lần.', N'VolumeModifiers'),
(N'Dụng cụ', N'Tôi không có dụng cụ gì thì tập được không?', N'Được. Thư viện có khoảng 54 bài chỉ dùng trọng lượng cơ thể, đủ để dựng giáo án toàn thân. Hạn chế duy nhất là gần như không có bài kéo — bạn cần một cái xà đơn, thanh ngang hoặc bàn chắc chắn để làm được phần kéo.', N'GoalDirectionScores'),
(N'Dụng cụ', N'Nên mua dụng cụ gì đầu tiên?', N'Một bộ dây kháng lực. Giá chỉ vài trăm nghìn và mở thêm khoảng 19 bài, quan trọng nhất là mở được phần kéo mà bài trọng lượng cơ thể đang thiếu.', N'GoalDirectionScores'),
(N'Dụng cụ', N'Tôi tập ở nhà, giáo án có khác không?', N'Cấu trúc buổi tập giữ nguyên. Chỉ bài cụ thể trong mỗi ô đổi sang bản tạ đơn hoặc dây kháng lực. Mỗi ô trong giáo án đều có sẵn ba lựa chọn theo ba mức dụng cụ.', N'TemplateSlots'),
(N'Dụng cụ', N'Không có ghế tập thì làm sao?', N'Bài nằm ghế có thể làm trên sàn — ví dụ đẩy ngực với tạ đơn nằm sàn. Biên độ ngắn hơn một chút nhưng vẫn hiệu quả. Bài cần ghế nghiêng có thể thay bằng chống đẩy nghiêng.', N'Exercises'),
(N'Tiến trình', N'Bao lâu thì tôi thấy kết quả?', N'Tuỳ mục tiêu. Sau một tháng: Tăng cơ thường tăng 0,5-1 kg và nâng khá hơn 5-10%. Giảm mỡ thường giảm 1,5-3 kg và vòng eo giảm 2-4 cm. Giữ dáng thì đo bằng số buổi hoàn thành. Tăng sức bền đo bằng quãng đường đi được trong 20 phút.', N'TemplateProgression'),
(N'Tiến trình', N'Tôi nên cân bao nhiêu lần một tuần?', N'Cân 3-4 lần trong tuần rồi lấy trung bình, đừng so theo từng ngày. Cân nặng dao động 1-2 kg trong ngày là bình thường và không phản ánh mỡ.', N'TemplateProgression'),
(N'Tiến trình', N'Tuần 4 vì sao tập nhẹ đi?', N'Đó là tuần giảm tải. Giữ nguyên số buổi và mức tạ nhưng bỏ bớt set để cơ thể hồi phục hoàn toàn, rồi bước vào chu kỳ sau ở mức cao hơn. Bỏ tuần giảm tải thì mệt sẽ tích lại.', N'TemplateProgression'),
(N'Tiến trình', N'Hết tháng thì làm gì tiếp?', N'Lặp lại chu kỳ bốn tuần, lấy mức tạ cuối tháng làm điểm xuất phát mới. Nếu bạn hoàn thành dưới 70% số buổi thì đừng đổi sang giáo án khó hơn — rút số buổi hoặc thời lượng mỗi buổi xuống.', N'TemplateProgression'),
(N'Tiến trình', N'Tôi bỏ lỡ một buổi thì sao?', N'Tập bù vào ngày kế tiếp nếu còn trong tuần, hoặc bỏ qua và tiếp tục theo lịch. Đừng gộp hai buổi vào một ngày.', N'TemplateProgression'),
(N'Cảm giác khi tập', N'Đau nhức sau khi tập có bình thường không?', N'Mỏi và đau nhức cơ trong 24-72 giờ sau buổi tập đầu tiên là bình thường, nhất là tuần 1 và 2. Nó sẽ giảm dần khi cơ thể quen. Nhưng đau nhói, tê bì, hoặc cảm giác lan xuống tay chân thì không bình thường.', N'AiSafetyRules'),
(N'Cảm giác khi tập', N'Tôi thấy đau khi tập một bài, nên làm gì?', N'Dừng bài đó ngay, không cố hoàn thành set. Chuyển sang biến thể nhẹ hơn cùng vai trò vận động. Nếu đau kéo dài quá một tuần hoặc đau tăng lên, bạn nên đi khám bác sĩ hoặc kỹ thuật viên vật lý trị liệu.', N'AiSafetyRules'),
(N'Cảm giác khi tập', N'Thế nào là tập đúng cường độ?', N'Với phần tạ, kết thúc set vẫn còn dư khoảng 2-3 lần lặp. Với cardio nhẹ, bạn vẫn nói được nguyên câu mà không hụt hơi. Với cardio ngắt quãng, trong hiệp thì không nói được nhưng phải hồi kịp để bắt đầu hiệp sau.', N'TemplateProgression'),
(N'Cảm giác khi tập', N'Tôi không thấy đau nhức, có phải tập chưa đủ không?', N'Không. Đau nhức không phải thước đo hiệu quả. Thước đo là bạn có nâng được nặng hơn hoặc nhiều lần hơn so với tuần trước hay không.', N'TemplateProgression'),
(N'Sức khoẻ', N'Tôi đau lưng thì tập được không?', N'Được, nhưng app sẽ loại một số bài khỏi giáo án của bạn — deadlift, kéo tạ đòn cúi người, squat với đòn tạ, và mọi bài gập cột sống có tải. Thay vào đó là bài có tựa và bài core chống chuyển động. Nếu đau kéo dài hoặc lan xuống chân, bạn cần được bác sĩ đánh giá trước.', N'HealthIssueExclusions'),
(N'Sức khoẻ', N'Tôi đau gối thì bỏ hẳn tập chân à?', N'Không. App giữ lại các bài ít tải lên gối như đẩy hông, gập hông, cuốn chân, và đạp đùi biên độ hạn chế. Cái bị loại là bài bật nhảy và các bài chạy có va đập.', N'HealthIssueExclusions'),
(N'Sức khoẻ', N'Tôi vừa khỏi chấn thương, nên bắt đầu thế nào?', N'App hạ toàn bộ giáo án xuống pool bài Người mới trong 4 tuần đầu, giảm khối lượng còn 50-60%, và thêm một ngày nghỉ. Trước khi bắt đầu bạn nên làm việc với kỹ thuật viên vật lý trị liệu.', N'HealthIssueExclusions'),
(N'Sức khoẻ', N'App có thay được bác sĩ không?', N'Không. Giáo án PostureX là chương trình luyện tập thể lực chung, không phải tư vấn y tế. Phần phân tích tư thế bằng camera là công cụ gợi ý, không phải đánh giá y khoa.', N'AiSafetyRules'),
(N'Mục tiêu', N'Tôi muốn giảm mỡ, sao vẫn phải tập tạ?', N'Vì nếu chỉ chạy cardio, cơ thể mất cả mỡ lẫn cơ. Mất cơ làm chuyển hoá chậm lại và cân thường bật lại sau vài tháng. Phần tạ trong giáo án Giảm mỡ là phần giữ cơ, chiếm khoảng một nửa buổi tập.', N'ProgramTemplates'),
(N'Mục tiêu', N'Tôi tập tăng cơ mà không lên cân?', N'Nếu bạn tập đủ 4 tuần theo đúng giáo án mà cân không nhúc nhích, vấn đề gần như luôn nằm ở lượng ăn vào chứ không phải ở bài tập. Đổi giáo án sẽ không giải quyết được. Bạn có thể cần trao đổi với chuyên gia dinh dưỡng.', N'ProgramTemplates'),
(N'Mục tiêu', N'Tôi có thể vừa tăng cơ vừa giảm mỡ không?', N'Người mới trong vài tháng đầu thì có thể ở mức độ nào đó. Nhưng app chỉ chọn một hướng chính để giáo án nhất quán. Hướng được chọn dựa trên mục tiêu bạn khai và chênh lệch giữa cân nặng hiện tại và cân nặng mục tiêu.', N'GoalDirectionScores'),
(N'Mục tiêu', N'Vì sao app chọn hướng này cho tôi?', N'App chấm điểm các mục tiêu bạn chọn, cộng thêm điểm từ chênh lệch cân nặng, rồi lấy hướng có điểm cao nhất. Bạn có thể đổi thủ công trong phần cài đặt.', N'GoalDirectionScores'),
(N'Mục tiêu', N'Tôi chọn mục tiêu sửa tư thế thì giáo án khác gì?', N'Tỉ lệ bài kéo nhiều gấp đôi bài đẩy, core tập theo hướng giữ vững cột sống thay vì gập bụng, và mỗi buổi có ít nhất một bài duỗi hông. Không có bài gập cột sống có tải trong tám tuần đầu.', N'ProgramTemplates'),
(N'Lịch tập', N'Tôi nên tập vào những ngày nào?', N'Rải đều trong tuần. Với 3 buổi thì Hai, Tư, Sáu là hợp lý. Với 4 buổi thì Hai, Ba, nghỉ, Năm, Sáu. Không nên tập quá hai ngày liên tiếp nếu bạn là người mới.', N'UserProfiles'),
(N'Lịch tập', N'Tôi chỉ rảnh cuối tuần thì sao?', N'Dồn ba buổi vào Sáu, Bảy, Chủ Nhật rồi nghỉ bốn ngày là không tốt cho hồi phục. Nếu thực sự chỉ rảnh cuối tuần, hãy chọn 2 buổi mỗi tuần cách nhau ít nhất một ngày thay vì cố nhồi ba buổi.', N'UserProfiles'),
(N'Lịch tập', N'Hai buổi cùng nhóm cơ cần cách nhau bao lâu?', N'Ít nhất 48 giờ. Đây là lý do khung Thân trên và Thân dưới xếp xen kẽ chứ không tập hai buổi thân trên liền nhau.', N'TemplateSessions'),
(N'Lịch tập', N'Tập buổi sáng hay buổi tối tốt hơn?', N'Không có khác biệt đáng kể về kết quả. Giờ tốt nhất là giờ bạn duy trì được đều đặn.', NULL),
(N'Cardio', N'Cardio bao nhiêu là đủ?', N'Tuỳ mục tiêu. Tăng cơ gần như không cần. Giảm mỡ khoảng 20-25 phút sau buổi tạ, cộng một buổi ngắt quãng mỗi tuần. Tăng sức bền thì cardio là phần chính, với một buổi nhẹ dài và một buổi ngắt quãng.', N'ProgramTemplates'),
(N'Cardio', N'Nên cardio trước hay sau tập tạ?', N'Sau. Nếu cardio trước, bạn sẽ mệt và phần tạ kém chất lượng — mà phần tạ mới là phần giữ cơ.', N'TemplateSlots'),
(N'Cardio', N'Cardio ngắt quãng là gì?', N'Là tập nhanh trong một khoảng ngắn rồi nghỉ, lặp lại nhiều hiệp. Ví dụ 30 giây nhảy dây rồi nghỉ 60 giây, làm 8 lần. Cường độ cao nên tối đa một buổi mỗi tuần.', N'TemplateSlots'),
(N'Cardio', N'Tôi bị đau ống đồng khi chạy?', N'Thường liên quan đến cơ mông và bắp chân yếu, cộng với chạy quá nhiều ở cường độ trung bình. Giáo án Tăng sức bền có một buổi tập chân một bên để xử lý đúng việc này. Trước mắt hãy chuyển buổi cardio nhẹ sang đạp xe hoặc máy đi bộ trên không.', N'ProgramTemplates'),
(N'Ăn uống', N'App có cho tôi thực đơn không?', N'Không. PostureX là ứng dụng luyện tập, không tư vấn dinh dưỡng. Nếu bạn cần kế hoạch ăn uống cụ thể, hãy trao đổi với chuyên gia dinh dưỡng.', NULL),
(N'Ăn uống', N'Nên ăn gì trước khi tập?', N'Một bữa nhẹ dễ tiêu trước khoảng 1-2 giờ là đủ với hầu hết mọi người. Chi tiết hơn thì nên hỏi chuyên gia dinh dưỡng.', NULL),
(N'Phân tích tư thế', N'Camera chấm điểm tư thế của tôi thế nào?', N'App đo góc giữa các khớp và so với khoảng chuẩn của từng bài. Không phải bài nào cũng có — hiện chỉ các bài mà camera một góc nhìn rõ khớp mới bật được. Bạn xem cột Camera trong danh sách bài tập.', N'Exercises'),
(N'Phân tích tư thế', N'Vì sao bài này không có chấm điểm tư thế?', N'Có ba trường hợp: bài nằm trong máy hoặc trên ghế nên thân người bị che, bài cardio không có động tác lặp rõ ràng, và bài kỹ thuật cao tốc độ nhanh như nhóm cử tạ Olympic mà mô hình bám khớp không đủ ổn định.', N'Exercises'),
(N'Phân tích tư thế', N'Tuần đầu sao không thấy điểm?', N'Trong tuần 1 và 2, app chỉ hướng dẫn chứ không chấm điểm. Chấm điểm quá sớm khi bạn còn đang học động tác dễ gây nản.', N'TemplateProgression');

-- 14.21 Ràng buộc an toàn cho trợ lý AI
INSERT INTO AiSafetyRules (RuleType, Situation, RequiredBehaviour, IsBlocking) VALUES
(N'ChanNhapLieu', N'Cân nặng mục tiêu cho ra chỉ số cơ thể dưới 18,5', N'Không cho chọn. Hiển thị khoảng cân nặng tương ứng chỉ số 18,5 đến 22,9 cho chiều cao đã khai.', 1),
(N'ChanNhapLieu', N'Người dùng dưới 18 tuổi', N'Không thu thập mục tiêu cân nặng. Không mở giáo án Giảm mỡ. Không thử tải tối đa.', 1),
(N'ChanNhapLieu', N'Chọn quá 2 ngày tập liên tiếp ở trình độ Người mới', N'Không cho chọn. Hiển thị gợi ý rải đều kèm nút áp dụng nhanh.', 1),
(N'ChanSinhGiaoAn', N'Trình độ Người mới chọn từ 6 buổi mỗi tuần', N'Trần là 5 buổi trong 12 tuần đầu.', 1),
(N'ChanSinhGiaoAn', N'Chỉ số cơ thể từ 25,0 trở lên', N'Tuần 1 chỉ 2 buổi. Bỏ hoàn toàn bài bật nhảy và bài chạy. Cardio chỉ dùng loại không va đập.', 1),
(N'ChanSinhGiaoAn', N'Chọn HI_POSTINJURY hoặc từ 3 vấn đề sức khoẻ trở lên', N'Hạ toàn bộ giáo án xuống pool Người mới. Khuyến nghị làm việc với kỹ thuật viên vật lý trị liệu.', 1),
(N'TrongLucTap', N'Người dùng báo đau nhói, tê bì, lan xuống tay chân, chóng mặt, đau tức ngực, khó thở', N'Yêu cầu dừng tập ngay. Không gợi ý giảm nhẹ rồi tập tiếp. Khuyến nghị đi khám.', 1),
(N'TrongLucTap', N'Người dùng báo đau tăng hai tuần liên tiếp', N'Tự động hạ khối lượng. Khuyến nghị gặp bác sĩ hoặc kỹ thuật viên vật lý trị liệu.', 1),
(N'NgonNguAI', N'Nói về kết quả phân tích tư thế', N'Diễn đạt như gợi ý kỹ thuật. KHÔNG dùng ngôn ngữ chẩn đoán.', 1),
(N'NgonNguAI', N'Nói về cơn đau', N'KHÔNG dùng ngôn ngữ khuyến khích vượt qua cơn đau hay cố thêm một set.', 1),
(N'NgonNguAI', N'Người dùng hỏi về ăn uống, thực đơn, lượng calo', N'Nói rõ app không tư vấn dinh dưỡng và hướng đến chuyên gia dinh dưỡng. Không đưa con số calo hay thực đơn.', 1),
(N'NgonNguAI', N'Người dùng muốn giảm cân nhanh hơn mức an toàn', N'Nêu tốc độ an toàn khoảng 0,5 đến 1% trọng lượng cơ thể mỗi tuần. Không thiết kế giáo án đáp ứng mục tiêu nhanh hơn.', 1),
(N'NgonNguAI', N'Người dùng hỏi điều nằm ngoài dữ liệu trong database', N'Nói rõ là chưa có thông tin thay vì suy đoán. Câu hỏi y tế thì hướng đến bác sĩ.', 1),
(N'HienThiBatBuoc', N'Màn hình kết thúc onboarding, trước khi hiện giáo án đầu tiên', N'Giáo án PostureX được xây dựng từ thông tin bạn cung cấp và là chương trình luyện tập thể lực chung, không phải tư vấn y tế. Nếu bạn đang có bệnh lý, đang mang thai, đang hồi phục sau chấn thương, hoặc thấy đau bất thường khi tập, hãy dừng lại và trao đổi với bác sĩ hoặc kỹ thuật viên vật lý trị liệu.', 1);

/* =====================================================================
   15. CÒN PHẢI LÀM TAY
   ---------------------------------------------------------------------
   1. Exercises.Difficulty / SpineLoad / Impact đang NULL cho 412 bài của v2.
      Không suy được từ tên file, phải xem video. SpineLoad là cột mà bộ lọc
      đau lưng dựa vào nên ưu tiên gán trước.
   2. Exercises.DemoVideoUrl / ThumbnailUrl — chạy
      scripts/import_exercise_videos.py để điền. Script khớp bài theo Name,
      và Name trong file này đã theo đúng quy tắc của script nên sẽ UPDATE
      chứ không tạo trùng.
   3. Exercises.Met — mới có cho 6 bài kế thừa từ bản gốc.
   4. ExercisePostureRules: chạy scripts/seed_posture_rules.py để nạp ngưỡng
      theo khoá máy. PostureErrorTypes mới có cho Squat và Push-up.
   5. ExerciseMuscleGroups hiện chủ yếu có nhóm cơ chính.
   6. HealthIssueExclusions sinh bằng khớp mẫu tên file, rà lại bằng mắt
      trước khi lên production.
   7. Exercises.SupportsAnalysis chưa khớp với ANALYZER_REGISTRY — API đang
      tính cờ này từ registry chứ không đọc cột, nên cột chỉ để tham khảo.
   ===================================================================== */

SELECT '>>> Database PostureX (poturex123) da tao xong: 55 bang, 417 bai tap, 8 giao an mau, 141 o bai tap.' AS Message;
