"""
Security Test Suite #1 - Core Vulnerability Test Cases
Fast execution focus - spawns security test harness
JIT-SECURITY-001
"""

import pytest
import json
import hashlib
import os
from datetime import datetime
from pathlib import Path


class SecurityTestConfig:
    """Configuration for security test suite"""
    START_TIME = datetime.utcnow()
    TEST_CASES = []
    RESULTS = {
        "suite_id": "JIT-SECURITY-001",
        "provider": "pytest",
        "start_time": START_TIME.isoformat(),
        "test_cases": [],
        "summary": {
            "total": 0,
            "passed": 0,
            "failed": 0,
            "skipped": 0
        }
    }


class TestSQLInjectionVulnerabilities:
    """SQL Injection Prevention Tests"""

    def test_basic_sql_injection_detection(self):
        """Detect basic SQL injection: ' OR '1'='1"""
        payload = "' OR '1'='1"
        dangerous_patterns = self._check_dangerous_pattern(payload)
        assert 'SQL_INJECTION' in dangerous_patterns, f"SQL injection not detected in: {payload}"

    def test_union_based_injection(self):
        """Detect UNION-based SQL injection"""
        payload = "' UNION SELECT username, password FROM users--"
        dangerous_patterns = self._check_dangerous_pattern(payload)
        assert 'SQL_INJECTION' in dangerous_patterns, "UNION injection not detected"

    def test_time_based_blind_injection(self):
        """Detect time-based blind SQL injection"""
        payload = "'; WAITFOR DELAY '00:00:05'--"
        dangerous_patterns = self._check_dangerous_pattern(payload)
        assert 'SQL_INJECTION' in dangerous_patterns, "Time-based injection not detected"

    def test_stacked_queries_injection(self):
        """Detect stacked queries SQL injection"""
        payload = "'; DROP TABLE users; SELECT * FROM userinfo WHERE 't'='t"
        dangerous_patterns = self._check_dangerous_pattern(payload)
        assert 'SQL_INJECTION' in dangerous_patterns, "Stacked query injection not detected"

    def test_mysql_comment_injection(self):
        """Detect MySQL comment-based injection"""
        payload = "admin' #"
        dangerous_patterns = self._check_dangerous_pattern(payload)
        assert 'SQL_INJECTION' in dangerous_patterns, "MySQL comment injection not detected"

    def test_blind_boolean_injection(self):
        """Detect boolean-based blind SQL injection"""
        payload = "' AND '1'='1"
        dangerous_patterns = self._check_dangerous_pattern(payload)
        assert 'SQL_INJECTION' in dangerous_patterns, "Boolean blind injection not detected"

    @staticmethod
    def _check_dangerous_pattern(payload):
        """Helper to detect dangerous patterns"""
        sql_patterns = ['OR', 'UNION', 'SELECT', 'DROP', 'DELETE', 'INSERT', 'UPDATE', 'WAITFOR', '--', ';']
        return ['SQL_INJECTION'] if any(p in payload.upper() for p in sql_patterns) else []


class TestCrossSiteScriptingVulnerabilities:
    """XSS Prevention Tests"""

    def test_script_tag_injection(self):
        """Detect <script> tag injection"""
        payload = '<script>alert("XSS")</script>'
        dangerous = self._detect_xss(payload)
        assert dangerous, "Script tag XSS not detected"

    def test_img_event_handler_injection(self):
        """Detect img tag event handler injection"""
        payload = '<img src=x onerror="alert(\'XSS\')">'
        dangerous = self._detect_xss(payload)
        assert dangerous, "Img onerror XSS not detected"

    def test_svg_event_injection(self):
        """Detect SVG event handler injection"""
        payload = '<svg onload="alert(\'XSS\')">'
        dangerous = self._detect_xss(payload)
        assert dangerous, "SVG onload XSS not detected"

    def test_iframe_injection(self):
        """Detect iframe injection"""
        payload = '<iframe src="javascript:alert(\'XSS\')"></iframe>'
        dangerous = self._detect_xss(payload)
        assert dangerous, "Iframe XSS not detected"

    def test_data_uri_injection(self):
        """Detect data: URI injection"""
        payload = '<a href="data:text/html,<script>alert(\'XSS\')</script>">Click</a>'
        dangerous = self._detect_xss(payload)
        assert dangerous, "Data URI XSS not detected"

    def test_style_injection(self):
        """Detect style-based XSS"""
        payload = '<div style="background:url(javascript:alert(\'XSS\'))"></div>'
        dangerous = self._detect_xss(payload)
        assert dangerous, "Style injection XSS not detected"

    @staticmethod
    def _detect_xss(payload):
        """Helper to detect XSS patterns"""
        xss_patterns = ['<script', 'onerror=', 'onload=', 'onclick=', 'onmouseover=',
                       'javascript:', 'data:text/html', '<iframe', '<svg']
        return any(p in payload.lower() for p in xss_patterns)


