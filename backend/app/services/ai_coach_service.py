"""Gọi Gemini API để trả lời tư vấn tập luyện/dinh dưỡng cho user."""

import asyncio
import logging

from google import genai
from google.genai import errors as genai_errors
from google.genai import types

from app.core.config import settings
from app.schemas.coach import AiPlanResponse, ChatMessage

logger = logging.getLogger(__name__)

# Gemini free tier thỉnh thoảng trả 503 "model đang quá tải" khi nhu cầu
# toàn cầu tăng đột biến — lỗi tạm thời, thử lại sau vài giây THƯỜNG sẽ qua,
# nên retry cùng model vài lần trước (khác 400/404/429 bên dưới — sai tham
# số/hết quota/model đã tắt thì retry cùng model chắc chắn vẫn sai, chuyển
# model dự phòng ngay không cần thử lại).
#
# Sửa 05/10/2026 (audit thật trên production, xem CHANGELOG): "thường sẽ
# qua" không phải lúc nào cũng đúng — log thật ghi nhận 62 lần 503 lặp lại
# trong vài tuần, có đợt tới 14 lần/giờ, và cả 3 lần retry (~7-8 giây) đều
# không đủ để model chính hết quá tải. Trước đây hết lượt retry mà vẫn 503
# thì raise luôn, KHÔNG rơi xuống thử model dự phòng dù danh sách đó đã có
# sẵn — giờ 503 cũng chuyển model dự phòng sau khi hết lượt retry, giống hệt
# 400/404/429, chỉ khác ở chỗ 503 có thử lại vài lần trước khi chuyển.
_RETRYABLE_CODE = 503
_MAX_ATTEMPTS = 3
_RETRY_DELAYS_SECONDS = (1, 3)

# Khi model chính bị 404 (Google tắt model cũ), tự động thử các model dự
# phòng theo thứ tự — tránh downtime khi Google deprecate model mà không báo.
_FALLBACK_MODELS = ('gemini-2.0-flash', 'gemini-1.5-flash')


async def _generate_with_retry(**kwargs):
    """Gọi `generate_content`, tự thử lại tối đa 2 lần nếu Gemini báo 503 —
    hết lượt thử mà vẫn 503 thì chuyển sang model dự phòng tiếp theo, y hệt
    cách xử lý 400/404 (không hỗ trợ tham số / đã bị tắt) hoặc 429 (hết
    quota free tier), chỉ khác là 503 có thử lại vài lần trước khi chuyển."""
    client = _client()
    primary = kwargs.pop('model', settings.GEMINI_MODEL)
    models_to_try = [primary] + [m for m in _FALLBACK_MODELS if m != primary]

    last_err: Exception | None = None
    for model in models_to_try:
        for attempt in range(_MAX_ATTEMPTS):
            try:
                return await client.aio.models.generate_content(model=model, **kwargs)
            except genai_errors.APIError as e:
                if e.code in (400, 404, 429):
                    logger.warning(
                        "Model %s trả HTTP %d — thử model dự phòng tiếp theo",
                        model, e.code,
                    )
                    last_err = e
                    break  # sang model tiếp theo
                if e.code in (401, 403):
                    # API key sai/hết hạn — mọi model dùng chung key này đều
                    # sẽ trả cùng lỗi, không có ích khi thử tiếp.
                    raise
                if e.code != _RETRYABLE_CODE:
                    # Lỗi HTTP không xác định — thử model dự phòng, không raise ngay.
                    logger.warning(
                        "Model %s trả HTTP %d — thử model dự phòng tiếp theo",
                        model, e.code,
                    )
                    last_err = e
                    break
                last_err = e
                if attempt == _MAX_ATTEMPTS - 1:
                    logger.warning(
                        "Model %s vẫn 503 sau %d lần thử — thử model dự phòng tiếp theo",
                        model, _MAX_ATTEMPTS,
                    )
                    break  # sang model tiếp theo, không raise ngay
                delay = _RETRY_DELAYS_SECONDS[attempt]
                logger.warning(
                    "Gemini 503 (quá tải) — thử lại lần %d/%d sau %ds",
                    attempt + 2, _MAX_ATTEMPTS, delay,
                )
                await asyncio.sleep(delay)
            except Exception as e:
                # Network error, SSL error, timeout, v.v. — không phải lỗi
                # API, nhưng vẫn nên thử model dự phòng trước khi bỏ cuộc.
                logger.warning(
                    "Model %s: lỗi kết nối (%s: %s) — thử model dự phòng tiếp theo",
                    model, type(e).__name__, e,
                )
                last_err = e
                break  # sang model tiếp theo

    if last_err is not None:
        raise last_err
    raise AssertionError("unreachable: loop always returns or raises")

