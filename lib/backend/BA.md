# Posture X Backend — Huong dan cai dat day du

> Tai lieu nay ghi lai toan bo cac buoc tu dau den khi server chay duoc.
> Moi truong thuc te: Windows 11, Python 3.13, MySQL 8.x.

---

## Yeu cau phan mem

| Phan mem | Phien ban da test | Ghi chu |
|---|---|---|
| Windows | 10 / 11 | |
| Python | **3.13.x** | Tai tai python.org |
| MySQL Server | **8.x** | Tai tai dev.mysql.com, hoac dung ban di kem XAMPP/Laragon |
| Git | Bat ky | Tuy chon |

---

## Buoc 1 — Cai Python 3.13

Tai tai: https://www.python.org/downloads/

Trong qua trinh cai: **tick vao "Add Python to PATH"**.

Kiem tra sau khi cai:
```powershell
python --version
# Python 3.13.x
```

---

## Buoc 2 — Cai MySQL Server

Tai tai: https://dev.mysql.com/downloads/installer/ (hoac dung MySQL di kem trong XAMPP/Laragon neu da co san).

Trong qua trinh cai:
- Ghi nho **port** (mac dinh `3306` — neu may da co MySQL khac chay san thi co the phai doi port, vi du `3307`)
- Dat **password cho user `root`** (nho lai password nay)

Tao database (dung MySQL Workbench, hoac dong lenh `mysql -u root -p`):
```sql
CREATE DATABASE posturex CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
```

> Neu may co nhieu instance MySQL cung chay (vi du tu XAMPP/Laragon + MySQL Installer), kiem tra dung port dang lang nghe bang:
> ```powershell
> netstat -an | findstr "LISTENING" | findstr "330"
> ```

---

## Buoc 3 — Lay source code

```powershell
# Neu co git:
git clone <repo-url> posture-x-backend
cd posture-x-backend

# Hoac giai nen folder posture-x-backend vao noi ban muon
cd posture-x-backend
```

---

## Buoc 4 — Tao virtual environment va cai packages

```powershell
python -m venv venv
venv\Scripts\activate
pip install -r requirements.txt
```

> Lan dau cai mat 5-10 phut vi MediaPipe (~200MB) va OpenCV (~40MB).

### Cai them cac package bat buoc (khong co trong requirements.txt goc):

```powershell
pip install greenlet
pip install "bcrypt==4.2.0"
```

| Package | Ly do can them |
|---|---|
| `greenlet` | SQLAlchemy async yeu cau |
| `aiomysql` | Driver ket noi MySQL async (co san trong requirements.txt) |
| `bcrypt==4.2.0` | `passlib 1.7.4` khong tuong thich `bcrypt 5.x` |

---

## Buoc 5 — Tai model AI (MediaPipe)

```powershell
python download_models.py
```

Cho den khi hien `Done! (9.0 MB)`. Model luu tai:
`app/ml/models/pose_landmarker_full.task`

---

## Buoc 6 — Cau hinh file .env

```powershell
copy .env.example .env
```

Mo file `.env` sua cac gia tri:

```env
DB_HOST=localhost
DB_PORT=3306
DB_NAME=posturex
DB_USER=root
DB_PASSWORD=matkhau_root_cua_ban

SECRET_KEY=posturex-dev-secret-key-change-in-production
VIDEO_STORAGE_PATH=storage/videos
DEBUG=True
```

> `DB_PORT` doi thanh port MySQL thuc te dang chay (xem ghi chu o Buoc 2 neu may co nhieu instance MySQL).

---

## Buoc 7 — Tao bang trong database

Du an dung schema PostureX day du (Roles/Users/UserProfiles/WorkoutSessions/...,
xem `sql/postureX123_schema.sql`) cho phan tai khoan/phan quyen, cong voi
`videos`/`workouts` don gian rieng cua backend. Can chay **2 buoc theo dung thu tu**:

```powershell
# 1) Tao Roles/Users/UserProfiles + toan bo bang tham chieu (Exercises, Goals...)
#    XOA VA TAO LAI database poturex123 tu dau — chi chay khi muon reset sach.
python sql\run_schema.py

# 2) Tao rieng videos/workouts (FK tro toi Users.UserId) — an toan chay lai nhieu lan,
#    KHONG dung toi Users/Roles.
python create_tables.py
# Tables created successfully.
```

> Luu y: MySQL tren nhieu may Windows co `lower_case_table_names=1`, nghia la
> `Users` va `users` la CUNG MOT bang. Vi vay `create_tables.py` chi drop/tao
> `videos`/`workouts`, khong dong toi `Users`.

---