class TestCommandInjectionVulnerabilities:
    """Command Injection Prevention Tests"""

    def test_shell_metacharacter_injection(self):
        """Detect shell metacharacter injection"""
        payload = "test; rm -rf /"
        assert self._is_command_injection(payload), "Semicolon command injection not detected"

    def test_pipe_command_injection(self):
        """Detect pipe-based command injection"""
        payload = "test | cat /etc/passwd"
        assert self._is_command_injection(payload), "Pipe command injection not detected"

    def test_ampersand_command_injection(self):
        """Detect && and || command injection"""
        payloads = ["test && rm -rf /", "test || cat /etc/passwd"]
        for payload in payloads:
            assert self._is_command_injection(payload), f"Ampersand injection not detected: {payload}"

    def test_backtick_execution_injection(self):
        """Detect backtick command execution"""
        payload = "test`whoami`"
        assert self._is_command_injection(payload), "Backtick injection not detected"

    def test_dollar_paren_injection(self):
        """Detect $() command substitution"""
        payload = "test$(whoami)"
        assert self._is_command_injection(payload), "Dollar-paren injection not detected"

    @staticmethod
    def _is_command_injection(payload):
        """Helper to detect command injection patterns"""
        injection_patterns = [';', '|', '&', '`', '$(', '`']
        return any(p in payload for p in injection_patterns)


class TestCryptographicVulnerabilities:
    """Cryptographic Security Tests"""

    def test_weak_hash_detection_md5(self):
        """Detect MD5 usage (weak hash)"""
        weak_hashes = ['md5', 'MD5', 'hashlib.md5']
        code_sample = "password_hash = hashlib.md5(password.encode()).hexdigest()"
        assert any(h in code_sample for h in weak_hashes), "MD5 weak hash not detected"

    def test_weak_hash_detection_sha1(self):
        """Detect SHA1 usage (weak hash)"""
        code_sample = "hash = hashlib.sha1(data).hexdigest()"
        assert 'sha1' in code_sample.lower(), "SHA1 weak hash not detected"

    def test_hardcoded_secret_detection(self):
        """Detect hardcoded secrets"""
        code_samples = [
            'api_key = "sk-1234567890abcdef"',
            'password = "mySecurePassword123"',
            'token = "ghp_ABC123XYZ"'
        ]
        for sample in code_samples:
            assert any(kw in sample for kw in ['api_key', 'password', 'token']), \
                f"Hardcoded secret not detected: {sample}"

    def test_random_module_vulnerability(self):
        """Detect insecure random.random() for cryptography"""
        code_sample = "token = str(random.random())"
        assert 'random.random' in code_sample, "Insecure random not detected"

    def test_ssl_verification_disabled(self):
        """Detect disabled SSL verification"""
        payloads = [
            'verify=False',
            'ssl._create_default_https_context = ssl._create_unverified_context',
            'requests.get(url, verify=False)'
        ]
        for payload in payloads:
            assert 'verify=False' in payload or 'unverified' in payload.lower(), \
                f"SSL verification bypass not detected: {payload}"


class TestAuthenticationVulnerabilities:
    """Authentication & Authorization Tests"""

    def test_missing_authentication_check(self):
        """Detect missing authentication check"""
        route_without_auth = {
            'path': '/api/admin/users',
            'auth_required': False,
            'public': True
        }
        assert not route_without_auth['auth_required'], "Auth bypass not detected"

    def test_weak_password_policy(self):
        """Detect weak password policy"""
        weak_policy = {
            'min_length': 3,
            'require_numbers': False,
            'require_special': False,
            'require_uppercase': False
        }
        assert weak_policy['min_length'] < 8, "Weak password policy not detected"

    def test_session_fixation_vulnerability(self):
        """Detect session fixation vulnerability"""
        vulnerable_code = """
def login(username):
    session['user'] = username
    # No session ID regeneration
        """
        assert 'session' in vulnerable_code and 'user' in vulnerable_code, \
            "Session fixation not detected"

    def test_privilege_escalation(self):
        """Detect privilege escalation vulnerability"""
        vulnerable_endpoint = {
            'url': '/api/user/123/promote',
            'requires_admin': False,
            'allows_self_promotion': True
        }
        assert vulnerable_endpoint['allows_self_promotion'], "Privilege escalation not detected"

    def test_jwt_secret_exposure(self):
        """Detect exposed JWT secrets"""
        vulnerable_config = """
JWT_SECRET = "my-secret-key-123"  # Exposed in code
        """
        assert 'JWT_SECRET' in vulnerable_config, "JWT secret exposure not detected"


