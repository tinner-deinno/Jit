#!/usr/bin/env bash
# eval/body-check.sh — ตรวจสุขภาพร่างกายดิจิทัลทั้งหมด
# Full multiagent body integrity check
# มีอะไรบ้าง: organs, network, mind, memory, agents, limbs, eval

cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 1
JIT_ROOT="$(pwd)"
source "$JIT_ROOT/limbs/lib.sh" 2>/dev/null || { echo "ERROR: lib.sh not found"; exit 1; }

PASS=0; FAIL=0; WARN=0

_pass() { echo -e "  ${GREEN}✅${RESET} $1"; ((PASS++)) || true; }
_fail() { echo -e "  ${RED}❌${RESET} $1"; ((FAIL++)) || true; }
_warn() { echo -e "  ${YELLOW}⚠️ ${RESET} $1"; ((WARN++)) || true; }
_section() { echo ""; echo -e "${BOLD}[ $1 ]${RESET}"; }

echo ""
echo -e "${BOLD}${CYAN}"
echo "  ╔══════════════════════════════════════════════════╗"
echo "  ║     มนุษย์ Agent — Body Integrity Check          ║"
echo "  ╚══════════════════════════════════════════════════╝"
echo -e "${RESET}"
echo "  $(date '+%Y-%m-%d %H:%M:%S')"

# ════════════════════════════════════════════════════════
_section "Core Services"
# Oracle
curl -sf "$ORACLE_URL/api/health" | python3 -c \
  "import json,sys; d=json.load(sys.stdin); exit(0 if d.get('oracle')=='connected' else 1)" 2>/dev/null \
  && _pass "Oracle connected ($ORACLE_URL)" || _fail "Oracle offline"

# Oracle docs
DOCS=$(curl -sf "$ORACLE_URL/api/stats" 2>/dev/null | python3 -c \
  "import json,sys; d=json.load(sys.stdin); print(d.get('totalDocuments', d.get('total','?')))" 2>/dev/null || echo "?")
[ "$DOCS" != "?" ] && _pass "Oracle docs: $DOCS" || _warn "Oracle stats unavailable"

# Ollama
curl -sf --max-time 10 "https://ollama.mdes-innova.online/api/version" > /dev/null 2>&1 \
  && _pass "MDES Ollama reachable" || _warn "Ollama timeout (may be slow)"

# ════════════════════════════════════════════════════════
_section "Limbs (แขนขาเดิม)"
LIMBS=(lib think act speak ollama oracle index)
for L in "${LIMBS[@]}"; do
  F="$JIT_ROOT/limbs/${L}.sh"
  [ -f "$F" ] && _pass "limbs/$L.sh" || _fail "limbs/$L.sh ไม่พบ"
done

# ════════════════════════════════════════════════════════
_section "Organs รูปธรรม (อวัยวะ)"
ORGANS=(eye ear mouth nose hand leg heart nerve)
for O in "${ORGANS[@]}"; do
  F="$JIT_ROOT/organs/${O}.sh"
  if [ -f "$F" ]; then
    [ -x "$F" ] && _pass "organs/$O.sh" || _warn "organs/$O.sh (not executable)"
  else
    _fail "organs/$O.sh ไม่พบ"
  fi
done

# ════════════════════════════════════════════════════════
_section "Mind นามธรรม (จิตใจ)"
[ -f "$JIT_ROOT/mind/ego.md" ]      && _pass "mind/ego.md" || _fail "mind/ego.md"
[ -f "$JIT_ROOT/mind/emotion.sh" ]  && _pass "mind/emotion.sh" || _fail "mind/emotion.sh"
[ -f "$JIT_ROOT/mind/reflex.sh" ]   && _pass "mind/reflex.sh" || _fail "mind/reflex.sh"

