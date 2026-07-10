/* =====================================================================
   POSTURE X  -  AI Real-time Posture Correction App
   MySQL database creation script
   ---------------------------------------------------------------------
   Adapted from the user's original PostureX123.sql for use with the
   FastAPI backend. Changes made vs. the original:
     - Database name lowercased to `poturex123` (matches .env DB_NAME;
       MySQL on this host has lower_case_table_names=1, so the original
       `PotureX123` folds to the same name anyway — made explicit here).
     - Users.PasswordHash / PasswordSalt changed from VARBINARY to
       VARCHAR so they can hold a bcrypt hash string (passlib/bcrypt
       produces ASCII text, not raw binary).
     - `CREATE OR ALTER VIEW` (not valid MySQL syntax) fixed to
       `CREATE OR REPLACE VIEW`.
     - Section 10.3/10.3b (demo admin/user seeded with raw SHA-256
       hashes) removed — the backend now creates accounts via bcrypt
       through the app's own register/create_admin flow instead.
   ===================================================================== */

/* ---------------------------------------------------------------------
   0. TẠO DATABASE
   --------------------------------------------------------------------- */
DROP DATABASE IF EXISTS poturex123;
CREATE DATABASE poturex123 CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE poturex123;

/* =====================================================================
   1. NHÓM TÀI KHOẢN & PHÂN QUYỀN
   ===================================================================== */

-- 1.1 Vai trò: Admin / User
CREATE TABLE Roles
(
    RoleId      INT          AUTO_INCREMENT PRIMARY KEY,
    RoleName    VARCHAR(50)  NOT NULL,
    Description VARCHAR(255) NULL,
    CONSTRAINT UQ_Roles_RoleName UNIQUE (RoleName)
);

-- 1.2 Tài khoản người dùng (cả admin lẫn user thường)
CREATE TABLE Users
(
    UserId          INT            AUTO_INCREMENT PRIMARY KEY,
    RoleId          INT            NOT NULL,
    Username        VARCHAR(50)    NOT NULL,
    Email           VARCHAR(256)   NOT NULL,
    PhoneNumber     VARCHAR(20)    NULL,
    PasswordHash    VARCHAR(255)   NOT NULL,   -- bcrypt hash (ASCII text)
    PasswordSalt    VARCHAR(255)   NULL,       -- không dùng — bcrypt tự chứa salt
    FullName        VARCHAR(100)   NULL,
    IsEmailVerified TINYINT(1)     NOT NULL DEFAULT 0,
    IsActive        TINYINT(1)     NOT NULL DEFAULT 1,
    RegisteredAt    DATETIME       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    LastLoginAt     DATETIME       NULL,

    CONSTRAINT FK_Users_Roles FOREIGN KEY (RoleId) REFERENCES Roles(RoleId),
    CONSTRAINT UQ_Users_Username UNIQUE (Username),
    CONSTRAINT UQ_Users_Email    UNIQUE (Email)
);

-- 1.3 Hồ sơ thể chất của người dùng (1-1 với Users)
CREATE TABLE UserProfiles
(
    UserId       INT          NOT NULL PRIMARY KEY,
    DateOfBirth  DATE         NULL,
    Gender       VARCHAR(10)  NULL,             -- Male / Female / Other
    HeightCm     DECIMAL(5,2) NULL,
    WeightKg     DECIMAL(5,2) NULL,
    FitnessLevel VARCHAR(20)  NULL,             -- Beginner / Intermediate / Advanced
    AvatarUrl    VARCHAR(500) NULL,
    Bio          VARCHAR(500) NULL,
    UpdatedAt    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    CONSTRAINT FK_UserProfiles_Users FOREIGN KEY (UserId) REFERENCES Users(UserId) ON DELETE CASCADE,
    CONSTRAINT CK_UserProfiles_Gender CHECK (Gender IN ('Male', 'Female', 'Other')),
    CONSTRAINT CK_UserProfiles_Level  CHECK (FitnessLevel IN ('Beginner', 'Intermediate', 'Advanced'))
);