## Buoc 8 — Tao tai khoan Admin

```powershell
python create_admin.py admin@posturex.com Admin123 "Super Admin"
# Admin account created: admin@posturex.com
```

> Neu email da ton tai, script tu dong cap quyen `is_admin=True` cho account do.

---

## Buoc 9 — Khoi dong server

```powershell
venv\Scripts\activate
uvicorn app.main:app --reload --port 9000
```

> Dung **port 9000** vi Windows doi khi giu port 8000 sau khi kill process.

Kiem tra server chay:
```powershell
curl http://localhost:9000/health
# {"status":"ok","app":"Posture X"}
```

---

## Buoc 10 — Test API qua Swagger UI

Mo trinh duyet vao: **http://localhost:9000/docs**

### Dang nhap lay token:
1. Tim muc **`auth`** -> click `POST /api/v1/auth/login`
2. Click **"Try it out"** -> dien:
```json
{
  "email": "admin@posturex.com",
  "password": "Admin123"
}
```
3. Click **"Execute"** -> copy gia tri `access_token` trong Response body

### Gan token vao Swagger:
1. Click nut **"Authorize"** (bieu tuong o khoa) o dau trang
2. Dan token vao o **Value** (chi dan chuoi `eyJ...`, **khong** can them `Bearer `)
3. Click **"Authorize"** -> **"Close"**

Sau do toan bo request deu tu dong co token. O khoa chuyen thanh bi khoa = thanh cong.

---

## Bang phan quyen

| Chuc nang | User | Admin |
|---|:---:|:---:|
| Dang ky / Dang nhap | OK | OK |
| Chinh sua ho so | OK | OK |
| Phan tich tu the bang AI (WebSocket) | OK | OK |
| Xem lich su tap luyen cua ban than | OK | OK |
| Quan ly nguoi dung | - | OK |
| Quan ly bai tap (tat ca user) | - | OK |
| Quan ly mo hinh AI / cau hinh he thong | - | OK |
| Xem thong ke toan he thong | - | OK |
| Xoa tai khoan nguoi dung | - | OK |

---

## Danh sach API endpoint

### Auth
| Method | URL | Mo ta |
|---|---|---|
| POST | `/api/v1/auth/register` | Dang ky tai khoan |
| POST | `/api/v1/auth/login` | Dang nhap, lay JWT token |

### User (can dang nhap)
| Method | URL | Mo ta |
|---|---|---|
| GET | `/api/v1/users/me` | Xem thong tin ban than |
| PATCH | `/api/v1/users/me` | Chinh sua ho so (ten, mat khau) |

### Workout (can dang nhap)
| Method | URL | Mo ta |
|---|---|---|
| POST | `/api/v1/workouts` | Luu buoi tap |
| GET | `/api/v1/workouts` | Danh sach lich su tap cua ban than |
| GET | `/api/v1/workouts/{id}` | Chi tiet 1 buoi tap |

### Video (can dang nhap)
| Method | URL | Mo ta |
|---|---|---|
| POST | `/api/v1/videos/upload` | Upload video bai tap |
| GET | `/api/v1/videos` | Danh sach video cua ban than |
| GET | `/api/v1/videos/{id}` | Chi tiet 1 video |

### Real-time AI (WebSocket)
| Protocol | URL | Mo ta |
|---|---|---|
| WS | `/api/v1/ws/analyze` | Phan tich tu the theo tung frame |

### Admin (can is_admin=True)
| Method | URL | Mo ta |
|---|---|---|
| GET | `/api/v1/admin/stats` | Thong ke toan he thong |
| GET | `/api/v1/admin/users` | Danh sach tat ca user |
| PATCH | `/api/v1/admin/users/{id}` | Cap nhat user (active, role, ten) |
| DELETE | `/api/v1/admin/users/{id}` | Xoa tai khoan |
| GET | `/api/v1/admin/workouts` | Tat ca workout cua moi user |
| DELETE | `/api/v1/admin/workouts/{id}` | Xoa buoi tap |
| GET | `/api/v1/admin/videos` | Tat ca video cua moi user |
| DELETE | `/api/v1/admin/videos/{id}` | Xoa video |
| GET | `/api/v1/admin/config` | Xem cau hinh AI |
| PATCH | `/api/v1/admin/config` | Cap nhat nguong phan tich AI |

---

## Cau truc thu muc (Scaffold)

