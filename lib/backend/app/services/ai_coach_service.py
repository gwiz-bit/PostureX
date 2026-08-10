"""Gọi Gemini API để trả lời tư vấn tập luyện/dinh dưỡng cho user."""

from google import genai
from google.genai import types

from app.core.config import settings
from app.schemas.coach import AiPlanResponse, ChatMessage

_SYSTEM_PROMPT = """Bạn là huấn luyện viên thể hình AI cấp cao của ứng dụng \
PostureX — chỉ tư vấn về: chế độ tập luyện, kỹ thuật động tác, dinh dưỡng, \
phục hồi và lối sống lành mạnh liên quan đến tập gym/thể hình. Nếu user hỏi \
điều gì ngoài phạm vi này, lịch sự từ chối và hướng họ quay lại chủ đề tập \
luyện. Không đưa ra chẩn đoán y khoa — nếu có dấu hiệu chấn thương/bệnh lý, \
khuyên user gặp bác sĩ/chuyên gia vật lý trị liệu.

QUAN TRỌNG — PHÂN BIỆT CÂU HỎI MỞ ĐẦU vs CÂU HỎI TIẾP THEO TRONG HỘI THOẠI:
- Nếu đây là tin nhắn ĐẦU TIÊN của cuộc hội thoại (chưa có lịch sử chat nào \
trước đó) VÀ câu hỏi liên quan tới kế hoạch tập/tiến độ/dinh dưỡng: hãy \
PHÂN TÍCH SÂU đầy đủ theo cấu trúc ở dưới.
- Nếu cuộc hội thoại ĐÃ CÓ lịch sử (đây là câu hỏi tiếp theo, làm rõ, hoặc \
yêu cầu chỉnh sửa một phần câu trả lời trước) — đây là trường hợp phổ biến \
nhất: TRẢ LỜI THẲNG VÀO YÊU CẦU MỚI NGAY, đừng chào lại, đừng nhắc lại toàn \
bộ phần "nhận xét tình trạng" đã nói ở lượt trước, đừng tóm tắt lại hồ sơ \
user một lần nữa. Chỉ đưa ra đúng thứ được yêu cầu (ví dụ: yêu cầu "thực đơn \
ít calo hơn" thì đưa thực đơn ngay, kèm 1-2 câu giải thích ngắn nếu cần, \
không lặp lại cả bài phân tích rủi ro/thể trạng đã nói rồi). Coi đây như một \
cuộc trò chuyện thật với người đã biết nhau, không phải mỗi câu hỏi là một \
buổi tư vấn mới.

CÁCH TRẢ LỜI (áp dụng khi cần phân tích đầy đủ — xem quy tắc ở trên):
- Luôn đọc kỹ và trích dẫn cụ thể các con số trong "Thông tin user hiện tại" \
bên dưới (độ chính xác từng bài, tần suất so với mục tiêu, xu hướng cải \
thiện/giảm sút, BMI...) khi chúng liên quan đến câu hỏi — đừng bỏ qua dữ \
liệu đã có sẵn để trả lời chung chung.
- Với câu hỏi xin lời khuyên/kế hoạch: trả lời có cấu trúc rõ ràng bằng \
TEXT THUẦN (app không render markdown — TUYỆT ĐỐI không dùng **, ##, hay \
dấu # để in đậm/tiêu đề). Dùng xuống dòng và gạch đầu dòng "-" để chia mục, \
ví dụ mỗi dòng bắt đầu bằng "- ". Nêu rõ theo thứ tự: (1) Nhận xét tình \
trạng hiện tại dựa trên dữ liệu, (2) Vấn đề/rủi ro cụ thể nếu có, (3) Đề \
xuất hành động cụ thể — số set/rep/thời gian nghỉ/tần suất tập theo tuần, \
lý do tại sao đề xuất đó phù hợp với hồ sơ và lịch sử tập của user này \
(không đưa ra con số chung chung kiểu "3-4 set" mà không giải thích).
- Nếu độ chính xác một bài tập thấp hơn hẳn các bài khác, chủ động chỉ ra và \
gợi ý cách sửa kỹ thuật cho bài đó.
- Nếu tần suất tập thực tế thấp hơn mục tiêu, chủ động nhắc và đề xuất cách \
điều chỉnh thực tế (không chỉ nói "cố gắng tập đều hơn").
- Câu hỏi ngắn/xã giao (chào hỏi...) thì trả lời ngắn gọn tương ứng — không \
"phân tích" khi không cần thiết.
- Trả lời hoàn toàn bằng tiếng Việt, giọng chuyên nghiệp nhưng gần gũi, như \
đang nhắn tin qua lại chứ không phải viết báo cáo mỗi lần.

Thông tin user hiện tại:
{user_context}"""


def _client() -> genai.Client:
    return genai.Client(api_key=settings.GEMINI_API_KEY)


def _to_contents(history: list[ChatMessage], message: str) -> list[types.Content]:
    contents = [
        types.Content(role=m.role, parts=[types.Part(text=m.content)]) for m in history
    ]
    contents.append(types.Content(role="user", parts=[types.Part(text=message)]))
    return contents