-- 1.4 Thiết bị người dùng (camera / điện thoại)
CREATE TABLE Devices
(
    DeviceId    INT          AUTO_INCREMENT PRIMARY KEY,
    UserId      INT          NOT NULL,
    DeviceName  VARCHAR(100) NULL,
    Platform    VARCHAR(20)  NULL,              -- iOS / Android / Web
    OsVersion   VARCHAR(30)  NULL,
    AppVersion  VARCHAR(30)  NULL,
    PushToken   VARCHAR(500) NULL,
    LastUsedAt  DATETIME     NULL,
    CreatedAt   DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT FK_Devices_Users FOREIGN KEY (UserId) REFERENCES Users(UserId) ON DELETE CASCADE,
    CONSTRAINT CK_Devices_Platform CHECK (Platform IN ('iOS', 'Android', 'Web'))
);

-- 1.5 Cấu hình cá nhân (chế độ riêng tư, ngôn ngữ, kiểu phản hồi...)
CREATE TABLE UserSettings
(
    UserId            INT         NOT NULL PRIMARY KEY,
    Language          VARCHAR(10) NOT NULL DEFAULT 'vi',
    VoiceFeedback     TINYINT(1)  NOT NULL DEFAULT 1, -- bật phản hồi giọng nói
    SoundFeedback     TINYINT(1)  NOT NULL DEFAULT 1,
    VibrationFeedback TINYINT(1)  NOT NULL DEFAULT 1,
    PrivacyMode       TINYINT(1)  NOT NULL DEFAULT 0, -- không lưu video
    DailyReminderTime TIME        NULL,
    UpdatedAt         DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    CONSTRAINT FK_UserSettings_Users FOREIGN KEY (UserId) REFERENCES Users(UserId) ON DELETE CASCADE
);

/* =====================================================================
   2. THƯ VIỆN BÀI TẬP & LUẬT TƯ THẾ (dữ liệu cho AI chấm)
   ===================================================================== */

-- 2.1 Nhóm cơ
CREATE TABLE MuscleGroups
(
    MuscleGroupId INT          AUTO_INCREMENT PRIMARY KEY,
    Name          VARCHAR(50)  NOT NULL,
    CONSTRAINT UQ_MuscleGroups_Name UNIQUE (Name)
);

-- 2.2 Bài tập
CREATE TABLE Exercises
(
    ExerciseId   INT           AUTO_INCREMENT PRIMARY KEY,
    Name         VARCHAR(100)  NOT NULL,
    Description  VARCHAR(1000) NULL,
    Category     VARCHAR(50)   NULL,           -- Strength / Cardio / Yoga / Mobility
    Difficulty   VARCHAR(20)   NULL,           -- Beginner / Intermediate / Advanced
    ExerciseType VARCHAR(20)   NOT NULL DEFAULT 'Standard', -- Standard (đếm rep) / Duration (giữ tư thế)
    DemoVideoUrl VARCHAR(500)  NULL,
    ThumbnailUrl VARCHAR(500)  NULL,
    Met          DECIMAL(4,2)  NULL,           -- chỉ số trao đổi chất để ước tính calo
    IsActive     TINYINT(1)    NOT NULL DEFAULT 1,
    CreatedAt    DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT UQ_Exercises_Name UNIQUE (Name),
    CONSTRAINT CK_Exercises_Difficulty CHECK (Difficulty IN ('Beginner', 'Intermediate', 'Advanced')),
    CONSTRAINT CK_Exercises_Type CHECK (ExerciseType IN ('Standard', 'Duration'))
);

-- 2.3 Bài tập <-> Nhóm cơ (nhiều - nhiều)
CREATE TABLE ExerciseMuscleGroups
(
    ExerciseId    INT        NOT NULL,
    MuscleGroupId INT        NOT NULL,
    IsPrimary     TINYINT(1) NOT NULL DEFAULT 0,

    CONSTRAINT PK_ExerciseMuscleGroups PRIMARY KEY (ExerciseId, MuscleGroupId),
    CONSTRAINT FK_ExMuscle_Exercise FOREIGN KEY (ExerciseId)    REFERENCES Exercises(ExerciseId)    ON DELETE CASCADE,
    CONSTRAINT FK_ExMuscle_Muscle   FOREIGN KEY (MuscleGroupId) REFERENCES MuscleGroups(MuscleGroupId) ON DELETE CASCADE
);

