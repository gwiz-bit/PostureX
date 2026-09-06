# Việc cần test trên điện thoại thật

Ghi lại cho phiên test ngày mai (07/09/2026). Tất cả các mục dưới đây mới chỉ
được xác nhận bằng test tự động hoặc test trên emulator — **chưa ai thử trên
điện thoại thật với camera thật**. App mặc định đã trỏ VPS `103.82.21.150`,
không cần cờ `--dart-define` gì khi build.

⚠️ Nhớ `git pull` (nhánh `main`, commit mới nhất `09752e7` tính tới lúc ghi
file này) rồi build lại app trước khi test — nhiều lỗi đã sửa hôm nay đều là
sửa trong CODE APP (Flutter), không phải chỉ trên server, nên bản app cũ sẽ
không có các bản vá đó dù server đã cập nhật.

---

## 1. Quan trọng nhất — Rep-count có đếm đúng số không

Đây là việc còn treo lâu nhất trong ngày, ưu tiên test đầu tiên.

**Cách test:** mở live-analysis bài **Squat** (bài dễ kiểm tra nhất), đứng đủ
xa để camera thấy trọn người, squat xuống-lên liên tục **5 lần rõ ràng**
(dừng hẳn ở đáy và ở đỉnh mỗi lần).

**Kỳ vọng:**
- Số REPS hiện đúng **5**, không phải 10 (lỗi đếm gấp đôi cũ) và không đứng
  yên ở 0.
- Khung xương (đường xanh/đỏ) bám đúng theo cơ thể suốt quá trình, không lệch
  hẳn sang bên (đây là lỗi mirror/rotation đã sửa ở đầu phiên, camera trước).
- Badge trạng thái (GOING DOWN / BOTTOM / GOING UP / TOP) đổi theo đúng nhịp
  tập, không đứng im.

**Nếu sai:** chụp/quay lại, ghi rõ số rep thật vs số app đếm, và khung xương
có bám đúng người không.

---

## 2. Các analyzer mới hôm nay — ngưỡng góc đều là ƯỚC LƯỢNG, chưa đo người thật

Không cần test hết hơn 90 bài mới, chỉ cần test **đại diện 1-2 bài mỗi nhóm**
bên dưới. Với mỗi bài: thực hiện đúng kỹ thuật 3-4 rep, xem app có đếm đúng
và **không nhắc lỗi oan** (báo "chưa đủ sâu"/"chưa duỗi hết" dù đã làm đúng)
hay **bỏ lọt lỗi thật** (làm sai rõ ràng mà app vẫn báo đúng).

| Nhóm | Bài gợi ý để test | Điều cần xem |
|---|---|---|
| **Curl** | Barbell Curl hoặc Dumbbell Curl | Rep đếm đúng lúc gập tay lên cao; báo "chưa curl đủ cao" nếu chỉ gập nửa chừng |
| **Lateral Raise/Front Raise/Rear Delt Fly** | Dumbbell Lateral Raise | Rep đếm đúng lúc nâng tay ngang vai — nhóm này có công thức góc phức tạp nhất (góc bù), rủi ro sai cao nhất, ưu tiên test kỹ |
| **Chest Fly** | Dumbbell Chest Fly | Rep đếm đúng lúc khép hai tay lại trước ngực |
| **Calf Raise** | Standing Calf Raise Machine hoặc Kettlebell Calf Raise | Rep đếm đúng lúc nhón gót cao |
| **Push-up / Dips** | Push Up, hoặc Bench Dips | Dùng chung analyzer với Bench Press — kiểm xem góc khuỷu tay đọc đúng dù không nằm trên ghế |
| **Glute Bridge / Good Mornings** | Glute Bridge | Dùng chung analyzer với Hip Thrust/Deadlift |
| **Leg Extension** | Machine Leg Extension (nếu có máy) | Rep đếm đúng lúc duỗi thẳng chân |
| **Tricep Extension/Pushdown** | Cable Bar Pushdown hoặc Dumbbell Skullcrusher | Rep đếm đúng lúc duỗi thẳng tay; lời nhắc phải nói "duỗi tay", KHÔNG phải "đẩy qua đầu" (đó là lỗi đã tránh khi viết analyzer này) |
| **Pulldown / Pull-up** | Lat Pulldown hoặc Pull Ups (nếu có xà) | Rep đếm đúng; **không** bị báo "lưng cong" dù ngồi/treo người bình thường (đây là lỗi đã né khi viết analyzer này — nếu thấy báo lưng cong liên tục thì có bug) |

**Nếu sai ở bài nào:** ghi rõ tên bài, mô tả cụ thể (không đếm rep / đếm sai
số / báo lỗi liên tục dù làm đúng / không báo lỗi dù làm sai). Sửa bằng cách
chỉnh ngưỡng qua màn admin "Ngưỡng tư thế" theo từng bài, không cần sửa code.

---

## 3. Video upload có được phân tích không (tính năng mới nhất)

**Cách test:**
1. Vào một bài **có hỗ trợ live analysis** (vd Squat) nhưng chọn **"Upload a
   video instead"** thay vì live — quay/chọn sẵn một video ngắn (vài squat),
   upload lên.
2. Đợi khoảng 10-30 giây (phân tích chạy ngầm sau khi upload xong).
3. Mở lại video đó (danh sách video đã upload) — xem có hiện `total_reps`,
   `accuracy_score`, dòng tóm tắt (`analysis_summary`) hợp lý không.
4. Thử thêm **một bài KHÔNG hỗ trợ live** (vd "Abdominals Stretch Variation
   Three" — đúng bài trong ảnh bạn gửi trước đó) → upload video → kỳ vọng
   thấy dòng ghi chú **"Bài này chưa hỗ trợ phân tích tự động — video chỉ
   được lưu lại."**, KHÔNG phải feedback squat vô nghĩa cho một bài giãn cơ.

**Nếu sai:** ghi rõ đang test bài nào, video dài bao lâu, đợi bao lâu rồi
kiểm tra, và nội dung thực tế hiện ra là gì.

---

## 4. Google Sign-In — lỗi cũ, chưa rõ nguyên nhân

Vẫn còn lỗi **"Could not sign in with Google. Check your connection."**, gặp
trên emulator trước đó. Nghi phạm chính là thiếu đăng ký OAuth Android client
cho `com.posturex.app` trong Google Cloud Console (việc của VanGiap, không
sửa được qua SSH) — nhưng chưa chắc chắn vì emulator không đáng tin cho ca
này.

**Cách test:** trên điện thoại thật, bấm "Continue with Google", xem có hiện
màn chọn tài khoản Google bình thường không, hay vẫn báo lỗi/im lặng quay lại
màn Login.

**Nếu vẫn lỗi:** không phải việc sửa được ngay — cần VanGiap đăng ký OAuth
client trước.

---

## Cách báo kết quả

Với mỗi mục ở trên, chỉ cần nói ngắn gọn: **"Mục N: OK"** hoặc **"Mục N: lỗi
— [mô tả]"**. Có ảnh chụp màn hình hoặc video quay lại thao tác thì càng tốt,
đặc biệt cho mục 1 và mục 2 (khung xương/rep-count khó mô tả bằng lời).
