#!/usr/bin/env python3
"""
Security Test Suite #5 - Advanced Vulnerability Categories
Fast execution - generates test cases in JSON format with status tracking
"""

import json
import sys
from datetime import datetime
from pathlib import Path


def generate_test_suite_5():
    """Generate security test cases for Suite #5"""

    start_time = datetime.utcnow()

    test_cases = [
        # Deserialization Attacks (5 cases)
        {
            "id": "SEC-DESER-001",
            "category": "Deserialization",
            "name": "Unsafe pickle() Usage",
            "payload": "pickle.loads(user_input)",
            "expected_detection": "UNSAFE_PICKLE",
            "severity": "CRITICAL",
            "cwe": "CWE-502"
        },
        {
            "id": "SEC-DESER-002",
            "category": "Deserialization",
            "name": "YAML unsafe_load Usage",
            "payload": "yaml.unsafe_load(config_string)",
            "expected_detection": "UNSAFE_YAML",
            "severity": "CRITICAL",
            "cwe": "CWE-502"
        },
        {
            "id": "SEC-DESER-003",
            "category": "Deserialization",
            "name": "XML External Entity (XXE)",
            "payload": "<!DOCTYPE foo [<!ENTITY xxe SYSTEM \"file:///etc/passwd\">]>",
            "expected_detection": "XXE_INJECTION",
            "severity": "CRITICAL",
            "cwe": "CWE-611"
        },
        {
            "id": "SEC-DESER-004",
            "category": "Deserialization",
            "name": "Unsafe JSON deserialization with reviver",
            "payload": "JSON.parse(input, (key, val) => eval(val))",
            "expected_detection": "UNSAFE_JSON_PARSE",
            "severity": "CRITICAL",
            "cwe": "CWE-95"
        },
        {
            "id": "SEC-DESER-005",
            "category": "Deserialization",
            "name": "Insecure Java ObjectInputStream",
            "payload": "new ObjectInputStream(socket.getInputStream()).readObject()",
            "expected_detection": "UNSAFE_OBJECT_STREAM",
            "severity": "CRITICAL",
            "cwe": "CWE-502"
        },

        # LDAP/SSRF Vulnerabilities (5 cases)
        {
            "id": "SEC-LDAP-001",
            "category": "LDAP Injection",
            "name": "Basic LDAP Injection",
            "payload": "*)(uid=*",
            "expected_detection": "LDAP_INJECTION",
            "severity": "HIGH",
            "cwe": "CWE-90"
        },
        {
            "id": "SEC-LDAP-002",
            "category": "LDAP Injection",
            "name": "LDAP Filter Bypass",
            "payload": "admin*))(&(uid=*",
            "expected_detection": "LDAP_INJECTION",
            "severity": "HIGH",
            "cwe": "CWE-90"
        },
        {
            "id": "SEC-SSRF-001",
            "category": "SSRF",
            "name": "Server-Side Request Forgery",
            "payload": "http://localhost:6379/set?key=admin&val=true",
            "expected_detection": "SSRF_DETECTION",
            "severity": "HIGH",
            "cwe": "CWE-918"
        },
        {
            "id": "SEC-SSRF-002",
            "category": "SSRF",
            "name": "Internal Service Access via SSRF",
            "payload": "http://169.254.169.254/latest/meta-data/",
            "expected_detection": "SSRF_METADATA",
            "severity": "CRITICAL",
            "cwe": "CWE-918"
        },
        {
            "id": "SEC-SSRF-003",
            "category": "SSRF",
            "name": "SSRF with Port Scanning",
            "payload": "http://127.0.0.1:8080,8081,8082,8443",
            "expected_detection": "SSRF_PORT_SCAN",
            "severity": "HIGH",
            "cwe": "CWE-918"
        },

        # Path Traversal (5 cases)
        {
            "id": "SEC-PATH-001",
            "category": "Path Traversal",
            "name": "Basic Directory Traversal",
            "payload": "../../../../../../etc/passwd",
            "expected_detection": "PATH_TRAVERSAL",
            "severity": "HIGH",
            "cwe": "CWE-22"
        },
        {
            "id": "SEC-PATH-002",
            "category": "Path Traversal",
            "name": "URL-encoded Traversal",
            "payload": "%2e%2e%2f%2e%2e%2fetc%2fpasswd",
            "expected_detection": "PATH_TRAVERSAL_ENCODED",
            "severity": "HIGH",
            "cwe": "CWE-22"
        },
        {
            "id": "SEC-PATH-003",
            "category": "Path Traversal",
            "name": "Double-URL Encoding Traversal",
            "payload": "%252e%252e%252fetc%252fpasswd",
            "expected_detection": "PATH_TRAVERSAL_DOUBLE",
            "severity": "HIGH",
            "cwe": "CWE-22"
        },
        {
            "id": "SEC-PATH-004",
            "category": "Path Traversal",
            "name": "Backslash Traversal (Windows)",
            "payload": "..\\..\\..\\windows\\system32\\config\\sam",
            "expected_detection": "PATH_TRAVERSAL_WINDOWS",
            "severity": "HIGH",
            "cwe": "CWE-22"
        },
        {
            "id": "SEC-PATH-005",
            "category": "Path Traversal",
            "name": "Symlink Attack",
            "payload": "uploads/profile.txt -> /etc/shadow",
            "expected_detection": "SYMLINK_ATTACK",
            "severity": "MEDIUM",
            "cwe": "CWE-59"
        },

        # Race Conditions & Timing (4 cases)
        {
            "id": "SEC-RACE-001",
            "category": "Race Condition",
            "name": "TOCTOU File Access",
            "payload": "check_exists(file) && read_file(file)  # gap between check and use",
            "expected_detection": "RACE_CONDITION_TOCTOU",
            "severity": "HIGH",
            "cwe": "CWE-367"
        },
        {
            "id": "SEC-TIMING-001",
            "category": "Timing Attack",
            "name": "Password Comparison Timing Leak",
            "payload": "password == user_input  # non-constant time",
            "expected_detection": "TIMING_LEAK",
            "severity": "MEDIUM",
            "cwe": "CWE-208"
        },
        {
            "id": "SEC-TIMING-002",
            "category": "Timing Attack",
            "name": "Sensitive Operation Timing",
            "payload": "if token_valid(input): process() else: fail()  # observable difference",
            "expected_detection": "TIMING_LEAK_SENSITIVE",
            "severity": "MEDIUM",
            "cwe": "CWE-208"
        },
        {
            "id": "SEC-RACE-002",
            "category": "Race Condition",
            "name": "Concurrent Modification",
            "payload": "data[key] += 1  # non-atomic operation in multi-thread",
            "expected_detection": "RACE_CONDITION_ATOMIC",
            "severity": "HIGH",
            "cwe": "CWE-362"
        },

        # Dependency/Supply Chain (4 cases)
        {
            "id": "SEC-SUPPLY-001",
            "category": "Supply Chain",
            "name": "Known Vulnerable Dependency",
            "payload": "lodash==4.17.15  # CVE-2021-23337",
            "expected_detection": "VULN_DEPENDENCY",
            "severity": "HIGH",
            "cwe": "CWE-1035"
        },
        {
            "id": "SEC-SUPPLY-002",
            "category": "Supply Chain",
            "name": "Outdated Package Version",
            "payload": "django==1.11.0  # multiple CVEs",
            "expected_detection": "OUTDATED_DEPENDENCY",
            "severity": "MEDIUM",
            "cwe": "CWE-1035"
        },
        {
            "id": "SEC-SUPPLY-003",
            "category": "Supply Chain",
            "name": "Typosquatting Detection",
            "payload": "npm package 'colorama' vs 'coloama'",
            "expected_detection": "TYPOSQUATTING",
            "severity": "HIGH",
            "cwe": "CWE-426"
        },
        {
            "id": "SEC-SUPPLY-004",
            "category": "Supply Chain",
            "name": "Unverified Package Signature",
            "payload": "downloaded package without GPG verification",
            "expected_detection": "UNVERIFIED_SIGNATURE",
            "severity": "MEDIUM",
            "cwe": "CWE-347"
        },

        # Information Disclosure (5 cases)
        {
            "id": "SEC-INFO-001",
            "category": "Information Disclosure",
            "name": "Stack Trace Exposure",
            "payload": "print(traceback.format_exc())  # in production",
            "expected_detection": "STACK_TRACE_EXPOSED",
            "severity": "MEDIUM",
            "cwe": "CWE-209"
        },
        {
            "id": "SEC-INFO-002",
            "category": "Information Disclosure",
            "name": "Sensitive Header Exposure",
            "payload": "X-Debug-Info: database connection string",
            "expected_detection": "SENSITIVE_HEADER",
            "severity": "HIGH",
            "cwe": "CWE-200"
        },
        {
            "id": "SEC-INFO-003",
            "category": "Information Disclosure",
            "name": "API Version Exposure",
            "payload": "X-API-Version: 2.1.3-beta // internal version",
            "expected_detection": "VERSION_EXPOSURE",
            "severity": "LOW",
            "cwe": "CWE-200"
        },
        {
            "id": "SEC-INFO-004",
            "category": "Information Disclosure",
            "name": "Comments with Secrets",
            "payload": "# TODO: remove this debug API_KEY = 'sk-xyz123'",
            "expected_detection": "SECRET_IN_COMMENT",
            "severity": "CRITICAL",
            "cwe": "CWE-798"
        },
        {
            "id": "SEC-INFO-005",
            "category": "Information Disclosure",
            "name": "Git History Exposure",
            "payload": ".git directory exposed publicly",
            "expected_detection": "GIT_EXPOSURE",
            "severity": "CRITICAL",
            "cwe": "CWE-200"
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
        "suite_name": "SECURITY_TEST_SUITE_5",
        "suite_id": "JIT-SECURITY-005",
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
    suite = generate_test_suite_5()

    # Output as JSON
    json_output = json.dumps(suite, indent=2)
    print(json_output)

    # Save to file
    output_path = Path(__file__).parent / "security_test_suite_5_results.json"
    with open(output_path, "w") as f:
        f.write(json_output)

    # Print summary
    summary = suite["summary"]
    print("\n--- Test Suite #5 Summary ---", file=sys.stderr)
    print(f"Total Tests: {summary['total_test_cases']}", file=sys.stderr)
    print(f"Critical: {summary['by_severity']['CRITICAL']}", file=sys.stderr)
    print(f"High: {summary['by_severity']['HIGH']}", file=sys.stderr)
    print(f"Completion: {summary['completion_percent']}%", file=sys.stderr)