-- 2.4 LUẬT GÓC KHỚP của từng bài tập
CREATE TABLE ExercisePostureRules
(
    RuleId        INT          AUTO_INCREMENT PRIMARY KEY,
    ExerciseId    INT          NOT NULL,
    RuleName      VARCHAR(80)  NOT NULL,        -- vd: "Góc đầu gối khi squat"
    JointA        VARCHAR(40)  NOT NULL,        -- vd: Hip
    JointB        VARCHAR(40)  NOT NULL,        -- vd: Knee (đỉnh góc)
    JointC        VARCHAR(40)  NOT NULL,        -- vd: Ankle
    MinAngle      DECIMAL(5,2) NULL,            -- ngưỡng dưới chấp nhận được
    MaxAngle      DECIMAL(5,2) NULL,            -- ngưỡng trên chấp nhận được
    TargetAngle   DECIMAL(5,2) NULL,            -- góc lý tưởng
    IsRepTrigger  TINYINT(1)   NOT NULL DEFAULT 0, -- góc này dùng để đếm rep
    Tolerance     DECIMAL(5,2) NULL,            -- dung sai cho phép

    CONSTRAINT FK_PostureRules_Exercise FOREIGN KEY (ExerciseId) REFERENCES Exercises(ExerciseId) ON DELETE CASCADE
);

-- 2.5 DANH MỤC LỖI TƯ THẾ phổ biến cho từng bài
CREATE TABLE PostureErrorTypes
(
    ErrorTypeId   INT           AUTO_INCREMENT PRIMARY KEY,
    ExerciseId    INT           NULL,          -- NULL = lỗi áp dụng chung
    ErrorCode     VARCHAR(50)   NOT NULL,      -- vd: KNEE_VALGUS
    ErrorName     VARCHAR(150)  NOT NULL,      -- vd: "Đầu gối đổ vào trong"
    Severity      VARCHAR(20)   NOT NULL DEFAULT 'Medium', -- Low / Medium / High
    CorrectionTip VARCHAR(500)  NULL,          -- lời khuyên sửa lỗi
    VoicePrompt   VARCHAR(255)  NULL,          -- câu AI đọc lên khi phát hiện lỗi

    CONSTRAINT FK_ErrorTypes_Exercise FOREIGN KEY (ExerciseId) REFERENCES Exercises(ExerciseId),
    CONSTRAINT UQ_ErrorTypes_Code UNIQUE (ErrorCode),
    CONSTRAINT CK_ErrorTypes_Severity CHECK (Severity IN ('Low', 'Medium', 'High'))
);

/* =====================================================================
   3. KẾ HOẠCH / CHƯƠNG TRÌNH TẬP
   ===================================================================== */

-- 3.1 Chương trình tập
CREATE TABLE WorkoutPlans
(
    PlanId       INT           AUTO_INCREMENT PRIMARY KEY,
    UserId       INT           NULL,            -- NULL = plan mẫu hệ thống
    Name         VARCHAR(120)  NOT NULL,
    Description  VARCHAR(1000) NULL,
    Goal         VARCHAR(50)   NULL,            -- WeightLoss / Strength / Posture / Flexibility
    DurationDays INT           NULL,
    IsSystemPlan TINYINT(1)    NOT NULL DEFAULT 0,
    CreatedAt    DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT FK_WorkoutPlans_Users FOREIGN KEY (UserId) REFERENCES Users(UserId)
);

-- 3.2 Chi tiết bài tập trong chương trình
CREATE TABLE WorkoutPlanExercises
(
    PlanExerciseId    INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    PlanId            INT NOT NULL,
    ExerciseId        INT NOT NULL,
    DayNumber         INT NULL,
    OrderIndex        INT NULL,
    TargetSets        INT NULL,
    TargetReps        INT NULL,
    TargetDurationSec INT NULL,
    RestSeconds       INT NULL,

    CONSTRAINT FK_PlanExercises_Plan     FOREIGN KEY (PlanId)     REFERENCES WorkoutPlans(PlanId) ON DELETE CASCADE,
    CONSTRAINT FK_PlanExercises_Exercise FOREIGN KEY (ExerciseId) REFERENCES Exercises(ExerciseId)
);