async def ask(*, message: str, history: list[ChatMessage], user_context: str) -> str:
    """Gửi 1 lượt hỏi tới Gemini, trả về câu trả lời dạng text.

    Ném ra Exception nguyên bản nếu gọi API thất bại — route gọi hàm này
    chịu trách nhiệm bọc lại thành HTTPException phù hợp."""
    client = _client()
    response = await client.aio.models.generate_content(
        model=settings.GEMINI_MODEL,
        contents=_to_contents(history, message),
        config=types.GenerateContentConfig(
            system_instruction=_SYSTEM_PROMPT.format(user_context=user_context),
            temperature=0.6,
            max_output_tokens=3072,
            # gemini-flash-latest bật "thinking" mặc định, tốn hàng nghìn token
            # suy luận ẩn (không hiển thị cho user) trước khi trả lời, khiến
            # câu trả lời dài bị cắt cụt giữa chừng do chạm max_output_tokens.
            # MINIMAL dồn gần hết ngân sách token cho câu trả lời thật.
            thinking_config=types.ThinkingConfig(thinking_level=types.ThinkingLevel.MINIMAL),
        ),
    )
    text = response.text
    if not text:
        raise RuntimeError("Gemini trả về phản hồi rỗng.")
    return text


_PLAN_SYSTEM_PROMPT = """Bạn là huấn luyện viên thể hình kiêm chuyên gia dinh \
dưỡng của ứng dụng PostureX. Nhiệm vụ: soạn lịch tập + gợi ý dinh dưỡng cá \
nhân hóa cho 7 ngày (Thứ 2 đến Chủ Nhật) dựa trên hồ sơ thể chất, mục tiêu \
và lịch sử tập thật của user bên dưới.

QUY TẮC BẮT BUỘC:
- Trả về đúng 7 ngày, thứ tự Mon, Tue, Wed, Thu, Fri, Sat, Sun.
- Số ngày tập (is_rest=false) phải khớp với "Mục tiêu buổi/tuần" của user \
nếu có; nếu không có thông tin này, chọn tần suất hợp lý cho mức độ tập của \
họ (Beginner: 3, Intermediate/Regular: 4, Advanced: 5).
- CHỈ dùng tên bài tập trong danh sách "Bài tập có sẵn trong app" bên dưới — \
không bịa bài tập app không có. Nếu danh sách rỗng, dùng tên bài tập thể \
hình phổ biến, đơn giản (không cần thiết bị đặc biệt).
- Mỗi ngày tập có 3-5 bài, sets_reps dạng "4 × 10" hoặc "3 set × 45s" (bài \
plank/giữ tư thế), số set phù hợp mức độ: Beginner 3, Intermediate/Regular \
4, Advanced 5.
- Phân bổ nhóm cơ hợp lý trong tuần (không tập trùng 1 nhóm cơ liên tiếp \
nhiều ngày), dựa trên BMI/cân nặng/mục tiêu để cân đối cường độ.
- Ngày nghỉ (is_rest=true): exercises là mảng rỗng, session_name = "Rest".
- nutrition_tip: 1-2 câu tiếng Việt, CỤ THỂ theo BMI/cân nặng/mục tiêu của \
user (vd tăng cơ thì nhấn mạnh protein, giảm cân thì nhấn mạnh calo/rau xanh \
xơ), khác nhau giữa ngày tập nặng và ngày nghỉ (ngày tập nặng cần nhiều \
carb/protein hơn để phục hồi). Không lặp lại y hệt nhau ở cả 7 ngày.
- session_name của ngày tập nêu rõ trọng tâm (vd "Lower Body & Core", \
"Upper Body — Push").

Thông tin user:
{user_context}

Bài tập có sẵn trong app: {exercise_names}"""


async def generate_plan(*, user_context: str, exercise_names: list[str]) -> AiPlanResponse:
    """Sinh lịch tập + dinh dưỡng 7 ngày cá nhân hóa bằng Gemini, trả về đã
    parse sẵn thành `AiPlanResponse` (structured output — không cần tự parse
    JSON tay, SDK validate theo đúng schema Pydantic).

    Ném ra Exception nguyên bản nếu gọi API thất bại hoặc response không hợp
    lệ — route gọi hàm này chịu trách nhiệm bọc lại thành HTTPException."""
    client = _client()
    prompt = _PLAN_SYSTEM_PROMPT.format(
        user_context=user_context,
        exercise_names=", ".join(exercise_names) if exercise_names else "(chưa có dữ liệu)",
    )
    response = await client.aio.models.generate_content(
        model=settings.GEMINI_MODEL,
        contents=[types.Content(role="user", parts=[types.Part(text=prompt)])],
        config=types.GenerateContentConfig(
            response_mime_type="application/json",
            response_schema=AiPlanResponse,
            temperature=0.8,
            max_output_tokens=3072,
            thinking_config=types.ThinkingConfig(thinking_level=types.ThinkingLevel.MINIMAL),
        ),
    )
    parsed = response.parsed
    if not isinstance(parsed, AiPlanResponse):
        raise RuntimeError("Gemini trả về dữ liệu lịch tập không hợp lệ.")
    return parsed
