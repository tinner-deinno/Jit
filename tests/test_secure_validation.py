"""Test secure validation module (limbs/validate.sh)"""
import subprocess

def run_validation(validation_type, value):
    """Run validation via bash"""
    bash_script = f"""
source /workspaces/Jit/limbs/validate.sh
if validate {validation_type} {repr(value)}; then
  echo "VALID:$VALIDATION_RESULT"
else
  echo "INVALID:$VALIDATION_ERROR"
fi
"""
    result = subprocess.run(['bash'], input=bash_script, capture_output=True, text=True)
    return result.stdout.strip()

def test_email_validation():
    """Test email validation"""
    result = run_validation('email', 'user@example.com')
    assert 'VALID:user@example.com' in result, f"Valid email should pass, got: {result}"
    
    # Test with dangerous chars
    result = run_validation('email', 'user;drop@example.com')
    assert 'INVALID:' in result, f"Injection attempt should fail, got: {result}"

def test_alphanum_validation():
    """Test alphanumeric validation"""
    result = run_validation('alphanum', 'valid-name_123')
    assert 'VALID:valid-name_123' in result, f"Valid alphanum should pass, got: {result}"
    
    # Test injection
    result = run_validation('alphanum', 'invalid; rm -rf /')
    assert 'INVALID:' in result, f"Injection attempt should fail, got: {result}"

def test_agent_name_validation():
    """Test agent name validation"""
    result = run_validation('agent_name', 'jit')
    assert 'VALID:jit' in result, f"Valid agent name should pass, got: {result}"
    
    result = run_validation('agent_name', 'invalid;whoami')
    assert 'INVALID:' in result, f"Semicolon injection should fail, got: {result}"

def test_url_validation():
    """Test URL validation"""
    result = run_validation('url', 'https://example.com/safe')
    assert 'VALID:https://example.com/safe' in result, f"Valid URL should pass, got: {result}"
    
    # SSRF test
    result = run_validation('url', 'http://127.0.0.1:8080/')
    assert 'INVALID:' in result, f"Localhost SSRF should fail, got: {result}"

def test_filename_validation():
    """Test filename validation"""
    result = run_validation('filename', 'config.json')
    assert 'VALID:config.json' in result, f"Valid filename should pass, got: {result}"
    
    # Path traversal test
    result = run_validation('filename', '../../../etc/passwd')
    assert 'INVALID:' in result, f"Path traversal should fail, got: {result}"

if __name__ == '__main__':
    test_email_validation()
    print("✅ Email validation tests passed")
    
    test_alphanum_validation()
    print("✅ Alphanum validation tests passed")
    
    test_agent_name_validation()
    print("✅ Agent name validation tests passed")
    
    test_url_validation()
    print("✅ URL validation tests passed")
    
    test_filename_validation()
    print("✅ Filename validation tests passed")
    
    print("\n✅ All secure validation tests passed!")
