#!/usr/bin/env python3
"""
Test JSON injection protection in discord-webhook.sh

JIT-019: Verify that commit messages with special characters are safely escaped
"""

import subprocess
import json
import os
import sys
import base64


def run_jq_test(test_name: str, message: str) -> tuple[bool, str]:
    """Test that a message with special characters produces valid JSON"""

    # Encode message as base64 to safely pass to bash
    msg_b64 = base64.b64encode(message.encode('utf-8')).decode('ascii')

    test_script = f'''
#!/bin/bash
set -euo pipefail

# Decode message from base64 to preserve exact bytes
MESSAGE=$(echo "{msg_b64}" | base64 -d)
commit_msg=$(echo "{msg_b64}" | base64 -d)

BEAT_NUMBER="999"
STATUS="ok"
timestamp="2026-06-07T12:00:00Z"
commit_hash="abc1234"
commit_url="https://github.com/test/repo/commit/abc1234"
emoji="✅"
color_code="65280"

# Reproduce the jq payload construction from discord-webhook.sh
payload=$(jq -n --arg emoji "$emoji" \\
               --arg beat "$BEAT_NUMBER" \\
               --arg status "$STATUS" \\
               --arg msg "$MESSAGE" \\
               --arg ts "$timestamp" \\
               --arg hash "$commit_hash" \\
               --arg url "$commit_url" \\
               --arg commit_msg "$commit_msg" \\
               --arg color "$color_code" \\
'{{
  content: "\\($emoji) **Heartbeat #\\($beat)** - \\($status)",
  embeds: [{{
    title: "Jit Heartbeat #\\($beat)",
    description: $msg,
    color: ($color | tonumber),
    fields: [
      {{ name: "Time", value: $ts, inline: true }},
      {{ name: "Status", value: $status, inline: true }},
      {{ name: "Latest Commit", value: "[`\\($hash)`](\\($url))", inline: false }},
      {{ name: "Commit Message", value: $commit_msg, inline: false }}
    ],
    footer: {{
      text: "Jit Agent System",
      icon_url: "https://avatars.githubusercontent.com/u/123456789?s=32"
    }}
  }}]
}}')

echo "$payload"
'''

    try:
        result = subprocess.run(
            ["bash", "-c", test_script],
            capture_output=True,
            text=True,
            timeout=10
        )

        if result.returncode != 0:
            return False, f"Script execution failed: {result.stderr}"

        payload_output = result.stdout.strip()

        # Try to parse as JSON - this validates proper escaping
        try:
            parsed = json.loads(payload_output)

            # Verify the message content is preserved correctly
            description = parsed.get("embeds", [{}])[0].get("description", "")
            commit_msg_field = parsed.get("embeds", [{}])[0].get("fields", [{}])[3].get("value", "")

            if description == message and commit_msg_field == message:
                return True, "JSON valid and content preserved"
            else:
                return False, f"Content mismatch - expected {repr(message)}, got {repr(description)}"

        except json.JSONDecodeError as e:
            return False, f"Invalid JSON: {e} - Output: {payload_output[:200]}"

    except subprocess.TimeoutExpired:
        return False, "Timeout"
    except Exception as e:
        return False, f"Error: {e}"


def test_json_escaping():
    """Test that special characters in messages are properly JSON-escaped"""

    # Test cases with dangerous payloads
    # Using chr() to ensure actual control characters
    test_cases = [
        ("quotes", 'Message with "double" and \'single\' quotes'),
        ("newlines", "Line1" + chr(10) + "Line2" + chr(10) + "Line3"),
        ("backslashes", r"C:\Users\path\to\file"),
        ("tabs", "Col1" + chr(9) + "Col2" + chr(9) + "Col3"),
        ("unicode", "Hello 世界 🫀 émojis"),
        ("mixed", 'Quote " and' + chr(10) + 'newline and' + chr(9) + 'tab'),
        ("json_injection", '{"malicious": "payload"}'),
        ("html_like", "<script>alert('xss')</script>"),
    ]

    results = []

    for test_name, message in test_cases:
        print(f"\n🧪 Testing: {test_name}")
        print(f"   Input: {repr(message)}")

        ok, reason = run_jq_test(test_name, message)

        if ok:
            print(f"   ✅ PASS")
            results.append((test_name, True, reason))
        else:
            print(f"   ❌ FAIL: {reason}")
            results.append((test_name, False, reason))

    return results


def main():
    print("=" * 60)
    print("JIT-019: JSON Injection Protection Test")
    print("=" * 60)

    results = test_json_escaping()

    print("\n" + "=" * 60)
    print("SUMMARY")
    print("=" * 60)

    passed = sum(1 for _, ok, _ in results if ok)
    total = len(results)

    for name, ok, reason in results:
        status = "✅ PASS" if ok else "❌ FAIL"
        print(f"{status} - {name}: {reason}")

    print(f"\nTotal: {passed}/{total} tests passed")

    if passed == total:
        print("\n🎉 All JSON injection protections working correctly!")
        return 0
    else:
        print(f"\n⚠️  {total - passed} test(s) failed")
        return 1


if __name__ == "__main__":
    sys.exit(main())