/* =====================================================================
   4. BUỔI TẬP & DỮ LIỆU THỜI GIAN THỰC  (lõi của ứng dụng)
   ===================================================================== */

-- 4.1 Buổi tập
CREATE TABLE WorkoutSessions
(
    SessionId        INT          AUTO_INCREMENT PRIMARY KEY,
    UserId           INT          NOT NULL,
    PlanId           INT          NULL,
    DeviceId         INT          NULL,
    StartedAt        DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    EndedAt          DATETIME     NULL,
    Status           VARCHAR(20)  NOT NULL DEFAULT 'InProgress', -- InProgress / Completed / Discarded
    TotalDurationSec INT          NULL,
    CaloriesBurned   DECIMAL(7,2) NULL,
    OverallFormScore DECIMAL(5,2) NULL,       -- điểm form trung bình toàn buổi (0-100)
    Notes            VARCHAR(500) NULL,

    CONSTRAINT FK_WorkoutSessions_Users   FOREIGN KEY (UserId)   REFERENCES Users(UserId) ON DELETE CASCADE,
    CONSTRAINT FK_WorkoutSessions_Plans   FOREIGN KEY (PlanId)   REFERENCES WorkoutPlans(PlanId),
    CONSTRAINT FK_WorkoutSessions_Devices FOREIGN KEY (DeviceId) REFERENCES Devices(DeviceId),
    CONSTRAINT CK_Sessions_Status   CHECK (Status IN ('InProgress', 'Completed', 'Discarded')),
    CONSTRAINT CK_Sessions_FormScore CHECK (OverallFormScore BETWEEN 0 AND 100)
);

-- 4.2 Từng "set"/bài tập trong buổi
CREATE TABLE SessionExercises
(
    SessionExerciseId INT          AUTO_INCREMENT PRIMARY KEY,
    SessionId         INT          NOT NULL,
    ExerciseId        INT          NOT NULL,
    OrderIndex        INT          NULL,
    TotalReps         INT          NOT NULL DEFAULT 0,
    CleanReps         INT          NOT NULL DEFAULT 0, -- rep không lỗi
    DurationSec       INT          NULL,
    FormScore         DECIMAL(5,2) NULL,        -- điểm form của riêng bài này (0-100)
    WeightKg          DECIMAL(6,2) NULL,        -- tạ sử dụng (nếu có)

    CONSTRAINT FK_SessionEx_Session  FOREIGN KEY (SessionId)  REFERENCES WorkoutSessions(SessionId) ON DELETE CASCADE,
    CONSTRAINT FK_SessionEx_Exercise FOREIGN KEY (ExerciseId) REFERENCES Exercises(ExerciseId),
    CONSTRAINT CK_SessionEx_FormScore CHECK (FormScore BETWEEN 0 AND 100)
);

-- 4.3 Chi tiết TỪNG REP
CREATE TABLE SessionReps
(
    RepId             BIGINT       AUTO_INCREMENT PRIMARY KEY,
    SessionExerciseId INT          NOT NULL,
    RepNumber         INT          NOT NULL,
    IsClean           TINYINT(1)   NOT NULL DEFAULT 1, -- rep sạch lỗi?
    FormScore         DECIMAL(5,2) NULL,
    PeakAngle         DECIMAL(5,2) NULL,        -- góc sâu nhất đạt được trong rep
    RangeOfMotion     DECIMAL(5,2) NULL,        -- biên độ chuyển động (ROM)
    TempoSec          DECIMAL(5,2) NULL,        -- thời gian thực hiện rep
    RecordedAt        DATETIME(3)  NOT NULL DEFAULT CURRENT_TIMESTAMP(3),

    CONSTRAINT FK_Reps_SessionExercise FOREIGN KEY (SessionExerciseId) REFERENCES SessionExercises(SessionExerciseId) ON DELETE CASCADE,
    CONSTRAINT CK_Reps_FormScore CHECK (FormScore BETWEEN 0 AND 100)
);

