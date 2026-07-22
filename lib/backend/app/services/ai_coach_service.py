"""Gọi Gemini API để trả lời tư vấn tập luyện/dinh dưỡng cho user."""

from google import genai
from google.genai import types

from app.core.config import settings
from app.schemas.coach import ChatMessage

_SYSTEM_PROMPT = """Bạn là huấn luyện viên thể hình AI của ứng dụng PostureX — \
chỉ tư vấn về: chế độ tập luyện, kỹ thuật động tác, dinh dưỡng, phục hồi và \
lối sống lành mạnh liên quan đến tập gym/thể hình. Trả lời bằng tiếng Việt, \
ngắn gọn, thực tế, dựa trên thông tin cá nhân của user được cung cấp bên dưới \
nếu có liên quan. Nếu user hỏi điều gì ngoài phạm vi thể hình/dinh dưỡng/sức \
khỏe, lịch sự từ chối và hướng họ quay lại chủ đề tập luyện. Không đưa ra chẩn \
đoán y khoa — nếu có dấu hiệu chấn thương/bệnh lý, khuyên user gặp bác sĩ.

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
            temperature=0.7,
            max_output_tokens=800,
        ),
    )
    text = response.text
    if not text:
        raise RuntimeError("Gemini trả về phản hồi rỗng.")
    return text