```
posture-x-backend/
|
├── app/
│   ├── main.py                        # FastAPI app, CORS, /health
│   |
│   ├── core/
│   │   ├── config.py                  # Doc .env, tao MySQL URL
│   │   ├── security.py                # JWT tao/giai ma, bcrypt hash
│   │   └── database.py                # Async engine + session + Base
│   |
│   ├── api/
│   │   └── v1/
│   │       ├── router.py              # Gop tat ca route
│   │       └── routes/
│   │           ├── auth.py            # POST /register, /login
│   │           ├── users.py           # GET /me, PATCH /me
│   │           ├── workouts.py        # CRUD lich su tap
│   │           ├── videos.py          # Upload + truy van video
│   │           ├── realtime.py        # WS /ws/analyze (COT LOI)
│   │           └── admin.py           # Cac endpoint admin
│   |
│   ├── ml/
│   │   ├── pose_estimator.py          # MediaPipe Tasks API wrapper
│   │   ├── angle_utils.py             # calculate_angle() bang numpy
│   │   ├── rep_counter.py             # State machine dem rep
│   │   ├── session_state.py           # Trang thai per-connection
│   │   ├── models/
│   │   │   └── pose_landmarker_full.task   # Model AI (tai bang download_models.py)
│   │   └── analyzers/
│   │       ├── base.py                # Abstract ExerciseAnalyzer
│   │       └── squat.py               # Phan tich squat, feedback TV
│   |
│   ├── models/                        # SQLAlchemy ORM
│   │   ├── user.py                    # Bang users (co is_admin)
│   │   ├── video.py                   # Bang videos
│   │   └── workout.py                 # Bang workouts
│   |
│   ├── schemas/                       # Pydantic v2
│   │   ├── user.py                    # UserCreate, UserUpdate, UserOut
│   │   ├── auth.py                    # LoginRequest, TokenResponse
│   │   ├── analysis.py                # FrameAnalysisResult, KeyAngles
│   │   ├── video.py                   # VideoOut
│   │   └── admin.py                   # AdminUserOut, SystemStats, AIConfig
│   |
│   ├── crud/
│   │   ├── user.py                    # get_user_by_email/id, create_user
│   │   ├── video.py                   # get_videos_by_user, get_video_by_id
│   │   └── admin.py                   # get_all_users, stats, delete...
│   |
│   ├── services/
│   │   └── video_service.py           # Luu file video + tao metadata DB
│   |
│   └── utils/
│       └── deps.py                    # get_current_user, get_current_admin
|
├── storage/
│   └── videos/                        # File video luu tai day (gitignore)
|
├── tests/
│   ├── test_health.py
│   └── test_angle_utils.py
|
├── create_tables.py                   # Tao bang DB (chay 1 lan)
├── create_admin.py                    # Tao tai khoan admin dau tien
├── download_models.py                 # Tai MediaPipe model
├── .env                               # Cau hinh thuc (KHONG commit)
├── .env.example                       # Mau cau hinh
├── requirements.txt
├── Dockerfile
└── BA.md                              # File huong dan nay
```

---

## Test WebSocket phan tich real-time

Cai them `websockets`:
```powershell
pip install websockets
```

Tao file `test_ws_client.py`:
```python
import asyncio, base64, json, cv2
import websockets

async def main():
    uri = "ws://localhost:9000/api/v1/ws/analyze"
    async with websockets.connect(uri) as ws:
        await ws.send(json.dumps({"exercise": "squat"}))
        print("Server:", await ws.recv())

        cap = cv2.VideoCapture(0)
        try:
            for _ in range(100):
                ret, frame = cap.read()
                if not ret:
                    break
                _, buf = cv2.imencode(".jpg", frame, [cv2.IMWRITE_JPEG_QUALITY, 70])
                await ws.send(base64.b64encode(buf.tobytes()).decode())
                r = json.loads(await ws.recv())
                print(f"Reps:{r['rep_count']} | Phase:{r['phase']} | OK:{r['correct']} | Errors:{r['errors']}")
                await asyncio.sleep(0.033)
        finally:
            cap.release()

asyncio.run(main())
```

```powershell
python test_ws_client.py
```

---

## Test upload video

```powershell
# Dang nhap lay token
$TOKEN = "eyJ..."

# Upload video
curl -X POST http://localhost:9000/api/v1/videos/upload `
  -H "Authorization: Bearer $TOKEN" `
  -F "file=@C:\path\to\workout.mp4" `
  -F "exercise=squat"

# Xem danh sach video
curl http://localhost:9000/api/v1/videos `
  -H "Authorization: Bearer $TOKEN"
```

---

## Test Admin API

```powershell
# Login admin lay token
$ADMIN = "eyJ..."   # token cua admin@posturex.com

# Thong ke he thong
curl http://localhost:9000/api/v1/admin/stats `
  -H "Authorization: Bearer $ADMIN"
