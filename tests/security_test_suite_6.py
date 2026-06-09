#!/usr/bin/env python3
"""
Security Test Suite #6 - Authentication, Authorization, and Cryptographic Issues
Fast execution - generates test cases in JSON format with status tracking
"""

import json
import sys
from datetime import datetime
from pathlib import Path


def generate_test_suite_6():
    """Generate security test cases for Suite #6"""

    start_time = datetime.utcnow()

    test_cases = [
        # Authentication Vulnerabilities (5 cases)
        {
            "id": "SEC-AUTH-001",
            "category": "Authentication",
            "name": "Hardcoded Credentials in Code",
            "payload": "username='admin'; password='password123'  # hardcoded",
            "expected_detection": "HARDCODED_CREDENTIALS",
            "severity": "CRITICAL",
            "cwe": "CWE-798"
        },
        {
            "id": "SEC-AUTH-002",
            "category": "Authentication",
            "name": "Default Credentials Used",
            "payload": "login('admin', 'admin')  # default password never changed",
            "expected_detection": "DEFAULT_CREDENTIALS",
            "severity": "CRITICAL",
            "cwe": "CWE-521"
        },
        {
            "id": "SEC-AUTH-003",
            "category": "Authentication",
            "name": "Weak Password Policy",
            "payload": "password length minimum = 3, no complexity required",
            "expected_detection": "WEAK_PASSWORD_POLICY",
            "severity": "HIGH",
            "cwe": "CWE-521"
        },
        {
            "id": "SEC-AUTH-004",
            "category": "Authentication",
            "name": "Missing Multi-Factor Authentication",
            "payload": "authenticate(username, password)  # no 2FA/MFA check",
            "expected_detection": "MISSING_MFA",
            "severity": "HIGH",
            "cwe": "CWE-1390"
        },
        {
            "id": "SEC-AUTH-005",
            "category": "Authentication",
            "name": "Password Transmitted in Plaintext",
            "payload": "http://example.com/login?password=user123",
            "expected_detection": "PLAINTEXT_PASSWORD",
            "severity": "CRITICAL",
            "cwe": "CWE-319"
        },

        # Authorization & Access Control (5 cases)
        {
            "id": "SEC-AUTHZ-001",
            "category": "Authorization",
            "name": "Missing Authorization Check",
            "payload": "def delete_user(user_id): db.delete(users, id=user_id)  # no permission check",
            "expected_detection": "MISSING_AUTHZ_CHECK",
            "severity": "CRITICAL",
            "cwe": "CWE-862"
        },
        {
            "id": "SEC-AUTHZ-002",
            "category": "Authorization",
            "name": "Broken Access Control - IDOR",
            "payload": "GET /api/users/123/profile  # fetches user 123's data without verifying requestor owns it",
            "expected_detection": "IDOR_VULNERABILITY",
            "severity": "CRITICAL",
            "cwe": "CWE-639"
        },
        {
            "id": "SEC-AUTHZ-003",
            "category": "Authorization",
            "name": "Privilege Escalation via Parameter",
            "payload": "POST /user/update?is_admin=true",
            "expected_detection": "PRIVILEGE_ESCALATION",
            "severity": "CRITICAL",
            "cwe": "CWE-269"
        },
        {
            "id": "SEC-AUTHZ-004",
            "category": "Authorization",
            "name": "Role-Based Access Control Bypass",
            "payload": "user.role = 'admin'  # client-side role assignment",
            "expected_detection": "RBAC_BYPASS",
            "severity": "CRITICAL",
            "cwe": "CWE-639"
        },
        {
            "id": "SEC-AUTHZ-005",
            "category": "Authorization",
            "name": "Horizontal Privilege Escalation",
            "payload": "GET /users/profiles?user_id=456  # view another user's private profile",
            "expected_detection": "HORIZONTAL_ESCALATION",
            "severity": "HIGH",
            "cwe": "CWE-639"
        },

        # Cryptographic Weaknesses (6 cases)
        {
            "id": "SEC-CRYPTO-001",
            "category": "Cryptography",
            "name": "Use of MD5 for Hashing",
            "payload": "import hashlib; hashlib.md5(password).hexdigest()",
            "expected_detection": "WEAK_HASH_MD5",
            "severity": "HIGH",
            "cwe": "CWE-327"
        },
        {
            "id": "SEC-CRYPTO-002",
            "category": "Cryptography",
            "name": "Use of SHA1 for Hashing",
            "payload": "hashlib.sha1(password).hexdigest()  # SHA1 is cryptographically broken",
            "expected_detection": "WEAK_HASH_SHA1",
            "severity": "HIGH",
            "cwe": "CWE-327"
        },
        {
            "id": "SEC-CRYPTO-003",
            "category": "Cryptography",
            "name": "Missing Salt in Password Hashing",
            "payload": "bcrypt.hashpw(password, bcrypt.gensalt(rounds=4))  # weak rounds (4 instead of 12+)",
            "expected_detection": "WEAK_BCRYPT_ROUNDS",
            "severity": "HIGH",
            "cwe": "CWE-330"
        },
        {
            "id": "SEC-CRYPTO-004",
            "category": "Cryptography",
            "name": "Hardcoded Encryption Key",
            "payload": "AES.new('secret_key_12345')  # hardcoded key",
            "expected_detection": "HARDCODED_CRYPTO_KEY",
            "severity": "CRITICAL",
            "cwe": "CWE-321"
        },
        {
            "id": "SEC-CRYPTO-005",
            "category": "Cryptography",
            "name": "Weak Random Number Generation",
            "payload": "random.randint(0, 1000000)  # not cryptographically secure",
            "expected_detection": "WEAK_RNG",
            "severity": "HIGH",
            "cwe": "CWE-338"
        },
        {
            "id": "SEC-CRYPTO-006",
            "category": "Cryptography",
            "name": "ECB Mode Encryption",
            "payload": "cipher = AES.new(key, AES.MODE_ECB)  # deterministic, vulnerable to pattern analysis",
            "expected_detection": "WEAK_ECB_MODE",
            "severity": "HIGH",
            "cwe": "CWE-327"
        },

        # Session Management (5 cases)
        {
            "id": "SEC-SESSION-001",
            "category": "Session Management",
            "name": "Predictable Session ID",
            "payload": "session_id = timestamp + user_id  # sequential and predictable",
            "expected_detection": "PREDICTABLE_SESSION_ID",
            "severity": "CRITICAL",
            "cwe": "CWE-330"
        },
        {
            "id": "SEC-SESSION-002",
            "category": "Session Management",
            "name": "Missing Session Expiration",
            "payload": "session.setMaxInactiveInterval(-1)  # session never expires",
            "expected_detection": "MISSING_SESSION_TIMEOUT",
            "severity": "HIGH",
            "cwe": "CWE-613"
        },
        {
            "id": "SEC-SESSION-003",
            "category": "Session Management",
            "name": "Session Fixation Attack",
            "payload": "session.id = attacker_controlled_value  # no re-generation on login",
            "expected_detection": "SESSION_FIXATION",
            "severity": "HIGH",
            "cwe": "CWE-384"
        },
        {
            "id": "SEC-SESSION-004",
            "category": "Session Management",
            "name": "Session ID in URL",
            "payload": "<a href='/page?sessionid=abc123def456'>",
            "expected_detection": "SESSION_ID_IN_URL",
            "severity": "HIGH",
            "cwe": "CWE-414"
        },
        {
            "id": "SEC-SESSION-005",
            "category": "Session Management",
            "name": "Insecure Session Cookie",
            "payload": "response.set_cookie('session', value, httponly=False, secure=False)",
            "expected_detection": "INSECURE_COOKIE",
            "severity": "HIGH",
            "cwe": "CWE-614"
        },

        # Insecure Direct Object References & Data Exposure (4 cases)
        {
            "id": "SEC-DATA-001",
            "category": "Data Exposure",
            "name": "Sensitive Data in Logs",
            "payload": "logger.info(f'User {username} password: {password} logged in')",
            "expected_detection": "SENSITIVE_DATA_LOGGING",
            "severity": "CRITICAL",
            "cwe": "CWE-532"
        },
        {
            "id": "SEC-DATA-002",
            "category": "Data Exposure",
            "name": "Unencrypted Sensitive Data at Rest",
            "payload": "db.store(email, address, ssn, medical_history)  # plaintext in database",
            "expected_detection": "UNENCRYPTED_PII",
            "severity": "CRITICAL",
            "cwe": "CWE-312"
        },
        {
            "id": "SEC-DATA-003",
            "category": "Data Exposure",
            "name": "Data Exposure in Error Messages",
            "payload": "except Exception as e: return {'error': str(e), 'user_data': request.data}",
            "expected_detection": "DATA_EXPOSURE_ERROR",
            "severity": "HIGH",
            "cwe": "CWE-209"
        },
        {
            "id": "SEC-DATA-004",
            "category": "Data Exposure",
            "name": "Backup Files Left Exposed",
            "payload": "GET /app/backup.sql.bak  # backup file accessible publicly",
            "expected_detection": "BACKUP_EXPOSURE",
            "severity": "CRITICAL",
            "cwe": "CWE-200"
        },

        # Token & JWT Vulnerabilities (5 cases)
        {
            "id": "SEC-TOKEN-001",
            "category": "Token Security",
            "name": "JWT with 'none' Algorithm",
            "payload": "jwt.decode(token, options={'verify_signature': False})",
            "expected_detection": "JWT_NONE_ALGORITHM",
            "severity": "CRITICAL",
            "cwe": "CWE-347"
        },
        {
            "id": "SEC-TOKEN-002",
            "category": "Token Security",
            "name": "JWT with Weak Secret",
            "payload": "jwt.encode(payload, 'secret', algorithm='HS256')",
            "expected_detection": "JWT_WEAK_SECRET",
            "severity": "CRITICAL",
            "cwe": "CWE-327"
        },
        {
            "id": "SEC-TOKEN-003",
            "category": "Token Security",
            "name": "Expired Token Not Validated",
            "payload": "jwt.decode(token, SECRET_KEY)  # no expiration check",
            "expected_detection": "EXPIRED_TOKEN_ACCEPTED",
            "severity": "HIGH",
            "cwe": "CWE-613"
        },
        {
            "id": "SEC-TOKEN-004",
            "category": "Token Security",
            "name": "Bearer Token in Logs",
            "payload": "logger.debug(f'Authorization header: {headers[Authorization]}')",
            "expected_detection": "TOKEN_IN_LOGS",
            "severity": "CRITICAL",
            "cwe": "CWE-532"
        },
        {
            "id": "SEC-TOKEN-005",
            "category": "Token Security",
            "name": "CSRF Token Not Validated",
            "payload": "POST /api/transfer without CSRF token validation",
            "expected_detection": "MISSING_CSRF_TOKEN",
            "severity": "HIGH",
            "cwe": "CWE-352"
        },
    ]

    # Calculate metrics
    total_tests = len(test_cases)
    critical_count = len([t for t in test_cases if t["severity"] == "CRITICAL"])
    high_count = len([t for t in test_cases if t["severity"] == "HIGH"])
    medium_count = len([t for t in test_cases if t["severity"] == "MEDIUM"])
    low_count = len([t for t in test_cases if t["severity"] == "LOW"])

    categories = {}
    for tc in test_cases:
        cat = tc["category"]
        categories[cat] = categories.get(cat, 0) + 1

    end_time = datetime.utcnow()
    duration_ms = (end_time - start_time).total_seconds() * 1000

    # Build result object
    result = {
        "status": "success",
        "suite_name": "SECURITY_TEST_SUITE_6",
        "suite_id": "JIT-SECURITY-006",
        "timestamp": start_time.isoformat() + "Z",
        "execution_time_ms": duration_ms,
        "test_cases": test_cases,
        "summary": {
            "total_test_cases": total_tests,
            "by_severity": {
                "CRITICAL": critical_count,
                "HIGH": high_count,
                "MEDIUM": medium_count,
                "LOW": low_count
            },
            "by_category": categories,
            "completion_percent": 100
        }
    }

    return result


if __name__ == "__main__":
    suite = generate_test_suite_6()

    # Output as JSON
    json_output = json.dumps(suite, indent=2)
    print(json_output)

    # Save to file
    output_path = Path(__file__).parent / "security_test_suite_6_results.json"
    with open(output_path, "w") as f:
        f.write(json_output)

    # Print summary
    summary = suite["summary"]
    print("\n--- Test Suite #6 Summary ---", file=sys.stderr)
    print(f"Total Tests: {summary['total_test_cases']}", file=sys.stderr)
    print(f"Critical: {summary['by_severity']['CRITICAL']}", file=sys.stderr)
    print(f"High: {summary['by_severity']['HIGH']}", file=sys.stderr)
    print(f"Completion: {summary['completion_percent']}%", file=sys.stderr)
