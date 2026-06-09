---
name: routing-health
description: "Monitor and verify routing configurations across all backends (OpenAI, Anthropic, Ollama, custom). Checks symmetry, response times, model availability, and error patterns. Use when user says 'check routing', 'routing health', 'verify backends', 'routing status', 'backend check', or needs routing diagnostics for production readiness."
argument-hint: "[--quick | --deep | --report] [--backend=<name>] [--model=<name>]"
---

# SKILL: routing-health — ตรวจสุขภาพเส้นทาง 🛣️

> "ทางดี ล้อรถต้องหมุนเรียบ — ทางเก่า ต้องไปตรวจซ่อมให้เสร็จก่อน"

A comprehensive routing health check system for Jit's multiagent routing layer. Validates all backend connections, model availability, response symmetry, and error patterns.

## เมื่อไหร่ใช้ skill นี้

- ต้องการตรวจ routing configuration ก่อน production deployment
- แสดงปัญหา model หรือ backend ใดหลังจากอัพเดท
- ต้องการ historical trends ของ routing performance
- ต้องการตรวจ symmetry ของ responses ข้าม backends
- ต้องการ diagnostics เมื่อ agents ไม่ได้รับ response ถูกต้อง

## ตัวอย่างการใช้

```bash
/routing-health              # Quick check — สถานะปัจจุบัน (2 min)
/routing-health --quick      # Same as above
/routing-health --deep       # Deep scan — response symmetry + latency patterns (5-10 min)
/routing-health --report     # Generate HTML report + commit to docs/
/routing-health --backend=openai    # Check specific backend only
/routing-health --model=gpt-4       # Check specific model routing
/routing-health --deep --backend=ollama  # Combine flags
```

---

## Architecture

```
Input: Routing Config (hermes-discord/model-router.js)
   │
   ├─→ [Backend Probe] — Test each backend connection
   │    └─→ Check health endpoints (OpenAI, Anthropic, Ollama, custom)
   │    └─→ Measure response time + error rate
   │
   ├─→ [Model Verify] — Check available models per backend
   │    └─→ List models + versions
   │    └─→ Detect decommissioned models
   │
   ├─→ [Symmetry Test] — Route same prompt to all backends
   │    └─→ Compare responses (format, timing, errors)
   │    └─→ Detect backend-specific failures
   │
   ├─→ [Error Pattern] — Scan recent logs for routing errors
   │    └─→ 404 (backend down), 401 (auth fail), timeout, etc.
   │    └─→ Group by backend + model
   │
   └─→ Output: Status Report (JSON + Markdown + HTML)
```

---

## Step 0: System Check

```bash
# Verify required files exist
test -f hermes-discord/model-router.js || exit 1
test -f eval/fleet-batch.js || exit 1  # Has routing test cases
test -d logs/ || mkdir -p logs/

# Check if Oracle is running
curl -s http://localhost:47778/api/health >/dev/null 2>&1 || {
  echo "⚠️  Oracle not running — some features disabled"
  ORACLE_AVAILABLE=false
}

# Check Ollama availability
OLLAMA_URL="${OLLAMA_URL:-https://ollama.mdes-innova.online}"
curl -s "$OLLAMA_URL/api/tags" >/dev/null 2>&1 && OLLAMA_AVAILABLE=true || OLLAMA_AVAILABLE=false
```

---

## Step 1: Quick Check (default)

Run basic health checks on all configured backends.

### 1.1 Parse Router Config

```bash
# Extract all backends from model-router.js
BACKENDS=$(grep -oE "backend:\s*['\"]?[a-zA-Z0-9_-]+['\"]?" hermes-discord/model-router.js | \
  cut -d':' -f2 | tr -d ' "' | sort -u)

# Count total routes
TOTAL_ROUTES=$(grep -c "->.*backend:" hermes-discord/model-router.js || echo "0")
```

### 1.2 Test Each Backend

For each backend, test:

