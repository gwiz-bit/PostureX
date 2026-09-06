"""Dựng bộ 33 keypoint giả để test analyzer mà không cần camera hay MediaPipe.

Analyzer chỉ đọc toạ độ khớp rồi tính góc, nên không cần ảnh thật: đặt khớp ở
đúng vị trí hình học là kiểm được toàn bộ logic đếm rep và bắt lỗi. Đây là
cách duy nhất để kiểm chứng 9 analyzer một cách lặp lại được — cách còn lại là
nhờ người đứng trước camera tập thử, vừa chậm vừa không tái hiện được.

Toạ độ theo hệ của MediaPipe: x, y đã chuẩn hoá về [0, 1], gốc ở góc TRÊN
BÊN TRÁI, nên **y lớn hơn nghĩa là thấp hơn trên màn hình**.
"""

import math

from app.ml.pose_estimator import Keypoint

# Chỉ số landmark của MediaPipe Pose — trùng với thứ tự trong
# `PoseEstimator.LANDMARK_NAMES`.
NOSE = 0
LEFT_SHOULDER = 11
RIGHT_SHOULDER = 12
LEFT_ELBOW = 13
RIGHT_ELBOW = 14
LEFT_WRIST = 15
RIGHT_WRIST = 16
LEFT_HIP = 23
RIGHT_HIP = 24
LEFT_KNEE = 25
RIGHT_KNEE = 26
LEFT_ANKLE = 27
RIGHT_ANKLE = 28
LEFT_HEEL = 29
RIGHT_HEEL = 30
LEFT_FOOT_INDEX = 31
RIGHT_FOOT_INDEX = 32

LANDMARK_COUNT = 33


def kp(x: float, y: float, z: float = 0.0, visibility: float = 1.0) -> Keypoint:
    return Keypoint(x=x, y=y, z=z, visibility=visibility)


def blank_pose(visibility: float = 1.0) -> list[Keypoint]:
    """33 keypoint đều nhìn thấy được, dồn ở giữa khung hình.

    Khớp nào không đặt lại thì trùng điểm nhau; `calculate_angle` với hai
    vector 0 trả về 90° (do chia cho epsilon rồi arccos(0)) chứ không nổ,
    nên tư thế "trống" vẫn an toàn — nhưng mỗi test phải tự đặt những khớp
    mà analyzer nó kiểm thật sự đọc tới.
    """
    return [kp(0.5, 0.5) for _ in range(LANDMARK_COUNT)]


def place_at_angle(a: Keypoint, b: Keypoint, degrees: float, length: float = 0.2) -> Keypoint:
    """Trả điểm c sao cho góc a-b-c (đỉnh tại b) đúng bằng `degrees`.

    Đây là viên gạch cơ bản: đã có hai khớp thì đặt khớp thứ ba theo góc mong
    muốn, không phải tự tính lượng giác trong từng test. Nhờ vậy dựng được
    chuỗi khớp nối tiếp (cổ chân → gối → hông → vai) mà mỗi góc vẫn đúng ý.
    """
    base = math.atan2(a.y - b.y, a.x - b.x)
    rad = base + math.radians(degrees)
    return kp(b.x + length * math.cos(rad), b.y + length * math.sin(rad))


def squat_pose(
    knee_angle: float,
    back_angle: float = 175.0,
    *,
    right_knee_angle: float | None = None,
    knee_past_toe: bool = False,
    visibility: float = 1.0,
) -> list[Keypoint]:
    """Tư thế squat/lunge nhìn nghiêng, hai chân đặt đối xứng.

    `knee_angle` là góc hông-gối-cổ chân (180° = đứng thẳng, càng nhỏ càng
    sâu). `back_angle` là góc vai-hông-gối (180° = lưng thẳng đứng). Truyền
    `right_knee_angle` khác đi để kiểm cảnh báo lệch hai bên (vd
    `LegExtensionAnalyzer`) — mặc định `None` nghĩa là hai gối bằng nhau.

    Mũi chân đặt ở hai phía ngược nhau cho trái và phải, vì analyzer kiểm gối
    vượt mũi chân theo hai chiều đối xứng (`left_knee.x > left_foot.x` nhưng
    `right_knee.x < right_foot.x`) — người quay mặt vào camera.
    """
    pose = blank_pose(visibility)
    right_angle = knee_angle if right_knee_angle is None else right_knee_angle

    for hip_i, knee_i, ankle_i, foot_i, heel_i, shoulder_i, side_x, outward, angle in (
        (LEFT_HIP, LEFT_KNEE, LEFT_ANKLE, LEFT_FOOT_INDEX, LEFT_HEEL, LEFT_SHOULDER, 0.45, +1, knee_angle),
        (RIGHT_HIP, RIGHT_KNEE, RIGHT_ANKLE, RIGHT_FOOT_INDEX, RIGHT_HEEL, RIGHT_SHOULDER, 0.55, -1, right_angle),
    ):
        hip = kp(side_x, 0.45, visibility=visibility)
        knee = kp(side_x, 0.65, visibility=visibility)
        ankle = place_at_angle(hip, knee, angle, length=0.18)
        ankle = kp(ankle.x, ankle.y, visibility=visibility)
        shoulder = place_at_angle(knee, hip, back_angle, length=0.25)
        shoulder = kp(shoulder.x, shoulder.y, visibility=visibility)

        # Mũi chân ở phía ngoài gối = không vượt; đảo dấu = gối vượt mũi chân.
        toe_offset = -0.12 if knee_past_toe else 0.12
        foot = kp(knee.x + outward * toe_offset, ankle.y + 0.02, visibility=visibility)

        pose[hip_i] = hip
        pose[knee_i] = knee
        pose[ankle_i] = ankle
        pose[shoulder_i] = shoulder
        pose[foot_i] = foot
        pose[heel_i] = kp(knee.x - outward * 0.04, ankle.y + 0.02, visibility=visibility)

    return pose