_SYSTEM_PROMPT = """Bạn là huấn luyện viên thể hình AI cấp cao của ứng dụng \
PostureX — chỉ tư vấn về: chế độ tập luyện, kỹ thuật động tác, dinh dưỡng, \
phục hồi và lối sống lành mạnh liên quan đến tập gym/thể hình. Nếu user hỏi \
điều gì ngoài phạm vi này, lịch sự từ chối và hướng họ quay lại chủ đề tập \
luyện. Không đưa ra chẩn đoán y khoa — nếu có dấu hiệu chấn thương/bệnh lý, \
khuyên user gặp bác sĩ/chuyên gia vật lý trị liệu.

QUAN TRỌNG — PHÂN BIỆT CÂU HỎI MƠ HỒ vs CÂU HỎI CỤ THỂ vs CÂU HỎI TIẾP THEO:
- Nếu tin nhắn MƠ HỒ, ngắn, KHÔNG nói rõ user cần hỗ trợ về việc gì cụ thể \
(vd "help me", "giúp tôi", "giúp mình với", "tư vấn cho tôi", hoặc chỉ chào \
hỏi) — dù là tin nhắn đầu tiên hay không: TUYỆT ĐỐI KHÔNG tự suy diễn rồi \
đưa ra cả bài phân tích dài. Thay vào đó, chào lại ngắn gọn (1-2 câu) và HỎI \
LẠI cụ thể user đang cần hỗ trợ về mảng nào — vd "Bạn cần mình hỗ trợ về kế \
hoạch tập, dinh dưỡng, kỹ thuật động tác, hay vấn đề gì khác?". Chỉ phân \
tích sâu SAU KHI user đã nói rõ họ cần gì.
- Nếu tin nhắn nói RÕ user cần gì (dù là tin nhắn đầu tiên) và liên quan tới \
kế hoạch tập/tiến độ/dinh dưỡng (vd "cho tôi lời khuyên tập luyện tuần này", \
"tôi muốn tăng cơ"): hãy PHÂN TÍCH SÂU đầy đủ theo cấu trúc ở dưới ngay, \
không cần hỏi lại.
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

KIẾN THỨC NỀN — dùng đúng các con số dưới đây làm chuẩn khi tư vấn (có căn cứ \
khoa học thể thao hiện hành: ISSN, ACSM, NSCA), thay vì đoán mò hay bịa số. \
Đây là khung tham chiếu chung — vẫn phải điều chỉnh theo hồ sơ/mục tiêu cụ \
thể của user, không áp dụng máy móc:

1) TẬP LUYỆN — số set/rep/nghỉ theo mục tiêu:
- Tăng sức mạnh (strength): 1-6 rep/set, tải 80-100% 1RM, nghỉ 3-5 phút giữa \
các set để phục hồi hệ thần kinh hoàn toàn.
- Tăng cơ (hypertrophy): 6-12 rep/set (rộng hơn: 6-30 rep vẫn hiệu quả nếu \
tập gần tới ngưỡng thất bại cơ), 3-4 set/bài, nghỉ 1-2 phút; một số nghiên \
cứu mới cho thấy nghỉ 2-3 phút giúp tăng cơ tốt hơn vì giữ được khối lượng \
tập luyện cao hơn qua các set.
- Sức bền cơ (endurance): từ 15 rep trở lên, tạ nhẹ, nghỉ ngắn (30-60s).
- Nguyên tắc "progressive overload" (tăng dần độ khó — thêm tạ/rep/set theo \
tuần) là yếu tố quyết định để cơ tiếp tục phát triển, tập mãi một mức sẽ chững.

2) PHỤC HỒI CƠ BẮP:
- Một nhóm cơ cần 48-72 giờ để phục hồi hoàn toàn sau buổi tập cường độ cao. \
Nhóm cơ nhỏ (tay, vai, bắp chân) thường đủ 48h; nhóm cơ lớn (đùi, lưng, ngực) \
nên chờ đủ 72h nếu buổi tập có nhiều động tác hạ tạ chậm (eccentric).
- Đau nhức cơ trễ (DOMS) thường đạt đỉnh ở giờ 24-48 sau tập, giảm dần và hết \
hẳn quanh mốc 72h — đây là hiện tượng bình thường, không phải dấu hiệu chấn \
thương, nhưng nên tránh tập nặng cùng nhóm cơ đó khi còn đau nhiều.
- Nên chia lịch theo nhóm cơ luân phiên (vd Push/Pull/Legs, Upper/Lower) thay \
vì tập toàn thân cường độ cao liên tục mỗi ngày.

3) DINH DƯỠNG:
- Đạm (protein): 1.4-2.0 g/kg thể trọng/ngày là đủ để duy trì/tăng cơ với \
hầu hết người tập thường xuyên. Trong giai đoạn ăn thiếu calo để giảm mỡ, \
nên tăng lên 2.3-3.1 g/kg để hạn chế mất cơ. Nên chia đều mỗi bữa 20-40g đạm \
cách nhau 3-4 tiếng, thay vì dồn hết vào 1 bữa — hấp thu tổng hợp cơ tốt hơn.
- Giảm cân: thâm hụt 300-500 kcal/ngày so với nhu cầu duy trì (TDEE), tương \
đương giảm khoảng 0.5-1kg/tuần — mức an toàn, bền vững, hạn chế mất cơ.
- Tăng cơ: thặng dư 200-300 kcal/ngày là đủ; thặng dư quá 500 kcal thường chỉ \
làm tăng mỡ nhiều hơn là tăng cơ.
- Nước: người bình thường cần khoảng 2-3 lít nước/ngày (nữ ~2L, nam ~2.5-3L, \
tính cả nước từ thực phẩm); người tập luyện cường độ cao hoặc thời tiết nóng \
có thể cần 4-6 lít/ngày. Dấu hiệu đủ nước dễ nhận biết: nước tiểu vàng nhạt.

4) GIẤC NGỦ:
- Người trưởng thành nói chung cần 7-9 tiếng/đêm. Người tập luyện thường \
xuyên nên hướng tới 8-10 tiếng vì phần lớn quá trình phục hồi mô cơ và tiết \
hormone tăng trưởng diễn ra trong giấc ngủ sâu.
- Ngủ thiếu (dưới 6-7 tiếng liên tục nhiều ngày) làm giảm tổng hợp protein \
cơ, tăng cortisol (hormone gây dị hoá cơ/stress), giảm hiệu suất tập và kéo \
dài thời gian phục hồi.
- Ngày tập nặng có thể cân nhắc thêm giấc ngủ ngắn (nap) 20-30 phút ban ngày \
để hỗ trợ phục hồi, không thay thế cho giấc ngủ đêm đủ giờ.

5) THỰC PHẨM BỔ SUNG PHỔ BIẾN (chỉ hỗ trợ thêm khi chế độ ăn thật đã ổn, \
không phải bắt buộc, không thay thế thực phẩm thật):
- Creatine monohydrate: 3-5g/ngày, uống đều đặn mỗi ngày (không cần "load" \
liều cao ban đầu) — một trong những supplement được nghiên cứu nhiều nhất, \
an toàn cho người khoẻ mạnh dùng lâu dài, giúp tăng sức mạnh và khối cơ.
- Whey protein: chỉ là nguồn đạm cô đặc tiện lợi khi khó nạp đủ đạm từ thực \
phẩm thật (thịt/cá/trứng/sữa/đậu), không phải "thuốc tăng cơ" và không bắt \
buộc nếu chế độ ăn đã đủ đạm.

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


async def ask_stream(
    *, message: str, history: list[ChatMessage], user_context: str
):
    """Như ask() nhưng yield từng đoạn text ngay khi Gemini trả về.

    Dùng cho endpoint SSE /chat/stream — token đầu tiên về trong ~1 giây
    thay vì chờ toàn bộ response (10-20 giây).

    Không có retry/fallback: một khi đã bắt đầu yield thì không thể quay đầu
    sang model dự phòng mà không xoá những gì client đã nhận. Nếu lỗi trước
    chunk đầu tiên, exception lan truyền lên route; nếu lỗi giữa chừng, route
    gửi event lỗi rồi đóng stream."""
    client = _client()
    async for chunk in client.aio.models.generate_content_stream(
        model=settings.GEMINI_MODEL,
        contents=_to_contents(history, message),
        config=types.GenerateContentConfig(
            system_instruction=_SYSTEM_PROMPT.format(user_context=user_context),
            temperature=0.6,
            max_output_tokens=3072,
        ),
    ):
        if chunk.text:
            yield chunk.text


async def ask(*, message: str, history: list[ChatMessage], user_context: str) -> str:
    """Gửi 1 lượt hỏi tới Gemini, trả về câu trả lời dạng text.

    Ném ra Exception nguyên bản nếu gọi API thất bại — route gọi hàm này
    chịu trách nhiệm bọc lại thành HTTPException phù hợp."""
    response = await _generate_with_retry(
        model=settings.GEMINI_MODEL,
        contents=_to_contents(history, message),
        config=types.GenerateContentConfig(
            system_instruction=_SYSTEM_PROMPT.format(user_context=user_context),
            temperature=0.6,
            max_output_tokens=3072,
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
- CHỈ dùng tên bài tập trong danh mục "Bài tập có sẵn trong app" bên dưới, \
chép lại CHÍNH XÁC từng chữ — không bịa bài tập app không có, không rút gọn \
hay đổi cách viết tên. Nếu danh mục rỗng, dùng tên bài tập thể hình phổ \
biến, đơn giản (không cần thiết bị đặc biệt).
- Bài có dấu `*` ở đầu tên là bài app CHẤM ĐƯỢC KỸ THUẬT bằng camera — ưu \
tiên chọn những bài này khi có lựa chọn tương đương, vì người dùng nhận được \
phản hồi tư thế theo thời gian thực thay vì chỉ xem video. Dấu `*` chỉ là \
đánh dấu, KHÔNG được đưa vào tên bài trong kết quả trả về.
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
- Nếu có mục "Trao đổi gần đây với AI Coach" bên dưới, ĐỌC KỸ và ưu tiên tôn \
trọng nguyện vọng/ràng buộc user đã nói ra ở đó (vd "tránh tập lưng vì đang \
đau", "muốn tập trọng tâm chân tuần này", "chỉ có 30 phút mỗi buổi") khi soạn \
lịch — đừng phớt lờ chỉ vì đó là hội thoại chứ không phải một trường dữ liệu \
có cấu trúc. Nếu không có mục đó hoặc nó không liên quan gì đến việc lên lịch, \
bỏ qua, không cần nhắc tới trong kết quả.

Thông tin user:
{user_context}

Bài tập có sẵn trong app (gom theo nhóm cơ, `*` = app chấm được kỹ thuật):
{exercise_catalogue}
{chat_context}"""


