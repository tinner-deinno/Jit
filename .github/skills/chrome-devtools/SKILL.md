# chrome-devtools Skill

**Organ**: ตา (Eye) + มือ (Hand) — ดู UI จริง, inspect element, วิเคราะห์เว็บ  
**Agent**: innova / Hermes (Discord bot อนุ)  
**Location**: `hermes-discord/chrome-tools.js`

## สิ่งที่ทำได้

| คำสั่ง | ผล |
|--------|-----|
| `chrome open <url>` | เปิด URL ใน headless Chrome — คืนค่า title, status, loadTime |
| `chrome screenshot <url>` | ถ่าย screenshot → บันทึกใน /tmp/ |
| `chrome inspect <url> <selector>` | inspect DOM element — tagName, text, rect, attributes |
| `chrome css <url> <selector>` | computed CSS styles ของ element |
| `chrome ui <url>` | วิเคราะห์ UI ทั้งหน้า — headings, colors, fonts, stats |
| `chrome js <url> <expression>` | รัน JavaScript ใน page context |

## วิธีใช้ใน Discord (bot อนุ)

```
!AnuT1n chrome open https://example.com
!AnuT1n chrome screenshot https://mdes-innova.online
!AnuT1n chrome inspect https://example.com h1
!AnuT1n chrome css https://example.com .hero
!AnuT1n chrome ui https://example.com
!AnuT1n chrome js https://example.com "document.title"
```

## วิธีใช้เป็น MCP Server (Claude Code)

เพิ่มใน `claude_desktop_config.json` หรือ `.claude/mcp_config.json`:

```json
{
  "mcpServers": {
    "chrome-devtools": {
      "command": "node",
      "args": ["/workspaces/Jit/hermes-discord/chrome-tools.js", "--mcp"]
    }
  }
}
```

หลังจากนั้น Claude จะมีเครื่องมือ:
- `chrome_navigate(url)` 
- `chrome_screenshot(url)`
- `chrome_inspect(url, selector)`
- `chrome_css(url, selector)`
- `chrome_analyze_ui(url)`
- `chrome_run_js(url, script)`

## วิธีใช้เป็น HTTP Bridge (ให้ Agent อื่นเรียกผ่าน REST)

```bash
# Start HTTP server
node hermes-discord/chrome-tools.js --http
# Default port: 4040 (set CHROME_MCP_PORT env to change)

# Example calls
curl -X POST http://localhost:4040/api/navigate -H 'Content-Type: application/json' \
  -d '{"url":"https://example.com"}'

curl -X POST http://localhost:4040/api/analyze_ui -H 'Content-Type: application/json' \
  -d '{"url":"https://mdes-innova.online"}'
```

## ติดตั้ง

```bash
cd hermes-discord
npm install puppeteer
# หรือถ้ามี Chrome อยู่แล้ว (ประหยัด disk)
npm install puppeteer-core
# แล้วตั้งค่า CHROME_PATH=/path/to/chrome
```

**Windows**: Chrome จะถูก auto-detect ที่ `C:\Program Files\Google\Chrome\Application\chrome.exe`  
**Linux**: `/usr/bin/google-chrome` หรือ `/usr/bin/chromium`  
**Custom**: ตั้ง env var `CHROME_PATH=/your/chrome`

## Architecture: Agent Bridge

```
Discord (ผู้ใช้)
    │  !AnuT1n chrome ui <url>
    ▼
อนุ (Hermes bot)  ─ handleCommand ──► chrome-tools.js
                                           │
                              ┌────────────┴────────────┐
                              ▼                         ▼
                         puppeteer               chromium/chrome
                         headless                เปิดหน้าเว็บจริง
                              │
                              ▼
                      UI analysis result ──► Discord reply
                              │
                              ▼ (optional)
                    bus.sh → innova inbox → Oracle learn
```

## Integration กับ Agents

innova, netra (eye), และ agents อื่นๆ สามารถเรียก Chrome DevTools ผ่าน:

1. **Discord**: `!AnuT1n chrome ui <url>` (ผ่าน อนุ)
2. **HTTP**: `curl http://localhost:4040/api/analyze_ui -d '{"url":"..."}'`
3. **MCP**: `chrome_analyze_ui(url)` (ใน Claude Code)
4. **Shell**: `node hermes-discord/chrome-tools.js --test <url>`

## Security Notes

- Chrome runs headless — ไม่มี UI popup
- `--no-sandbox` จำเป็นใน Docker/Codespaces (sandboxless env)
- `runJS` รัน expression ใน page context — ไม่ใช่ในเครื่อง host
- URLs ไม่ถูก validate ที่ tool level — validate ที่ caller (bot.js handles access control)