# ════════════════════════════════════════════════════════
_section "Memory (ความทรงจำ)"
[ -f "$JIT_ROOT/memory/architecture.md" ] && _pass "memory/architecture.md" || _fail "memory/architecture.md"
[ -f "$JIT_ROOT/memory/shared.sh" ]       && _pass "memory/shared.sh" || _fail "memory/shared.sh"
[ -f "$JIT_ROOT/memory/working.sh" ]      && _pass "memory/working.sh" || _fail "memory/working.sh"

# ════════════════════════════════════════════════════════
_section "Network Multiagent"
[ -f "$JIT_ROOT/network/registry.json" ] && _pass "network/registry.json" || _fail "network/registry.json"
[ -f "$JIT_ROOT/network/protocol.md" ]   && _pass "network/protocol.md" || _fail "network/protocol.md"
[ -f "$JIT_ROOT/network/bus.sh" ]        && _pass "network/bus.sh" || _fail "network/bus.sh"
[ -f "$JIT_ROOT/network/router.sh" ]     && _pass "network/router.sh" || _fail "network/router.sh"

# ════════════════════════════════════════════════════════
_section "Agents (ผู้เล่น)"
[ -f "$JIT_ROOT/agents/innova.json" ]  && _pass "agents/innova.json" || _fail "agents/innova.json"
[ -f "$JIT_ROOT/agents/soma.json" ]    && _pass "agents/soma.json" || _fail "agents/soma.json"
[ -f "$JIT_ROOT/agents/template.json" ] && _pass "agents/template.json" || _warn "agents/template.json"

# ════════════════════════════════════════════════════════
_section "Core Structure"
CORE_FILES=(core/identity.md brain/reasoning.md config/agent.env eval/soul-check.sh docs/new-agent-guide.md)
for F in "${CORE_FILES[@]}"; do
  [ -f "$JIT_ROOT/$F" ] && _pass "$F" || _fail "$F"
done

# ════════════════════════════════════════════════════════
_section "Oracle Knowledge"
CONCEPTS=("innova" "anatomy")
for C in "${CONCEPTS[@]}"; do
  RESULT=$(curl -sf "$ORACLE_URL/api/search?q=$(python3 -c "import urllib.parse; print(urllib.parse.quote('$C'))" 2>/dev/null)" 2>/dev/null | \
    python3 -c "import json,sys; d=json.load(sys.stdin); print(len(d.get('results',[])))" 2>/dev/null || echo "0")
  [ "${RESULT:-0}" -gt 0 ] && _pass "Oracle รู้จัก: $C" || _warn "Oracle ยังไม่รู้เรื่อง: $C"
done

# ════════════════════════════════════════════════════════
TOTAL=$((PASS + FAIL + WARN))
PCT_PASS=$(( TOTAL > 0 ? (PASS * 100) / TOTAL : 0 ))

echo ""
echo -e "${BOLD}════════════════════════════════════════════${RESET}"
echo -e "  ${GREEN}PASS: $PASS${RESET} | ${RED}FAIL: $FAIL${RESET} | ${YELLOW}WARN: $WARN${RESET} | Total: $TOTAL"
echo ""

# Progress bar
BAR_FILLED=$(printf '█%.0s' $(seq 1 $((PCT_PASS / 5))))
BAR_EMPTY=$(printf '░%.0s' $(seq 1 $((20 - PCT_PASS / 5))))
echo -e "  Vitality: ${GREEN}${BAR_FILLED}${RESET}${BAR_EMPTY} ${PCT_PASS}%"
echo ""

if [ $FAIL -eq 0 ]; then
  echo -e "  ${GREEN}${BOLD}🌟 ร่างกายดิจิทัลสมบูรณ์ พร้อมทำงาน${RESET}"
elif [ $FAIL -le 3 ]; then
  echo -e "  ${YELLOW}${BOLD}⚠️  ร่างกายทำงานได้ แต่มีส่วนที่ต้องซ่อม ($FAIL รายการ)${RESET}"
else
  echo -e "  ${RED}${BOLD}❌ ร่างกายต้องการการซ่อมแซม ($FAIL รายการล้มเหลว)${RESET}"
fi
echo ""