-- 4.4 PHẢN HỒI THỜI GIAN THỰC
CREATE TABLE RealtimeFeedback
(
    FeedbackId        BIGINT        AUTO_INCREMENT PRIMARY KEY,
    SessionExerciseId INT           NOT NULL,
    RepId             BIGINT        NULL,        -- gắn với rep nào (nếu xác định được)
    ErrorTypeId       INT           NULL,        -- loại lỗi phát hiện
    OccurredAt        DATETIME(3)   NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    ElapsedMs         INT           NULL,        -- mốc thời gian tính từ đầu bài (ms)
    FeedbackType      VARCHAR(20)   NOT NULL DEFAULT 'Error', -- Error / Warning / Correction / Praise
    MeasuredAngle     DECIMAL(5,2)  NULL,        -- góc thực tế đo được khi lỗi
    DeviationDegrees  DECIMAL(5,2)  NULL,        -- lệch bao nhiêu độ so với chuẩn
    Channel           VARCHAR(20)   NULL,        -- Voice / Visual / Vibration / Text
    Message           VARCHAR(500)  NULL,        -- nội dung hiển thị / đọc cho user

    CONSTRAINT FK_Feedback_SessionExercise FOREIGN KEY (SessionExerciseId) REFERENCES SessionExercises(SessionExerciseId) ON DELETE CASCADE,
    CONSTRAINT FK_Feedback_Rep       FOREIGN KEY (RepId)       REFERENCES SessionReps(RepId),
    CONSTRAINT FK_Feedback_ErrorType FOREIGN KEY (ErrorTypeId) REFERENCES PostureErrorTypes(ErrorTypeId),
    CONSTRAINT CK_Feedback_Type CHECK (FeedbackType IN ('Error', 'Warning', 'Correction', 'Praise'))
);

/* =====================================================================
   5. THEO DÕI TIẾN BỘ, MỤC TIÊU, THÀNH TÍCH
   ===================================================================== */

-- 5.1 Mục tiêu cá nhân
CREATE TABLE Goals
(
    GoalId       INT          AUTO_INCREMENT PRIMARY KEY,
    UserId       INT          NOT NULL,
    GoalType     VARCHAR(40)  NOT NULL,         -- WorkoutsPerWeek / TotalReps / FormScore / Streak
    TargetValue  DECIMAL(10,2) NOT NULL,
    CurrentValue DECIMAL(10,2) NOT NULL DEFAULT 0,
    StartDate    DATE         NOT NULL,
    EndDate      DATE         NULL,
    IsAchieved   TINYINT(1)   NOT NULL DEFAULT 0,

    CONSTRAINT FK_Goals_Users FOREIGN KEY (UserId) REFERENCES Users(UserId) ON DELETE CASCADE
);

-- 5.2 Danh mục huy hiệu / thành tích
CREATE TABLE Achievements
(
    AchievementId INT          AUTO_INCREMENT PRIMARY KEY,
    Code          VARCHAR(50)  NOT NULL,
    Name          VARCHAR(120) NOT NULL,
    Description   VARCHAR(500) NULL,
    IconUrl       VARCHAR(500) NULL,
    CONSTRAINT UQ_Achievements_Code UNIQUE (Code)
);

-- 5.3 Thành tích người dùng đạt được
CREATE TABLE UserAchievements
(
    UserId        INT      NOT NULL,
    AchievementId INT      NOT NULL,
    AchievedAt    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT PK_UserAchievements PRIMARY KEY (UserId, AchievementId),
    CONSTRAINT FK_UserAch_Users        FOREIGN KEY (UserId)        REFERENCES Users(UserId) ON DELETE CASCADE,
    CONSTRAINT FK_UserAch_Achievements FOREIGN KEY (AchievementId) REFERENCES Achievements(AchievementId) ON DELETE CASCADE
);

-- 5.4 Số đo cơ thể theo thời gian
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
   6. GÓI DỊCH VỤ (FREEMIUM / PREMIUM) & THÔNG BÁO
   ===================================================================== */

