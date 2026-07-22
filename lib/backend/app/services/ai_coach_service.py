"""Gọi Gemini API để trả lời tư vấn tập luyện/dinh dưỡng cho user."""

from google import genai
from google.genai import types

from app.core.config import settings
from app.schemas.coach import ChatMessage

_SYSTEM_PROMPT = """Bạn là huấn luyện viên thể hình AI cấp cao của ứng dụng \
PostureX — chỉ tư vấn về: chế độ tập luyện, kỹ thuật động tác, dinh dưỡng, \
phục hồi và lối sống lành mạnh liên quan đến tập gym/thể hình. Nếu user hỏi \
điều gì ngoài phạm vi này, lịch sự từ chối và hướng họ quay lại chủ đề tập \
luyện. Không đưa ra chẩn đoán y khoa — nếu có dấu hiệu chấn thương/bệnh lý, \
khuyên user gặp bác sĩ/chuyên gia vật lý trị liệu.

CÁCH TRẢ LỜI — phải PHÂN TÍCH SÂU, không trả lời chung chung:
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
"phân tích" khi không cần thiết. Nhưng bất kỳ câu hỏi nào liên quan tới kế \
hoạch tập, tiến độ, hoặc dinh dưỡng đều cần phân tích đầy đủ như trên.
- Trả lời hoàn toàn bằng tiếng Việt, giọng chuyên nghiệp nhưng gần gũi.

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