def hinge_pose(
    hip_angle: float,
    *,
    right_hip_angle: float | None = None,
    knee_past_toe: bool = False,
    visibility: float = 1.0,
) -> list[Keypoint]:
    """Tư thế gập-duỗi hông cho deadlift và hip thrust.

    `hip_angle` là góc vai-hông-gối: 180° = thân duỗi thẳng, càng nhỏ càng
    gập sâu. `right_hip_angle` cho phép đặt hai bên lệch nhau để kiểm cảnh
    báo đẩy lệch bên của hip thrust.
    """
    pose = blank_pose(visibility)
    right_angle = hip_angle if right_hip_angle is None else right_hip_angle

    for hip_i, knee_i, ankle_i, foot_i, shoulder_i, side_x, angle, outward in (
        (LEFT_HIP, LEFT_KNEE, LEFT_ANKLE, LEFT_FOOT_INDEX, LEFT_SHOULDER, 0.45, hip_angle, +1),
        (RIGHT_HIP, RIGHT_KNEE, RIGHT_ANKLE, RIGHT_FOOT_INDEX, RIGHT_SHOULDER, 0.55, right_angle, -1),
    ):
        hip = kp(side_x, 0.45, visibility=visibility)
        knee = kp(side_x, 0.65, visibility=visibility)
        shoulder = place_at_angle(knee, hip, angle, length=0.25)
        shoulder = kp(shoulder.x, shoulder.y, visibility=visibility)
        ankle = kp(side_x, 0.85, visibility=visibility)

        toe_offset = -0.12 if knee_past_toe else 0.12
        pose[hip_i] = hip
        pose[knee_i] = knee
        pose[ankle_i] = ankle
        pose[shoulder_i] = shoulder
        pose[foot_i] = kp(knee.x + outward * toe_offset, ankle.y + 0.02, visibility=visibility)

    return pose


def arm_pose(
    elbow_angle: float,
    *,
    right_elbow_angle: float | None = None,
    back_angle: float = 175.0,
    visibility: float = 1.0,
) -> list[Keypoint]:
    """Tư thế co-duỗi khuỷu tay cho row, bench press và overhead press.

    `elbow_angle` là góc vai-khuỷu-cổ tay (180° = duỗi thẳng). Truyền
    `right_elbow_angle` khác đi để kiểm cảnh báo lệch hai bên.

    `back_angle` (vai-hông-gối) cần cho RowAnalyzer, vốn còn kiểm độ thẳng
    lưng ngoài góc khuỷu tay.
    """
    pose = blank_pose(visibility)
    right_angle = elbow_angle if right_elbow_angle is None else right_elbow_angle

    for shoulder_i, elbow_i, wrist_i, hip_i, knee_i, side_x, angle in (
        (LEFT_SHOULDER, LEFT_ELBOW, LEFT_WRIST, LEFT_HIP, LEFT_KNEE, 0.45, elbow_angle),
        (RIGHT_SHOULDER, RIGHT_ELBOW, RIGHT_WRIST, RIGHT_HIP, RIGHT_KNEE, 0.55, right_angle),
    ):
        shoulder = kp(side_x, 0.35, visibility=visibility)
        elbow = kp(side_x, 0.5, visibility=visibility)
        wrist = place_at_angle(shoulder, elbow, angle, length=0.15)
        wrist = kp(wrist.x, wrist.y, visibility=visibility)

        hip = kp(side_x, 0.6, visibility=visibility)
        knee = place_at_angle(shoulder, hip, back_angle, length=0.2)
        knee = kp(knee.x, knee.y, visibility=visibility)

        pose[shoulder_i] = shoulder
        pose[elbow_i] = elbow
        pose[wrist_i] = wrist
        pose[hip_i] = hip
        pose[knee_i] = knee

    return pose