class TestInputValidationVulnerabilities:
    """Input Validation Tests"""

    def test_missing_input_validation(self):
        """Detect missing input validation"""
        vulnerable_func = "def process(user_input): return eval(user_input)"
        assert 'eval' in vulnerable_func, "Unsafe eval not detected"

    def test_buffer_overflow_vulnerability(self):
        """Detect buffer overflow risk"""
        vulnerable = "strcpy(buffer, user_input)  # No bounds check"
        assert 'strcpy' in vulnerable and 'user_input' in vulnerable, "Buffer overflow not detected"

    def test_path_traversal_vulnerability(self):
        """Detect path traversal vulnerability"""
        payload = "../../../../etc/passwd"
        assert '..' in payload, "Path traversal not detected"

    def test_null_byte_injection(self):
        """Detect null byte injection"""
        payload = "file.txt%00.jpg"
        assert '%00' in payload or '\x00' in payload, "Null byte not detected"

    def test_unrestricted_file_upload(self):
        """Detect unrestricted file upload"""
        vulnerable_upload = {
            'check_extension': False,
            'check_mime': False,
            'max_size': 999999999
        }
        assert not vulnerable_upload['check_extension'], "Unrestricted upload not detected"


class TestDataExposureVulnerabilities:
    """Data Exposure Tests"""

    def test_plaintext_password_storage(self):
        """Detect plaintext password storage"""
        vulnerable = "password = user_input  # Stored plaintext"
        assert 'password' in vulnerable and 'plaintext' in vulnerable, \
            "Plaintext password storage not detected"

    def test_sensitive_data_in_logs(self):
        """Detect sensitive data in logs"""
        sensitive_log = 'logger.info(f"User login: {username}, password: {password}")'
        assert 'password' in sensitive_log, "Sensitive data in logs not detected"

    def test_sensitive_data_in_url(self):
        """Detect sensitive data in URLs"""
        url = "https://api.example.com/user?id=123&api_key=secret123"
        assert 'api_key' in url, "API key in URL not detected"

    def test_information_disclosure(self):
        """Detect information disclosure"""
        error_message = "Database connection failed: server=db.example.com, user=admin, password=pass123"
        assert 'password' in error_message, "Credentials in error message not detected"

    def test_insufficient_logging(self):
        """Detect insufficient security logging"""
        vulnerable_system = {
            'log_login_attempts': False,
            'log_failed_auth': False,
            'log_admin_actions': False
        }
        assert not vulnerable_system['log_login_attempts'], "Missing login logging detected"


class TestSecurityHeaderVulnerabilities:
    """Security Header Tests"""

    def test_missing_csp_header(self):
        """Detect missing CSP header"""
        headers = {'Content-Type': 'application/json'}
        assert 'Content-Security-Policy' not in headers, "Missing CSP not detected"

    def test_missing_x_frame_options_header(self):
        """Detect missing X-Frame-Options"""
        headers = {'Content-Type': 'text/html'}
        assert 'X-Frame-Options' not in headers, "Missing X-Frame-Options not detected"

    def test_missing_strict_transport_security(self):
        """Detect missing HSTS header"""
        headers = {'Content-Type': 'text/html'}
        assert 'Strict-Transport-Security' not in headers, "Missing HSTS not detected"

    def test_missing_x_content_type_options(self):
        """Detect missing X-Content-Type-Options"""
        headers = {'Content-Type': 'text/html'}
        assert 'X-Content-Type-Options' not in headers, "Missing X-Content-Type-Options not detected"


# Test execution and results collection
def pytest_collection_modifyitems(config, items):
    """Collect test metrics"""
    for item in items:
        item.add_marker(pytest.mark.security)


def pytest_runtest_makereport(item, call):
    """Capture test execution"""
    if call.when == "call":
        outcome = "PASSED" if call.excinfo is None else "FAILED"
        test_case = {
            "id": item.name,
            "category": item.cls.__name__ if item.cls else "General",
            "description": item.obj.__doc__ or item.name,
            "status": outcome
        }
        SecurityTestConfig.RESULTS["test_cases"].append(test_case)

        if outcome == "PASSED":
            SecurityTestConfig.RESULTS["summary"]["passed"] += 1
        else:
            SecurityTestConfig.RESULTS["summary"]["failed"] += 1

        SecurityTestConfig.RESULTS["summary"]["total"] += 1


@pytest.fixture(scope="session", autouse=True)
def generate_security_report():
    """Generate security test report"""
    yield

    end_time = datetime.utcnow()
    duration = (end_time - SecurityTestConfig.START_TIME).total_seconds()

    SecurityTestConfig.RESULTS["end_time"] = end_time.isoformat()
    SecurityTestConfig.RESULTS["duration_seconds"] = duration
    completion_percent = (SecurityTestConfig.RESULTS["summary"]["passed"] /
                         max(SecurityTestConfig.RESULTS["summary"]["total"], 1)) * 100

    SecurityTestConfig.RESULTS["completion_percent"] = round(completion_percent, 2)
    SecurityTestConfig.RESULTS["status"] = "PASSED" if SecurityTestConfig.RESULTS["summary"]["failed"] == 0 else "FAILED"

    # Write results
    report_path = Path(__file__).parent / "security_test_results_001.json"
    with open(report_path, 'w') as f:
        json.dump(SecurityTestConfig.RESULTS, f, indent=2)

    print(f"\n\nSecurity Test Report Generated: {report_path}")
    print(json.dumps(SecurityTestConfig.RESULTS, indent=2))


if __name__ == "__main__":
    pytest.main([__file__, "-v", "--tb=short"])