-- 6.1 Gói dịch vụ
CREATE TABLE SubscriptionPlans
(
    SubscriptionPlanId INT           AUTO_INCREMENT PRIMARY KEY,
    Name               VARCHAR(50)   NOT NULL,   -- Free / Premium / Pro
    PriceMonthly       DECIMAL(10,2) NOT NULL DEFAULT 0,
    Currency           VARCHAR(10)   NOT NULL DEFAULT 'VND',
    Features           VARCHAR(1000) NULL,
    IsActive           TINYINT(1)    NOT NULL DEFAULT 1,
    CONSTRAINT UQ_SubPlan_Name UNIQUE (Name)
);

-- 6.2 Đăng ký gói của người dùng
CREATE TABLE UserSubscriptions
(
    UserSubscriptionId INT         AUTO_INCREMENT PRIMARY KEY,
    UserId             INT         NOT NULL,
    SubscriptionPlanId INT         NOT NULL,
    StartDate          DATE        NOT NULL,
    EndDate            DATE        NULL,
    Status             VARCHAR(20) NOT NULL DEFAULT 'Active', -- Active / Expired / Cancelled
    AutoRenew          TINYINT(1)  NOT NULL DEFAULT 0,

    CONSTRAINT FK_UserSub_Users FOREIGN KEY (UserId)             REFERENCES Users(UserId) ON DELETE CASCADE,
    CONSTRAINT FK_UserSub_Plan  FOREIGN KEY (SubscriptionPlanId) REFERENCES SubscriptionPlans(SubscriptionPlanId),
    CONSTRAINT CK_UserSub_Status CHECK (Status IN ('Active', 'Expired', 'Cancelled'))
);

-- 6.2b Nhật ký thanh toán hóa đơn của người dùng
CREATE TABLE Payments
(
    PaymentId          INT           AUTO_INCREMENT PRIMARY KEY,
    UserSubscriptionId INT           NOT NULL,
    TransactionNo      VARCHAR(100)  NULL,        -- Mã giao dịch từ cổng thanh toán (MoMo, VNPay...)
    Amount             DECIMAL(10,2) NOT NULL,
    Currency           VARCHAR(10)   NOT NULL DEFAULT 'VND',
    PaymentMethod      VARCHAR(50)   NOT NULL,    -- MoMo / VNPay / Stripe / ApplePay / GooglePay
    Status             VARCHAR(20)   NOT NULL DEFAULT 'Pending',
                                                  -- Pending / Completed / Failed / Refunded
    PaymentGatewayLog  TEXT          NULL,        -- Lưu JSON phản hồi từ gateway phòng trường hợp đối soát lỗi
    PaidAt             DATETIME      NULL,
    CreatedAt          DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT FK_Payments_UserSubscriptions FOREIGN KEY (UserSubscriptionId)
        REFERENCES UserSubscriptions(UserSubscriptionId) ON DELETE CASCADE,
    CONSTRAINT CK_Payments_Status CHECK (Status IN ('Pending', 'Completed', 'Failed', 'Refunded'))
);

CREATE INDEX IX_Payments_UserSubscriptionId ON Payments(UserSubscriptionId);
CREATE INDEX IX_Payments_Status             ON Payments(Status);

-- 6.3 Thông báo
CREATE TABLE Notifications
(
    NotificationId BIGINT       AUTO_INCREMENT PRIMARY KEY,
    UserId         INT          NOT NULL,
    Title          VARCHAR(150) NOT NULL,
    Body           VARCHAR(500) NULL,
    Type           VARCHAR(30)  NULL,          -- Reminder / Achievement / System
    IsRead         TINYINT(1)   NOT NULL DEFAULT 0,
    CreatedAt      DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT FK_Notif_Users FOREIGN KEY (UserId) REFERENCES Users(UserId) ON DELETE CASCADE
);

-- 6.4 Nhật ký hoạt động của admin
CREATE TABLE AuditLogs
(
    AuditLogId BIGINT        AUTO_INCREMENT PRIMARY KEY,
    UserId     INT           NULL,              -- ai thực hiện
    Action     VARCHAR(100)  NOT NULL,
    EntityName VARCHAR(100)  NULL,
    EntityId   VARCHAR(50)   NULL,
    Details    VARCHAR(1000) NULL,
    CreatedAt  DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT FK_Audit_Users FOREIGN KEY (UserId) REFERENCES Users(UserId)
);