```bash
test_backend() {
  local backend=$1
  local endpoint=""
  local auth_header=""
  
  # Get endpoint and auth from config
  case "$backend" in
    openai)
      endpoint="https://api.openai.com/v1/models"
      auth_header="Authorization: Bearer $OPENAI_API_KEY"
      ;;
    anthropic)
      endpoint="https://api.anthropic.com/v1/models"
      auth_header="x-api-key: $ANTHROPIC_API_KEY"
      ;;
    ollama)
      endpoint="${OLLAMA_URL}/api/tags"
      ;;
    *)
      endpoint="$backend"  # Custom endpoint
      ;;
  esac
  
  # Test connectivity
  start_time=$(date +%s%N)
  http_code=$(curl -s -w "%{http_code}" -o /tmp/backend_test.json \
    -H "$auth_header" "$endpoint" 2>/dev/null)
  end_time=$(date +%s%N)
  latency=$(( (end_time - start_time) / 1000000 ))  # ms
  
  echo "$backend|$http_code|${latency}ms"
}

# Test all backends
echo "Testing backends..."
for backend in $BACKENDS; do
  test_backend "$backend"
done | tee /tmp/routing_health.txt
```

### 1.3 Display Quick Status

```bash
echo "🛣️ Routing Health — Quick Check"
echo ""
echo "| Backend | Status | Latency |"
echo "|---------|--------|---------|"
while IFS='|' read -r backend code latency; do
  if [[ "$code" == "200" ]]; then
    status="✅ OK"
  elif [[ "$code" == "401" || "$code" == "403" ]]; then
    status="🔐 Auth Failed"
  elif [[ "$code" == "000" ]]; then
    status="❌ Unreachable"
  else
    status="⚠️  HTTP $code"
  fi
  echo "| $backend | $status | $latency |"
done < /tmp/routing_health.txt

echo ""
echo "**Total routes**: $TOTAL_ROUTES"
echo "**Timestamp**: $(date -u +'%Y-%m-%d %H:%M:%S UTC')"
```

---

## Step 2: Deep Scan (`--deep`)

Run comprehensive tests including response symmetry and latency patterns.

### 2.1 Symmetry Test

Send identical prompts to multiple backends and compare responses:

```bash
run_symmetry_test() {
  local test_prompt="Count to 5 in one line."
  local test_model="gpt-3.5-turbo"  # Model available on multiple backends
  
  echo "Running symmetry test with prompt: '$test_prompt'"
  echo ""
  
  for backend in $BACKENDS; do
    echo "Testing $backend..."
    
    # Call routing layer with specific backend preference
    response=$(bash eval/fleet-batch.js --backend="$backend" \
      --model="$test_model" \
      --prompt="$test_prompt" 2>/dev/null)
    
    # Store response
    echo "$response" > /tmp/response_${backend}.txt
    
    # Hash for comparison
    response_hash=$(echo "$response" | sha256sum | cut -d' ' -f1)
    echo "  Hash: $response_hash"
  done
  
  # Compare hashes
  echo ""
  echo "Hash comparison:"
  for f in /tmp/response_*.txt; do
    backend=$(basename "$f" | sed 's/response_//;s/.txt//')
    hash=$(sha256sum "$f" | cut -d' ' -f1)
    echo "  $backend: $hash"
  done
  
  # Detect mismatches
  unique_hashes=$(sha256sum /tmp/response_*.txt | cut -d' ' -f1 | sort -u | wc -l)
  if [[ $unique_hashes -gt 1 ]]; then
    echo ""
    echo "⚠️  ASYMMETRY DETECTED — responses differ between backends"
  else
    echo ""
    echo "✅ Symmetric — all backends return equivalent responses"
  fi
}
```

### 2.2 Latency Pattern Analysis

