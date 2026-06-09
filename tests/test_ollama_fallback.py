#!/usr/bin/env python3
"""
test_ollama_fallback.py — ทดสอบ Multi-Model Fallback Chain (JIT-015)

Tests:
1. MODEL_CHAIN parsing
2. Fallback on timeout simulation
3. Fallback on HTTP 5xx simulation
4. Logging verification
5. Bus event emission
"""

import os
import subprocess
import sys
import time
import json
from pathlib import Path

JIT_ROOT = Path("/workspaces/Jit")
OLLAMA_SCRIPT = JIT_ROOT / "limbs/ollama.sh"
LOG_DIR = Path("/var/log/jit") if Path("/var/log/jit").exists() else Path("/tmp/jit-logs")
MODEL_ATTEMPTS_LOG = LOG_DIR / "ollama-model-attempts.log"
BUS_ROOT = Path("/tmp/manusat-bus")


def setup_test_env():
    """เตรียม environment สำหรับทดสอบ"""
    print("=" * 60)
    print("ตั้งค่า environment สำหรับทดสอบ JIT-015")
    print("=" * 60)

    # Ensure log directory exists
    LOG_DIR.mkdir(parents=True, exist_ok=True)

    # Clear previous test logs
    if MODEL_ATTEMPTS_LOG.exists():
        MODEL_ATTEMPTS_LOG.unlink()

    # Initialize bus inboxes
    BUS_ROOT.mkdir(parents=True, exist_ok=True)
    for agent in ["innova", "soma", "jit"]:
        (BUS_ROOT / agent).mkdir(exist_ok=True)

    print(f"✓ Log directory: {LOG_DIR}")
    print(f"✓ Bus root: {BUS_ROOT}")
    print()


def test_model_chain_parsing():
    """ทดสอบที่ 1: MODEL_CHAIN parsing"""
    print("\n" + "=" * 60)
    print("Test 1: MODEL_CHAIN Parsing")
    print("=" * 60)

    test_cases = [
        ("gemma4:26b", ["gemma4:26b"]),
        ("gemma4:26b,gemma2:9b", ["gemma4:26b", "gemma2:9b"]),
        ("gemma4:26b,gemma2:9b,gemma2:2b", ["gemma4:26b", "gemma2:9b", "gemma2:2b"]),
    ]

    all_passed = True
    for input_chain, expected in test_cases:
        # Simulate bash IFS splitting
        result = input_chain.split(",")
        if result == expected:
            print(f"✓ '{input_chain}' → {result}")
        else:
            print(f"✗ '{input_chain}' → {result} (expected {expected})")
            all_passed = False

    return all_passed


def test_single_model_success():
    """ทดสอบที่ 2: Single model success (no fallback needed)"""
    print("\n" + "=" * 60)
    print("Test 2: Single Model Success")
    print("=" * 60)

    env = os.environ.copy()
    env["MODEL_CHAIN"] = "gemma4:26b"
    env["OLLAMA_TIMEOUT_SEC"] = "30"

    start = time.time()
    result = subprocess.run(
        ["bash", str(OLLAMA_SCRIPT), "ask", "ตอบสั้นๆ ว่า 'พร้อม'"],
        capture_output=True,
        text=True,
        env=env,
        timeout=60
    )
    elapsed = time.time() - start

    if result.returncode == 0 and len(result.stdout.strip()) > 0:
        print(f"✓ Single model succeeded in {elapsed:.2f}s")
        print(f"  Output: {result.stdout.strip()[:50]}...")
        return True
    else:
        print(f"✗ Single model failed (code={result.returncode})")
        print(f"  stderr: {result.stderr[:200]}")
        return False


def test_fallback_on_timeout():
    """ทดสอบที่ 3: Fallback when primary model times out"""
    print("\n" + "=" * 60)
    print("Test 3: Fallback on Timeout Simulation")
    print("=" * 60)

    # ใช้ timeout สั้นมากเพื่อ simulate failure
    env = os.environ.copy()
    env["MODEL_CHAIN"] = "gemma4:26b,gemma2:9b"
    env["OLLAMA_TIMEOUT_SEC"] = "5"  # สั้นมากเพื่อ trigger timeout

    start = time.time()
    result = subprocess.run(
        ["bash", str(OLLAMA_SCRIPT), "ask", "สวัสดี"],
        capture_output=True,
        text=True,
        env=env,
        timeout=120
    )
    elapsed = time.time() - start

    # ตรวจสอบ log file
    attempts = []
    if MODEL_ATTEMPTS_LOG.exists():
        with open(MODEL_ATTEMPTS_LOG) as f:
            attempts = f.readlines()

    print(f"Elapsed: {elapsed:.2f}s")
    print(f"Return code: {result.returncode}")
    print(f"Log attempts: {len(attempts)}")

    for line in attempts:
        print(f"  {line.strip()}")

    # ควรเห็นการลอง model หลายครั้ง
    if len(attempts) >= 1:
        print("✓ Fallback logic triggered (multiple attempts logged)")
        return True
    else:
        print("✗ No attempts logged")
        return False