/* =====================================================================
   7. CHỈ MỤC (INDEX) tăng tốc truy vấn thường dùng
   ===================================================================== */
CREATE INDEX IX_Users_RoleId             ON Users(RoleId);
CREATE INDEX IX_Sessions_UserId          ON WorkoutSessions(UserId, StartedAt DESC);
CREATE INDEX IX_SessionEx_SessionId      ON SessionExercises(SessionId);
CREATE INDEX IX_Reps_SessionExerciseId   ON SessionReps(SessionExerciseId);
CREATE INDEX IX_Feedback_SessionExercise ON RealtimeFeedback(SessionExerciseId, OccurredAt);
CREATE INDEX IX_Feedback_ErrorType       ON RealtimeFeedback(ErrorTypeId);
CREATE INDEX IX_Notifications_UserId      ON Notifications(UserId, IsRead);

/* =====================================================================
   8. STORED PROCEDURE: ĐĂNG KÝ TÀI KHOẢN
   (giữ lại cho tham khảo / dùng trực tiếp bằng SQL nếu cần — backend
   FastAPI hiện tại đăng ký user qua ORM + bcrypt, không gọi proc này)
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
   9. VIEW: TÓM TẮT BUỔI TẬP (tiện cho màn hình lịch sử / báo cáo)
   ===================================================================== */
CREATE OR REPLACE VIEW vw_SessionSummary
AS
SELECT
    s.SessionId,
    s.UserId,
    u.Username,
    s.StartedAt,
    s.EndedAt,
    s.Status,
    s.TotalDurationSec,
    s.OverallFormScore,
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

/* =====================================================================
   10. DỮ LIỆU MẪU (SEED DATA)
   Lưu ý: KHÔNG seed tài khoản Users mẫu ở đây — backend tạo tài khoản
   qua register/create_admin.py bằng bcrypt (xem BA.md).
   ===================================================================== */

-- 10.1 Vai trò
INSERT INTO Roles (RoleName, Description) VALUES
('Admin', 'Quản trị viên hệ thống'),
('User',  'Người dùng thông thường');

-- 10.2 Gói dịch vụ
INSERT INTO SubscriptionPlans (Name, PriceMonthly, Currency, Features) VALUES
('Free',    0,      'VND', 'Phát hiện tư thế cơ bản, giới hạn 3 bài tập/ngày'),
('Premium', 99000,  'VND', 'Toàn bộ bài tập, phản hồi giọng nói, lịch sử không giới hạn'),
('Pro',     199000, 'VND', 'Toàn bộ tính năng Premium + chương trình cá nhân hóa AI + phân tích chuyên sâu');

-- 10.4 Nhóm cơ
INSERT INTO MuscleGroups (Name) VALUES
('Chest'), ('Back'), ('Shoulders'), ('Quadriceps'),
('Hamstrings'), ('Glutes'), ('Core'), ('Biceps'), ('Triceps'), ('Calves');

-- 10.5 Bài tập mẫu
INSERT INTO Exercises (Name, Description, Category, Difficulty, ExerciseType, Met) VALUES
('Squat',        'Đứng lên ngồi xuống, giữ lưng thẳng, đầu gối theo mũi chân', 'Strength', 'Beginner',     'Standard', 5.0),
('Push-up',      'Chống đẩy, thân người thẳng, khuỷu tay khoảng 45 độ',         'Strength', 'Intermediate', 'Standard', 3.8),
('Lunge',        'Bước trùng chân, gối trước vuông góc',                        'Strength', 'Beginner',     'Standard', 4.0),
('Plank',        'Giữ tư thế tấm ván, thân thẳng từ đầu đến gót',                'Core',     'Beginner',     'Duration', 3.3),
('Bicep Curl',   'Cuốn tạ tay, giữ khuỷu cố định',                              'Strength', 'Beginner',     'Standard', 3.5),
('Jumping Jack', 'Nhảy dang tay chân, vận động toàn thân',                       'Cardio',     'Beginner',     'Standard', 8.0);

