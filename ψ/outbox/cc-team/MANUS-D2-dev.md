<!-- cc-team deliverable
 group: MANUS (manus-parity scaffolds: tools, agent loop, SSE, workspace stream, artifacts, contract tests, docs)
 member: D2 role=dev model=deepseek/deepseek-v4-flash
 finish_reason: stop | tokens: {"prompt_tokens":61,"completion_tokens":677,"total_tokens":738,"prompt_tokens_details":{"cached_tokens":0,"audio_tokens":0,"video_tokens":0},"completion_tokens_details":{"reasoning_tokens":164,"image_tokens":0},"cache_creation_input_tokens":0} | 9s
 generated: 2026-06-13T05:45:31.014Z -->
# การสร้างเครื่องมือ (Tool Authoring)

## การสร้างเครื่องมือใหม่ที่ implement uniform interface

- สร้างคลาสที่สืบทอดจาก `BaseTool` หรือ implement interface ที่กำหนด
- ต้องมีเมธอด `execute(params)` ซึ่งรับ `dict` และคืนค่า `dict` ตามรูปแบบที่ตกลงกัน
- กำหนด metadata เช่น `name`, `description`, `parameters` (schema) เพื่อให้ agent รู้จัก

```python
class MyTool(BaseTool):
    name = "my_tool"
    description = "Does something"
    parameters = {
        "type": "object",
        "properties": {
            "input": {"type": "string"}
        }
    }
    async def execute(self, params: dict) -> dict:
        result = do_something(params["input"])
        return {"output": result}
```

## การลงทะเบียนและให้ agent loop ค้นพบ

- ลงทะเบียนเครื่องมือใน registry ส่วนกลาง (เช่น `ToolRegistry.register(MyTool())`)
- หรือใช้ decorator `@tool` เพื่อ auto-register
- agent loop จะ scan registry และเพิ่ม tool metadata ใน system prompt
- หากเป็น plugin system ให้วางไฟล์ในโฟลเดอร์ที่กำหนด ระบบจะโหลดอัตโนมัติ

```python
ToolRegistry.register(MyTool())
```

## กฎความปลอดภัย

### codeExec timeout
- กำหนด timeout สูงสุดสำหรับการรันโค้ด (เช่น 30 วินาที)
- ใช้ `asyncio.wait_for` หรือ `subprocess timeout`
- หากเกินเวลา ยกเลิกและคืน error

```python
try:
    result = await asyncio.wait_for(exec_code(params), timeout=30)
except asyncio.TimeoutError:
    return {"error": "Execution timeout"}
```

### file traversal guards
- ห้ามเข้าถึงไฟล์นอก working directory ที่อนุญาต
- ใช้ path sanitization: แปลง path เป็น absolute แล้วตรวจสอบว่าเริ่มต้นด้วย allowed base path
- ปฏิเสธ path ที่มี `../` หรือ symlink นอกขอบเขต

```python
from pathlib import Path
BASE_DIR = Path("/allowed/dir")
user_path = Path(params["path"]).resolve()
if not str(user_path).startswith(str(BASE_DIR)):
    raise PermissionError("Access denied")
```