```bash
analyze_latency() {
  echo "Analyzing latency patterns (30-second test)..."
  
  for i in {1..10}; do
    for backend in $BACKENDS; do
      test_backend "$backend" >> /tmp/latency_history.txt
    done
    sleep 2
  done
  
  # Calculate statistics
  echo ""
  echo "| Backend | Min | Avg | Max | StdDev |"
  echo "|---------|-----|-----|-----|--------|"
  
  for backend in $BACKENDS; do
    latencies=$(grep "^$backend" /tmp/latency_history.txt | cut -d'|' -f3 | sed 's/ms//')
    min=$(echo "$latencies" | sort -n | head -1)
    max=$(echo "$latencies" | sort -n | tail -1)
    avg=$(echo "$latencies" | awk '{sum+=$1;count++} END {printf "%.0f", sum/count}')
    
    echo "| $backend | ${min}ms | ${avg}ms | ${max}ms | - |"
  done
}
```

### 2.3 Error Pattern Scan

```bash
scan_errors() {
  echo "Scanning recent errors from logs..."
  
  # Check various log locations
  for logfile in logs/*.log eval/*.log hermes-discord/*.log 2>/dev/null; do
    [[ -f "$logfile" ]] && tail -100 "$logfile"
  done | grep -i "error\|fail\|timeout\|reject" | tail -50 > /tmp/routing_errors.txt
  
  echo ""
  echo "## Recent Routing Errors"
  echo ""
  
  if [[ -s /tmp/routing_errors.txt ]]; then
    echo '```'
    cat /tmp/routing_errors.txt
    echo '```'
    
    # Group by error type
    echo ""
    echo "### Error Summary"
    echo ""
    grep -oE "(404|401|403|timeout|ECONNREFUSED|ENOTFOUND)" /tmp/routing_errors.txt | \
      sort | uniq -c | sort -rn | while read count error; do
      echo "- **$error**: $count occurrences"
    done
  else
    echo "✅ No recent routing errors found"
  fi
}
```

---

## Step 3: Report Generation (`--report`)

Generate a comprehensive HTML report and commit to `/docs/routing/`.

```bash
generate_report() {
  local timestamp=$(date +%Y-%m-%d_%H:%M:%S)
  local report_dir="docs/routing"
  mkdir -p "$report_dir"
  
  # Collect all data
  quick_data=$(<< 'EOF'
  [Run quick checks and capture JSON output]
  EOF
  )
  
  # Generate HTML
  cat > "$report_dir/health_${timestamp}.html" << 'EOF'
<!DOCTYPE html>
<html>
<head>
  <title>Jit Routing Health — ${timestamp}</title>
  <style>
    body { font-family: monospace; margin: 20px; }
    .status-ok { color: green; }
    .status-warn { color: orange; }
    .status-fail { color: red; }
    table { border-collapse: collapse; margin: 20px 0; }
    td, th { border: 1px solid #ccc; padding: 8px; }
  </style>
</head>
<body>
  <h1>🛣️ Jit Routing Health Report</h1>
  <p><strong>Generated:</strong> ${timestamp}</p>
  
  <h2>Backend Status</h2>
  [Insert status table]
  
  <h2>Symmetry Results</h2>
  [Insert symmetry analysis]
  
  <h2>Latency Trends</h2>
  [Insert latency chart]
  
  <h2>Error Patterns</h2>
  [Insert error summary]
</body>
</html>
EOF
  
  # Commit report
  git add "$report_dir/health_${timestamp}.html"
  git commit -m "docs: routing health report $timestamp" || true
  
  echo "✅ Report generated: $report_dir/health_${timestamp}.html"
}
```

---

## Step 4: Backend-Specific Check (`--backend=<name>`)

Deep dive into a single backend:

```bash
check_backend() {
  local backend=$1
  
  echo "🔍 Deep Check: $backend Backend"
  echo ""
  
  # Connection status
  echo "### Connection"
  test_backend "$backend"
  
  # Available models
  echo ""
  echo "### Available Models"
  case "$backend" in
    openai)
      curl -s -H "Authorization: Bearer $OPENAI_API_KEY" \
        https://api.openai.com/v1/models | jq '.data[] | .id' | head -20
      ;;
    anthropic)
      curl -s -H "x-api-key: $ANTHROPIC_API_KEY" \
        https://api.anthropic.com/v1/models | jq '.data[] | .id' | head -20
      ;;
    ollama)
      curl -s "$OLLAMA_URL/api/tags" | jq '.models[] | .name'
      ;;
  esac
  
  # Routing rules for this backend
  echo ""
  echo "### Routing Rules"
  grep -A5 "backend.*$backend" hermes-discord/model-router.js | head -10
}
```

---

## Step 5: Model-Specific Check (`--model=<name>`)

Verify routing for a specific model:

```bash
check_model() {
  local model=$1
  
  echo "📦 Model Routing: $model"
  echo ""
  
  # Find all routes for this model
  grep "$model" hermes-discord/model-router.js | while read -r line; do
    echo "  $line"
  done
  
  # Test model availability on each backend
  echo ""
  echo "### Availability"
  echo "| Backend | Available |"
  echo "|---------|-----------|"
  
  for backend in $BACKENDS; do
    case "$backend" in
      openai)
        available=$(curl -s -H "Authorization: Bearer $OPENAI_API_KEY" \
          https://api.openai.com/v1/models | jq ".data[] | select(.id==\"$model\") | .id")
        ;;
      anthropic)
        available=$(curl -s -H "x-api-key: $ANTHROPIC_API_KEY" \
          https://api.anthropic.com/v1/models | jq ".data[] | select(.id==\"$model\") | .id")
        ;;
      *)
        available="?"
        ;;
    esac
    
    [[ -n "$available" ]] && status="✅" || status="❌"
    echo "| $backend | $status |"
  done
}
```

---

## Step 6: Oracle Integration

Learn routing insights to Oracle knowledge base:

```bash
log_to_oracle() {
  local insight=$1
  local backends=$2
  
  if [[ "$ORACLE_AVAILABLE" == "true" ]]; then
    bash limbs/oracle.sh learn \
      "routing-health-$(date +%s)" \
      "Routing health check: $insight" \
      "routing,backends=$backends,health-check"
  fi
}
```

---

## Examples

### Example 1: Quick Sanity Check Before Deployment

```bash
/routing-health --quick
# Output:
# 🛣️ Routing Health — Quick Check
# | Backend | Status | Latency |
# |---------|--------|---------|
# | openai | ✅ OK | 245ms |
# | anthropic | ✅ OK | 189ms |
# | ollama | ✅ OK | 52ms |
# **Total routes**: 47
# **Timestamp**: 2026-06-09 14:30:15 UTC
```

### Example 2: Diagnose Failing Route

```bash
/routing-health --deep --backend=openai
# Output:
# 🔍 Deep Check: openai Backend
# ### Connection
# openai|200|243ms
# ### Available Models
# gpt-4
# gpt-4-turbo
# gpt-3.5-turbo
# ...
# ⚠️ ASYMMETRY DETECTED — responses differ between backends
```

### Example 3: Generate Production Report

```bash
/routing-health --report
# Output:
# ✅ Report generated: docs/routing/health_2026-06-09_14:30:15.html
# [HTML file committed]
```

---

## Integration with Jit Organs

This skill integrates with Jit's organ system:

- **mouth.sh** — Report results to agents
- **nerve.sh** — Signal routing errors as system alerts  
- **oracle.sh** (limbs) — Log insights to knowledge base
- **heart.sh** — Monitor ongoing routing health (optional loop)
- **hand.sh** (organs) — Write reports to filesystem

---

## Error Handling

| Error | Cause | Resolution |
|-------|-------|-----------|
| `ECONNREFUSED` | Backend endpoint down | Check backend service status |
| `401 Unauthorized` | Invalid API key | Verify `$OPENAI_API_KEY`, `$ANTHROPIC_API_KEY` env vars |
| `Timeout` | Network or slow backend | Retry or increase timeout |
| `Model not found` | Model decommissioned | Update routing config |
| `Asymmetric responses` | Backend differences | Investigate response format |

---

## Performance Notes

- **Quick check**: 1-2 minutes (10-15 concurrent probes)
- **Deep scan**: 5-10 minutes (includes symmetry tests, 30s latency analysis)
- **Report generation**: ~30 seconds (I/O bounded)

---

ARGUMENTS: $ARGUMENTS