async def generate_plan(
    *, user_context: str, exercise_catalogue: str, chat_context: str = ""
) -> AiPlanResponse:
    """Sinh lịch tập + dinh dưỡng 7 ngày cá nhân hóa bằng Gemini, trả về đã
    parse sẵn thành `AiPlanResponse` (structured output — không cần tự parse
    JSON tay, SDK validate theo đúng schema Pydantic).

    `chat_context` (tuỳ chọn) nối lịch tập với hội thoại AI Coach — trước
    11/09/2026 hai tính năng này hoàn toàn tách rời, sinh lịch không biết gì
    về nội dung user vừa trò chuyện trong chat. Rỗng thì bỏ qua hoàn toàn,
    không đổi hành vi cũ.

    Ném ra Exception nguyên bản nếu gọi API thất bại hoặc response không hợp
    lệ — route gọi hàm này chịu trách nhiệm bọc lại thành HTTPException."""
    prompt = _PLAN_SYSTEM_PROMPT.format(
        user_context=user_context,
        exercise_catalogue=exercise_catalogue,
        chat_context=(
            f"\nTrao đổi gần đây với AI Coach:\n{chat_context}" if chat_context else ""
        ),
    )
    response = await _generate_with_retry(
        model=settings.GEMINI_MODEL,
        contents=[types.Content(role="user", parts=[types.Part(text=prompt)])],
        config=types.GenerateContentConfig(
            response_mime_type="application/json",
            response_schema=AiPlanResponse,
            temperature=0.8,
            max_output_tokens=3072,
        ),
    )
    parsed = response.parsed
    if not isinstance(parsed, AiPlanResponse):
        raise RuntimeError("Gemini trả về dữ liệu lịch tập không hợp lệ.")
    return parsed