-- 10.6 Gán nhóm cơ chính cho vài bài
INSERT INTO ExerciseMuscleGroups (ExerciseId, MuscleGroupId, IsPrimary)
SELECT e.ExerciseId, m.MuscleGroupId, 1
FROM Exercises e JOIN MuscleGroups m ON
    (e.Name = 'Squat'      AND m.Name = 'Quadriceps') OR
    (e.Name = 'Push-up'    AND m.Name = 'Chest') OR
    (e.Name = 'Lunge'      AND m.Name = 'Glutes') OR
    (e.Name = 'Plank'      AND m.Name = 'Core') OR
    (e.Name = 'Bicep Curl' AND m.Name = 'Biceps') OR
    (e.Name = 'Jumping Jack' AND m.Name = 'Calves');

-- 10.7 Luật góc khớp (ví dụ cho Squat & Push-up)
SET @SquatId = (SELECT ExerciseId FROM Exercises WHERE Name = 'Squat' LIMIT 1);
SET @PushId  = (SELECT ExerciseId FROM Exercises WHERE Name = 'Push-up' LIMIT 1);

INSERT INTO ExercisePostureRules
    (ExerciseId, RuleName, JointA, JointB, JointC, MinAngle, MaxAngle, TargetAngle, IsRepTrigger, Tolerance)
VALUES
(@SquatId, 'Góc đầu gối (hip-knee-ankle)', 'Hip',      'Knee',   'Ankle', 70,  100, 90,  1, 10),
(@SquatId, 'Độ thẳng lưng (shoulder-hip-knee)', 'Shoulder', 'Hip', 'Knee', 160, 185, 175, 0, 8),
(@PushId,  'Góc khuỷu tay (shoulder-elbow-wrist)', 'Shoulder', 'Elbow', 'Wrist', 80, 100, 90, 1, 10),
(@PushId,  'Thân thẳng (shoulder-hip-ankle)', 'Shoulder', 'Hip', 'Ankle', 165, 185, 178, 0, 8);

-- 10.8 Danh mục lỗi tư thế + câu nhắc của AI
INSERT INTO PostureErrorTypes (ExerciseId, ErrorCode, ErrorName, Severity, CorrectionTip, VoicePrompt) VALUES
(@SquatId, 'KNEE_VALGUS',     'Đầu gối đổ vào trong',      'High',   'Đẩy đầu gối ra ngoài theo hướng mũi chân', 'Đẩy đầu gối ra ngoài!'),
(@SquatId, 'SQUAT_SHALLOW',   'Ngồi chưa đủ sâu',         'Medium', 'Hạ hông xuống thấp hơn, đùi song song mặt sàn', 'Xuống sâu hơn chút nữa!'),
(@SquatId, 'BACK_ROUNDING',   'Lưng bị cong',              'High',   'Giữ ngực mở, lưng thẳng',                  'Giữ thẳng lưng!'),
(@PushId,  'HIP_SAGGING',     'Hông bị võng xuống',       'High',   'Siết cơ bụng, giữ thân thẳng',             'Siết bụng, giữ thân thẳng!'),
(@PushId,  'ELBOW_FLARE',     'Khuỷu tay xòe quá rộng',   'Medium', 'Khép khuỷu tay gần thân khoảng 45 độ',     'Khép khuỷu tay lại!');

-- 10.9 Thành tích mẫu
INSERT INTO Achievements (Code, Name, Description) VALUES
('FIRST_WORKOUT',  'Buổi tập đầu tiên',   'Hoàn thành buổi tập đầu tiên'),
('STREAK_7',       '7 ngày liên tục',     'Tập 7 ngày liên tiếp'),
('PERFECT_FORM',   'Form hoàn hảo',       'Đạt 100 điểm form trong một bài tập'),
('REPS_1000',      '1000 reps',           'Hoàn thành tổng cộng 1000 rep');

SELECT '>>> Database PostureX (poturex123) đã được tạo thành công cùng dữ liệu mẫu (không seed tài khoản).' AS Message;