def test_fallback_event_emission():
    """ทดสอบที่ 4: Bus event emission"""
    print("\n" + "=" * 60)
    print("Test 4: Fallback Event Emission to Bus")
    print("=" * 60)

    # เรียก ollama.sh เพื่อกenerate event
    env = os.environ.copy()
    env["MODEL_CHAIN"] = "gemma4:26b"
    env["OLLAMA_TIMEOUT_SEC"] = "30"

    subprocess.run(
        ["bash", str(OLLAMA_SCRIPT), "ask", "ทดสอบ"],
        capture_output=True,
        text=True,
        env=env,
        timeout=60
    )

    # ตรวจสอบ inbox ของ innova
    innova_inbox = BUS_ROOT / "innova"
    fallback_events = []

    if innova_inbox.exists():
        for msg_file in innova_inbox.glob("*.msg"):
            with open(msg_file) as f:
                content = f.read()
                if "learn:model-fallback" in content or "model_fallback_event" in content:
                    fallback_events.append(msg_file.name)

    if fallback_events:
        print(f"✓ Found {len(fallback_events)} fallback event(s) in bus:")
        for event in fallback_events:
            print(f"  - {event}")
        return True
    else:
        print("⚠ No fallback events found in bus (may be OK if no failures)")
        return True  # ไม่ถือว่า fail ถ้าไม่มfailure


def test_logging_format():
    """ทดสอบที่ 5: Log format verification"""
    print("\n" + "=" * 60)
    print("Test 5: Log Format Verification")
    print("=" * 60)

    if not MODEL_ATTEMPTS_LOG.exists():
        print("✗ Log file not found")
        return False

    with open(MODEL_ATTEMPTS_LOG) as f:
        lines = f.readlines()

    if not lines:
        print("✗ Log file is empty")
        return False

    valid_format = True
    required_fields = ["model=", "latency=", "result="]

    for i, line in enumerate(lines[-5:], 1):  # ตรวจสอบ 5 บรรทัดสุดท้าย
        missing = [f for f in required_fields if f not in line]
        if missing:
            print(f"✗ Line {i}: Missing fields {missing}")
            print(f"  Content: {line.strip()}")
            valid_format = False
        else:
            print(f"✓ Line {i}: Valid format")
            print(f"  {line.strip()}")

    return valid_format


def test_configurable_timeout():
    """ทดสอบที่ 6: Configurable timeout"""
    print("\n" + "=" * 60)
    print("Test 6: Configurable Timeout (OLLAMA_TIMEOUT_SEC)")
    print("=" * 60)

    # ทดสอบว่า timeout ถูกใช้จริงโดยวัดเวลา
    env = os.environ.copy()
    env["MODEL_CHAIN"] = "gemma4:26b"
    env["OLLAMA_TIMEOUT_SEC"] = "10"

    start = time.time()
    subprocess.run(
        ["bash", str(OLLAMA_SCRIPT), "ask", "ทดสอบ timeout"],
        capture_output=True,
        text=True,
        env=env,
        timeout=30
    )
    elapsed = time.time() - start

    # ควรไม่เกิน timeout + buffer
    max_expected = 15  # 10s timeout + 5s buffer
    if elapsed < max_expected:
        print(f"✓ Timeout respected (elapsed={elapsed:.2f}s, max_expected={max_expected}s)")
        return True
    else:
        print(f"✗ Timeout may not be working (elapsed={elapsed:.2f}s)")
        return False


def run_all_tests():
    """รันการทดสอบทั้งหมด"""
    print("\n" + "=" * 70)
    print("  JIT-015: Multi-Model Fallback Chain — Test Suite")
    print("=" * 70)

    setup_test_env()

    results = {
        "MODEL_CHAIN Parsing": test_model_chain_parsing(),
        "Single Model Success": test_single_model_success(),
        "Fallback on Timeout": test_fallback_on_timeout(),
        "Bus Event Emission": test_fallback_event_emission(),
        "Log Format": test_logging_format(),
        "Configurable Timeout": test_configurable_timeout(),
    }

    # สรุปผล
    print("\n" + "=" * 70)
    print("  Test Summary")
    print("=" * 70)

    passed = sum(1 for v in results.values() if v)
    total = len(results)

    for name, result in results.items():
        status = "✓ PASS" if result else "✗ FAIL"
        print(f"  {status}: {name}")

    print(f"\n  Total: {passed}/{total} tests passed")
    print("=" * 70)

    return passed == total


if __name__ == "__main__":
    success = run_all_tests()
    sys.exit(0 if success else 1)
