#!/usr/bin/env python3
"""
Test suite for JIT-004: Dead-Letter Queue (DLQ) for bus failures

Tests:
1. DLQ directory structure creation
2. dlq list command
3. dlq replay command
4. dlq purge command
5. dlq depth command
6. Expired messages moved to DLQ/expired/
7. Unrouted messages moved to DLQ/unrouted/
8. .reason sidecar format
9. alert:dlq-growing emitted when threshold exceeded
"""

import subprocess
import os
import time
import json

BUS = "/workspaces/Jit/network/bus.sh"
DLQ_ROOT = "/tmp/manusat-bus/_dlq"


def run_bus(*args):
    """Run bus.sh with arguments and return output"""
    result = subprocess.run(
        [BUS] + list(args),
        capture_output=True,
        text=True
    )
    return result.stdout + result.stderr, result.returncode


def test_dlq_directory_structure():
    """Test 1: Verify DLQ directory structure exists"""
    print("Test 1: DLQ directory structure...")
    
    expected_dirs = [
        f"{DLQ_ROOT}/expired",
        f"{DLQ_ROOT}/unrouted",
        f"{DLQ_ROOT}/max-retries",
        f"{DLQ_ROOT}/error",
    ]
    
    for dir_path in expected_dirs:
        assert os.path.isdir(dir_path), f"Missing directory: {dir_path}"
    
    assert os.path.isfile(f"{DLQ_ROOT}/_metadata.json"), "Missing _metadata.json"
    
    print("  ✓ All DLQ directories exist")
    return True


def test_dlq_depth_command():
    """Test 2: dlq depth command"""
    print("Test 2: dlq depth command...")
    
    output, code = run_bus("dlq", "depth")
    assert code == 0, f"dlq depth failed with code {code}"
    assert "DLQ Depth:" in output, "Missing 'DLQ Depth:' in output"
    assert "Threshold:" in output, "Missing 'Threshold:' in output"
    
    print("  ✓ dlq depth command works")
    return True


def test_dlq_list_command():
    """Test 3: dlq list command"""
    print("Test 3: dlq list command...")
    
    output, code = run_bus("dlq", "list")
    assert code == 0, f"dlq list failed with code {code}"
    assert "Dead Letter Queue" in output, "Missing 'Dead Letter Queue' in output"
    assert "expired" in output, "Missing 'expired' category"
    assert "unrouted" in output, "Missing 'unrouted' category"
    
    print("  ✓ dlq list command works")
    return True


def test_expired_message_to_dlq():
    """Test 4: Expired messages moved to DLQ/expired/"""
    print("Test 4: Expired messages → DLQ/expired/...")
    
    # Send message with 1 second TTL
    output, code = run_bus("send", "--ttl", "1", "innova", "test:dlq", "Test expiration")
    assert code == 0, f"send failed: {output}"
    
    # Wait for expiration
    time.sleep(2)
    
    # Sweep expired messages
    output, code = run_bus("sweep")
    assert code == 0, f"sweep failed: {output}"
    assert "DLQ/expired/" in output, "Message not moved to DLQ/expired/"
    
    # Verify in DLQ
    output, code = run_bus("dlq", "list", "expired")
    assert code == 0
    assert "expired: " in output and "messages" in output
    
    print("  ✓ Expired messages moved to DLQ/expired/")
    return True


def test_reason_sidecar_format():
    """Test 5: .reason sidecar format"""
    print("Test 5: .reason sidecar format...")
    
    # Find a .reason file
    reason_files = []
    for root, dirs, files in os.walk(f"{DLQ_ROOT}/expired"):
        for f in files:
            if f.endswith(".reason"):
                reason_files.append(os.path.join(root, f))
    
    if not reason_files:
        # Create one by expiring another message
        run_bus("send", "--ttl", "1", "innova", "test:sidecar", "Test sidecar")
        time.sleep(2)
        run_bus("sweep")
        
        for root, dirs, files in os.walk(f"{DLQ_ROOT}/expired"):
            for f in files:
                if f.endswith(".reason"):
                    reason_files.append(os.path.join(root, f))
    
    assert len(reason_files) > 0, "No .reason files found"
    
    # Check sidecar format
    with open(reason_files[0]) as f:
        content = f.read()
    
    required_fields = [
        "original_to:",
        "original_from:",
        "failure_reason:",
        "failed_at:",
        "retry_count:",
    ]
    
    for field in required_fields:
        assert field in content, f"Missing field: {field}"
    
    print(f"  ✓ .reason sidecar has correct format")
    return True


