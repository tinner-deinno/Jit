#!/usr/bin/env python3
"""
Test suite for JIT-011: HMAC Message Signing on Bus Protocol

Tests:
1. Valid signed message → accepted
2. Tampered body → rejected
3. Invalid signature → rejected
4. Missing signature + STRICT_AUTH=0 → accepted with warning
5. Missing signature + STRICT_AUTH=1 → rejected
"""

import os
import subprocess
import tempfile
import shutil
import uuid

BUS_ROOT = "/tmp/manusat-bus-test"
TEST_SECRET = "test-secret-key-for-hmac-signing-32bytes!"


def run_cmd(cmd, env=None):
    """Run bash command and return (stdout, stderr, returncode)"""
    full_env = os.environ.copy()
    if env:
        full_env.update(env)

    result = subprocess.run(
        ["bash", "-c", cmd],
        capture_output=True,
        text=True,
        env=full_env,
        cwd="/workspaces/Jit"
    )
    return result.stdout, result.stderr, result.returncode


def setup_bus():
    """Initialize test bus directory"""
    shutil.rmtree(BUS_ROOT, ignore_errors=True)
    os.makedirs(f"{BUS_ROOT}/sender", exist_ok=True)
    os.makedirs(f"{BUS_ROOT}/receiver", exist_ok=True)
    return f"{BUS_ROOT}/receiver"


def cleanup_bus():
    """Clean up test bus directory"""
    shutil.rmtree(BUS_ROOT, ignore_errors=True)


def generate_signature(from_agent, to_agent, subject, timestamp, body, secret):
    """Generate HMAC-SHA256 signature using openssl"""
    canonical = f"{from_agent}{to_agent}{subject}{timestamp}{body}"
    cmd = f'echo -n "{canonical}" | openssl dgst -sha256 -hmac "{secret}" | awk \'{{print $NF}}\''
    result = subprocess.run(["bash", "-c", cmd], capture_output=True, text=True)
    return result.stdout.strip()


def write_message(to, from_agent, subject, body, timestamp, signature=None):
    """Write a message file manually"""
    inbox = f"{BUS_ROOT}/{to}"
    msg_file = f"{inbox}/{timestamp}_from-{from_agent}.msg"

    with open(msg_file, "w") as f:
        f.write(f"from:{from_agent}\n")
        f.write(f"to:{to}\n")
        f.write(f"subject:{subject}\n")
        f.write(f"timestamp:{timestamp}\n")
        if signature:
            f.write(f"x-signature:hmac-sha256={signature}\n")
        f.write("---\n")
        f.write(f"{body}\n")

    return msg_file


def test_1_valid_signed_message():
    """Test 1: Valid signed message should be accepted"""
    print("\n=== Test 1: Valid Signed Message ===")
    inbox = setup_bus()

    timestamp = "2026-06-07T12:00:00"
    from_agent = "sender"
    to_agent = "receiver"
    subject = "task:test"
    body = "Hello, this is a test message"

    # Generate valid signature
    signature = generate_signature(from_agent, to_agent, subject, timestamp, body, TEST_SECRET)
    print(f"Generated signature: {signature[:16]}...")

    # Write message
    write_message(to_agent, from_agent, subject, body, timestamp, signature)

    # Try to receive with ear.sh
    stdout, stderr, rc = run_cmd(
        f"AGENT_NAME=receiver INBOX_DIR={BUS_ROOT} bash organs/ear.sh receive",
        env={"MANUSAT_BUS_SECRET": TEST_SECRET, "MANUSAT_STRICT_AUTH": "1"}
    )

    cleanup_bus()

    if "Hello, this is a test message" in stdout:
        print("✅ PASS: Valid signed message accepted")
        return True
    else:
        print(f"❌ FAIL: Valid message rejected\nstdout: {stdout}\nstderr: {stderr}")
        return False


def test_2_tampered_body():
    """Test 2: Tampered body should be rejected"""
    print("\n=== Test 2: Tampered Body ===")
    inbox = setup_bus()

    timestamp = "2026-06-07T12:00:00"
    from_agent = "sender"
    to_agent = "receiver"
    subject = "task:test"
    original_body = "Hello, this is a test message"
    tampered_body = "Hello, this is TAMPERED message"

    # Generate signature for ORIGINAL body
    signature = generate_signature(from_agent, to_agent, subject, timestamp, original_body, TEST_SECRET)

    # Write message with TAMPERED body but ORIGINAL signature
    write_message(to_agent, from_agent, subject, tampered_body, timestamp, signature)

    # Try to receive
    stdout, stderr, rc = run_cmd(
        f"AGENT_NAME=receiver INBOX_DIR={BUS_ROOT} bash organs/ear.sh receive",
        env={"MANUSAT_BUS_SECRET": TEST_SECRET, "MANUSAT_STRICT_AUTH": "1"}
    )

    cleanup_bus()

    if "BUS_AUTH_FAIL" in stderr or rc != 0:
        print("✅ PASS: Tampered message rejected")
        return True
    else:
        print(f"❌ FAIL: Tampered message was accepted\nstdout: {stdout}")
        return False