def shoulder_raise_pose(
    shoulder_angle: float,
    *,
    right_shoulder_angle: float | None = None,
    visibility: float = 1.0,
) -> list[Keypoint]:
    """Tư thế nâng tay dạng vai: góc hông-vai-khuỷu tay, đỉnh tại vai.

    Dùng chung cho `LateralRaiseAnalyzer` (Lateral/Front Raise, Rear Delt Fly)
    và `ChestFlyAnalyzer` (Chest/Pec Fly) — cả hai đọc cùng một góc, chỉ khác
    chiều ngưỡng rep. `shoulder_angle` nhỏ = tay xuôi theo thân/khép lại, lớn
    = tay nâng ngang vai/mở rộng.
    """
    pose = blank_pose(visibility)
    right_angle = shoulder_angle if right_shoulder_angle is None else right_shoulder_angle

    for hip_i, shoulder_i, elbow_i, side_x, angle in (
        (LEFT_HIP, LEFT_SHOULDER, LEFT_ELBOW, 0.45, shoulder_angle),
        (RIGHT_HIP, RIGHT_SHOULDER, RIGHT_ELBOW, 0.55, right_angle),
    ):
        hip = kp(side_x, 0.6, visibility=visibility)
        shoulder = kp(side_x, 0.35, visibility=visibility)
        elbow = place_at_angle(hip, shoulder, angle, length=0.2)
        elbow = kp(elbow.x, elbow.y, visibility=visibility)

        pose[hip_i] = hip
        pose[shoulder_i] = shoulder
        pose[elbow_i] = elbow

    return pose


def calf_raise_pose(
    ankle_angle: float,
    *,
    right_ankle_angle: float | None = None,
    visibility: float = 1.0,
) -> list[Keypoint]:
    """Tư thế nhón gót: góc gối-mắt cá-mũi chân, đỉnh tại mắt cá.

    `ankle_angle` nhỏ (~90-100°) = bàn chân áp sàn (nghỉ), lớn (~140-150°) =
    đã nhón gót lên cao (đỉnh rep).
    """
    pose = blank_pose(visibility)
    right_angle = ankle_angle if right_ankle_angle is None else right_ankle_angle

    for knee_i, ankle_i, foot_i, side_x, angle in (
        (LEFT_KNEE, LEFT_ANKLE, LEFT_FOOT_INDEX, 0.45, ankle_angle),
        (RIGHT_KNEE, RIGHT_ANKLE, RIGHT_FOOT_INDEX, 0.55, right_angle),
    ):
        knee = kp(side_x, 0.6, visibility=visibility)
        ankle = kp(side_x, 0.85, visibility=visibility)
        foot = place_at_angle(knee, ankle, angle, length=0.12)
        foot = kp(foot.x, foot.y, visibility=visibility)

        pose[knee_i] = knee
        pose[ankle_i] = ankle
        pose[foot_i] = foot

    return pose


def plank_pose(
    body_angle: float,
    *,
    horizontal: bool = True,
    visibility: float = 1.0,
) -> list[Keypoint]:
    """Tư thế plank: góc vai-hông-cổ chân, 180° = thân thẳng hàng.

    `horizontal=False` dựng người đứng thẳng thay vì nằm ngang, để kiểm phần
    analyzer nhận biết "chưa vào tư thế plank".
    """
    pose = blank_pose(visibility)

    for shoulder_i, hip_i, ankle_i, side_y in (
        (LEFT_SHOULDER, LEFT_HIP, LEFT_ANKLE, 0.48),
        (RIGHT_SHOULDER, RIGHT_HIP, RIGHT_ANKLE, 0.52),
    ):
        if horizontal:
            # Thân trải ngang khung hình: vai trái, hông giữa, cổ chân phải.
            shoulder = kp(0.25, side_y, visibility=visibility)
            hip = kp(0.5, side_y, visibility=visibility)
        else:
            # Đứng thẳng: vai trên, hông dưới — khoảng cách dọc lớn hơn ngang.
            shoulder = kp(0.5, 0.25, visibility=visibility)
            hip = kp(0.5, 0.55, visibility=visibility)

        ankle = place_at_angle(shoulder, hip, body_angle, length=0.25)
        ankle = kp(ankle.x, ankle.y, visibility=visibility)

        pose[shoulder_i] = shoulder
        pose[hip_i] = hip
        pose[ankle_i] = ankle

    return pose


def spine_pose(spine_angle: float, *, visibility: float = 1.0) -> list[Keypoint]:
    """Tư thế bò bốn chân cho Cat-Cow: góc vai-hông-gối.

    Góc nhỏ = cong lưng lên (Cat), góc lớn = võng lưng xuống (Cow).
    """
    pose = blank_pose(visibility)

    for shoulder_i, hip_i, knee_i, side_x in (
        (LEFT_SHOULDER, LEFT_HIP, LEFT_KNEE, 0.45),
        (RIGHT_SHOULDER, RIGHT_HIP, RIGHT_KNEE, 0.55),
    ):
        shoulder = kp(side_x - 0.2, 0.45, visibility=visibility)
        hip = kp(side_x + 0.05, 0.45, visibility=visibility)
        knee = place_at_angle(shoulder, hip, spine_angle, length=0.2)
        knee = kp(knee.x, knee.y, visibility=visibility)

        pose[shoulder_i] = shoulder
        pose[hip_i] = hip
        pose[knee_i] = knee

    return pose