def test_dlq_replay_command():
    """Test 6: dlq replay command"""
    print("Test 6: dlq replay command...")
    
    # Find a message to replay
    msg_files = []
    for root, dirs, files in os.walk(f"{DLQ_ROOT}/expired"):
        for f in files:
            if f.endswith(".msg"):
                msg_files.append(os.path.join(root, f))
    
    if not msg_files:
        print("  ⊘ Skipping (no messages to replay)")
        return True
    
    # Replay the message
    output, code = run_bus("dlq", "replay", msg_files[0])
    assert code == 0, f"replay failed: {output}"
    assert "Replayed:" in output, "Missing 'Replayed:' in output"
    
    # Verify message removed from DLQ
    assert not os.path.exists(msg_files[0]), "Message not removed from DLQ after replay"
    
    print("  ✓ dlq replay command works")
    return True


def test_dlq_purge_command():
    """Test 7: dlq purge command"""
    print("Test 7: dlq purge command...")
    
    # Create expired messages
    for i in range(3):
        run_bus("send", "--ttl", "1", "innova", f"test:purge{i}", "Test purge")
    time.sleep(2)
    run_bus("sweep")
    
    # Count before purge
    before_count = len([f for f in os.listdir(f"{DLQ_ROOT}/expired") if f.endswith(".msg")])
    
    # Purge old messages
    output, code = run_bus("dlq", "purge", "--older-than", "0d")
    assert code == 0, f"purge failed: {output}"
    assert "Purged" in output, "Missing 'Purged' in output"
    
    # Count after purge
    after_count = len([f for f in os.listdir(f"{DLQ_ROOT}/expired") if f.endswith(".msg")])
    
    assert after_count < before_count, f"Purge did not reduce count: {before_count} → {after_count}"
    
    print("  ✓ dlq purge command works")
    return True


def test_unrouted_message_to_dlq():
    """Test 8: Unrouted messages moved to DLQ/unrouted/"""
    print("Test 8: Unrouted messages → DLQ/unrouted/...")
    
    # Send to non-existent agent
    output, code = run_bus("send", "nonexistent-agent-xyz", "test:unrouted", "Test unrouted")
    
    # Should fail but move to DLQ
    assert code != 0, "Should fail for non-existent agent"
    assert "Unrouted" in output or "DLQ" in output, "Should mention DLQ"
    
    # Verify in DLQ
    output, code = run_bus("dlq", "list", "unrouted")
    assert code == 0
    assert "unrouted: " in output
    
    print("  ✓ Unrouted messages moved to DLQ/unrouted/")
    return True


def test_threshold_alert():
    """Test 9: alert:dlq-growing when threshold exceeded"""
    print("Test 9: Threshold alert (dlq-growing)...")
    
    # First purge existing messages
    run_bus("dlq", "purge", "--older-than", "0d")
    
    # Send many messages that will expire
    threshold = 10
    for i in range(threshold + 2):
        run_bus("send", "--ttl", "1", "innova", f"test:threshold{i}", "Test threshold")
    
    time.sleep(2)
    
    # Sweep should trigger alert
    output, code = run_bus("sweep")
    assert "exceeds threshold" in output.lower() or "dlq-growing" in output.lower(), \
        f"Should emit threshold alert: {output}"
    
    print("  ✓ Threshold alert emitted when DLQ depth exceeded")
    return True


def main():
    print("=" * 60)
    print("JIT-004: Dead-Letter Queue (DLQ) Test Suite")
    print("=" * 60)
    print()
    
    tests = [
        test_dlq_directory_structure,
        test_dlq_depth_command,
        test_dlq_list_command,
        test_expired_message_to_dlq,
        test_reason_sidecar_format,
        test_dlq_replay_command,
        test_dlq_purge_command,
        test_unrouted_message_to_dlq,
        test_threshold_alert,
    ]
    
    passed = 0
    failed = 0
    
    for test in tests:
        try:
            if test():
                passed += 1
        except AssertionError as e:
            print(f"  ✗ FAILED: {e}")
            failed += 1
        except Exception as e:
            print(f"  ✗ ERROR: {e}")
            failed += 1
    
    print()
    print("=" * 60)
    print(f"Results: {passed} passed, {failed} failed")
    print("=" * 60)
    
    return failed == 0


if __name__ == "__main__":
    import sys
    sys.exit(0 if main() else 1)