def test_3_invalid_signature():
    """Test 3: Invalid signature should be rejected"""
    print("\n=== Test 3: Invalid Signature ===")
    inbox = setup_bus()

    timestamp = "2026-06-07T12:00:00"
    from_agent = "sender"
    to_agent = "receiver"
    subject = "task:test"
    body = "Hello, this is a test message"

    # Write message with FAKE signature
    fake_signature = "deadbeef1234567890abcdef1234567890abcdef1234567890abcdef12345678"
    write_message(to_agent, from_agent, subject, body, timestamp, fake_signature)

    # Try to receive
    stdout, stderr, rc = run_cmd(
        f"AGENT_NAME=receiver INBOX_DIR={BUS_ROOT} bash organs/ear.sh receive",
        env={"MANUSAT_BUS_SECRET": TEST_SECRET, "MANUSAT_STRICT_AUTH": "1"}
    )

    cleanup_bus()

    if "BUS_AUTH_FAIL" in stderr or "Signature mismatch" in stderr:
        print("✅ PASS: Invalid signature rejected")
        return True
    else:
        print(f"❌ FAIL: Invalid signature was accepted\nstdout: {stdout}")
        return False


def test_4_missing_signature_legacy_mode():
    """Test 4: Missing signature with STRICT_AUTH=0 should be accepted"""
    print("\n=== Test 4: Missing Signature (Legacy Mode) ===")
    inbox = setup_bus()

    timestamp = "2026-06-07T12:00:00"
    from_agent = "sender"
    to_agent = "receiver"
    subject = "task:test"
    body = "Hello, this is a legacy message"

    # Write message WITHOUT signature
    write_message(to_agent, from_agent, subject, body, timestamp, None)

    # Try to receive with STRICT_AUTH=0
    stdout, stderr, rc = run_cmd(
        f"AGENT_NAME=receiver INBOX_DIR={BUS_ROOT} bash organs/ear.sh receive",
        env={"MANUSAT_BUS_SECRET": TEST_SECRET, "MANUSAT_STRICT_AUTH": "0"}
    )

    cleanup_bus()

    if "Hello, this is a legacy message" in stdout:
        print("✅ PASS: Unsigned message accepted in legacy mode")
        return True
    else:
        print(f"❌ FAIL: Legacy mode didn't work\nstdout: {stdout}\nstderr: {stderr}")
        return False


def test_5_missing_signature_strict_mode():
    """Test 5: Missing signature with STRICT_AUTH=1 should be rejected"""
    print("\n=== Test 5: Missing Signature (Strict Mode) ===")
    inbox = setup_bus()

    timestamp = "2026-06-07T12:00:00"
    from_agent = "sender"
    to_agent = "receiver"
    subject = "task:test"
    body = "Hello, this is an unsigned message"

    # Write message WITHOUT signature
    write_message(to_agent, from_agent, subject, body, timestamp, None)

    # Try to receive with STRICT_AUTH=1
    stdout, stderr, rc = run_cmd(
        f"AGENT_NAME=receiver INBOX_DIR={BUS_ROOT} bash organs/ear.sh receive",
        env={"MANUSAT_BUS_SECRET": TEST_SECRET, "MANUSAT_STRICT_AUTH": "1"}
    )

    cleanup_bus()

    if "BUS_AUTH_FAIL" in stderr or "Missing signature" in stderr:
        print("✅ PASS: Unsigned message rejected in strict mode")
        return True
    else:
        print(f"❌ FAIL: Strict mode didn't reject unsigned message\nstdout: {stdout}\nstderr: {stderr}")
        return False


def test_6_mouth_sh_integration():
    """Test 6: mouth.sh tell generates signature"""
    print("\n=== Test 6: mouth.sh Integration ===")
    inbox = setup_bus()

    # Send message using mouth.sh
    stdout, stderr, rc = run_cmd(
        f"AGENT_NAME=testagent BUS_DIR={BUS_ROOT} bash organs/mouth.sh tell receiver task:integration 'Test from mouth.sh'",
        env={"MANUSAT_BUS_SECRET": TEST_SECRET}
    )

    # Check if message file was created with signature
    import glob
    msg_files = glob.glob(f"{BUS_ROOT}/receiver/*_from-testagent.msg")

    if not msg_files:
        print(f"❌ FAIL: No message file created\nstdout: {stdout}\nstderr: {stderr}")
        cleanup_bus()
        return False

    # Read the message file and check for signature
    with open(msg_files[0], "r") as f:
        content = f.read()

    cleanup_bus()

    if "x-signature:hmac-sha256=" in content:
        print("✅ PASS: mouth.sh added x-signature header")
        return True
    else:
        print(f"❌ FAIL: No signature in message\nContent:\n{content}")
        return False


def main():
    print("=" * 60)
    print("JIT-011: HMAC Message Signing Test Suite")
    print("=" * 60)

    results = []

    results.append(("Valid Signed Message", test_1_valid_signed_message()))
    results.append(("Tampered Body", test_2_tampered_body()))
    results.append(("Invalid Signature", test_3_invalid_signature()))
    results.append(("Missing Signature (Legacy)", test_4_missing_signature_legacy_mode()))
    results.append(("Missing Signature (Strict)", test_5_missing_signature_strict_mode()))
    results.append(("mouth.sh Integration", test_6_mouth_sh_integration()))

    print("\n" + "=" * 60)
    print("Test Results Summary")
    print("=" * 60)

    passed = sum(1 for _, r in results if r)
    total = len(results)

    for name, result in results:
        status = "✅ PASS" if result else "❌ FAIL"
        print(f"  {status}: {name}")

    print(f"\nTotal: {passed}/{total} tests passed")

    return 0 if passed == total else 1


if __name__ == "__main__":
    exit(main())