# {"total_users":2,"active_users":2,"admin_users":1,"total_videos":0,"total_workouts":0,"total_reps":0}

# Danh sach tat ca user
curl http://localhost:9000/api/v1/admin/users `
  -H "Authorization: Bearer $ADMIN"

# Cap quyen admin cho user ID=2
curl -X PATCH http://localhost:9000/api/v1/admin/users/2 `
  -H "Content-Type: application/json" `
  -H "Authorization: Bearer $ADMIN" `
  -d '{"is_admin": true}'

# Vo hieu hoa user ID=2
curl -X PATCH http://localhost:9000/api/v1/admin/users/2 `
  -H "Content-Type: application/json" `
  -H "Authorization: Bearer $ADMIN" `
  -d '{"is_active": false}'

# Xoa user ID=2
curl -X DELETE http://localhost:9000/api/v1/admin/users/2 `
  -H "Authorization: Bearer $ADMIN"

# Xem cau hinh AI hien tai
curl http://localhost:9000/api/v1/admin/config `
  -H "Authorization: Bearer $ADMIN"

# Cap nhat nguong phan tich squat
curl -X PATCH http://localhost:9000/api/v1/admin/config `
  -H "Content-Type: application/json" `
  -H "Authorization: Bearer $ADMIN" `
  -d '{
    "squat_knee_depth_threshold": 90.0,
    "squat_back_straight_min": 155.0,
    "squat_knee_overshoot_ratio": 0.05,
    "squat_rep_down_threshold": 90.0,
    "squat_rep_up_threshold": 160.0,
    "pose_model_complexity": 1,
    "pose_min_detection_confidence": 0.5
  }'

# User thuong goi admin -> 403
# {"detail":"Ban khong co quyen admin."}
```

---

## Xu ly loi thuong gap

| Loi | Nguyen nhan | Cach fix |
|---|---|---|
| `mediapipe has no attribute 'solutions'` | API cu da bi xoa | Binh thuong, code dung Tasks API moi roi |
| `(trapped) error reading bcrypt version` | passlib khong doc duoc version bcrypt | Chi la WARNING, bo qua |
| `password cannot be longer than 72 bytes` | bcrypt 5.x khong tuong thich passlib | `pip install "bcrypt==4.2.0"` |
| `greenlet library is required` | Thieu dependency | `pip install greenlet` |
| `No matching distribution for mediapipe==0.10.18` | Version khong ton tai | `pip install mediapipe==0.10.35` |
| `Access denied for user 'root'@'localhost'` | Sai password/user trong `.env` | Kiem tra lai `DB_USER`/`DB_PASSWORD` |
| `Unknown database 'posturex'` | Chua tao database | Chay `CREATE DATABASE posturex;` trong MySQL truoc |
| `Can't connect to MySQL server` | Sai `DB_HOST`/`DB_PORT`, hoac MySQL chua chay | Kiem tra service MySQL dang chay va dung port (xem Buoc 2) |
| `Cannot add foreign key constraint` khi `create_tables.py` tao bang moi (khong co FK) | Metadata FK "rac" con sot trong database cu | `DROP DATABASE poturex123; CREATE DATABASE poturex123 ...;` roi chay lai `sql\run_schema.py` |
| `ping() missing 1 required positional argument: 'reconnect'` | Bug tuong thich SQLAlchemy 2.0.36 + aiomysql khi bat `pool_pre_ping` | Da tat san trong `app/core/database.py` (`pool_pre_ping=False`) |
| `[Errno 10048]` port 8000 bi giu | Windows socket zombie | Dung `--port 9000` hoac restart may |
| Model khong tim thay | Chua tai model | `python download_models.py` |
| Swagger hien loi do o import | VS Code dung sai Python | Ctrl+Shift+P -> Python: Select Interpreter -> chon `.\venv\Scripts\python.exe` |

---

## Tom tat lenh hang ngay

```powershell
cd posture-x-backend
venv\Scripts\activate
uvicorn app.main:app --reload --port 9000
```

Swagger UI: **http://localhost:9000/docs**

---

## Thong tin ky thuat

| Thanh phan | Cong nghe |
|---|---|
| Web framework | FastAPI 0.115 + Uvicorn |
| Database | MySQL 8.x |
| ORM | SQLAlchemy 2.0 async |
| DB driver | aiomysql |
| AI / ML | MediaPipe 0.10.35 (Tasks API) + OpenCV + NumPy |
| Auth | JWT (python-jose) + bcrypt (passlib) |
| Real-time | WebSocket native FastAPI |
| File I/O | aiofiles (async) |
| Python | 3.13 |
