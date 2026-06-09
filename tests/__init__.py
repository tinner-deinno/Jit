"""
Jit Test Suite Configuration and Runner
Controls all test execution across the system
"""

import unittest
import sys
import os

# Add repo root to path
REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, REPO_ROOT)

# ═══════════════════════════════════════════════════════════════
# Test Configuration
# ═══════════════════════════════════════════════════════════════

TEST_CONFIG = {
    # Which test suites to run
    "suites": {
        "unit": {
            "description": "Unit tests for Jit components",
            "tests": [
                "test_jit_orchestration",
                "test_jit_hermes_sync",
                "test_jit_integrations"
            ]
        },
        "integration": {
            "description": "Integration tests (require external services)",
            "tests": [
                "test_jit_integrations"
            ]
        },
        "all": {
            "description": "All tests",
            "tests": [
                "test_jit_orchestration",
                "test_jit_hermes_sync",
                "test_jit_integrations",
                "test_heartbeat",
                "test_karn_voice"
            ]
        }
    },
    
    # Test execution parameters
    "execution": {
        "verbosity": 2,
        "fail_fast": False,
        "tb_format": "short"  # short, long, native
    },
    
    # What to verify
    "checks": {
        "correctness": True,  # All functions work correctly
        "integration": True,  # Services integrate properly
        "performance": True,  # Performance targets met
        "reliability": True   # Recovery mechanisms work
    },
    
    # External service endpoints
    "services": {
        "oracle": "http://localhost:47778",
        "ollama": "https://ollama.mdes-innova.online",
        "discord_bot": "hermes-discord (systemd)",
        "heartbeat": "jit-heartbeat (systemd)"
    }
}


# ═══════════════════════════════════════════════════════════════
# Test Loader
# ═══════════════════════════════════════════════════════════════

class JitTestLoader:
    """Loads and organizes Jit tests"""
    
    @staticmethod
    def load_suite(suite_name="unit"):
        """Load a test suite"""
        suite = unittest.TestSuite()
        test_names = TEST_CONFIG["suites"].get(suite_name, {}).get("tests", [])
        
        loader = unittest.TestLoader()
        for test_name in test_names:
            try:
                module = __import__(f"tests.{test_name}", fromlist=[test_name])
                tests = loader.loadTestsFromModule(module)
                suite.addTests(tests)
            except ImportError:
                print(f"⚠️  Could not import {test_name}")
        
        return suite
    
    @staticmethod
    def load_all():
        """Load all tests"""
        suite = unittest.TestSuite()
        loader = unittest.TestLoader()
        
        tests_dir = os.path.join(REPO_ROOT, "tests")
        for filename in os.listdir(tests_dir):
            if filename.startswith("test_jit_") and filename.endswith(".py"):
                module_name = filename[:-3]
                try:
                    module = __import__(f"tests.{module_name}", fromlist=[module_name])
                    tests = loader.loadTestsFromModule(module)
                    suite.addTests(tests)
                except ImportError as e:
                    print(f"⚠️  Could not import {module_name}: {e}")
        
        return suite


# ═══════════════════════════════════════════════════════════════
# Test Runner
# ═══════════════════════════════════════════════════════════════

class JitTestRunner:
    """Runs tests with reporting"""
    
    def __init__(self, config=None):
        self.config = config or TEST_CONFIG
        self.results = {
            "passed": 0,
            "failed": 0,
            "skipped": 0,
            "errors": 0
        }
    
    def run_suite(self, suite_name="unit"):
        """Run a test suite"""
        print(f"🧪 Running {suite_name} tests...")
        print(f"   {self.config['suites'][suite_name]['description']}")
        print()
        
        suite = JitTestLoader.load_suite(suite_name)
        runner = unittest.TextTestRunner(
            verbosity=self.config["execution"]["verbosity"],
            failfast=self.config["execution"]["fail_fast"]
        )
        
        result = runner.run(suite)
        self._collect_results(result)
        return result
    
    def run_all(self):
        """Run all tests"""
        print("🧪 Running full Jit test suite...")
        print()
        
        suite = JitTestLoader.load_all()
        runner = unittest.TextTestRunner(
            verbosity=self.config["execution"]["verbosity"],
            failfast=self.config["execution"]["fail_fast"]
        )
        
        result = runner.run(suite)
        self._collect_results(result)
        return result
    
    def _collect_results(self, result):
        """Collect test results"""
        self.results["passed"] = result.testsRun - len(result.failures) - len(result.errors)
        self.results["failed"] = len(result.failures)
        self.results["errors"] = len(result.errors)
        self.results["skipped"] = len(result.skipped)
    
    def print_summary(self):
        """Print test summary"""
        total = sum(self.results.values())
        print()
        print("=" * 60)
        print("📊 TEST SUMMARY")
        print("=" * 60)
        print(f"  ✅ Passed:  {self.results['passed']:3d}")
        print(f"  ❌ Failed:  {self.results['failed']:3d}")
        print(f"  ⚠️  Errors:  {self.results['errors']:3d}")
        print(f"  ⏭️  Skipped: {self.results['skipped']:3d}")
        print(f"  📋 Total:   {total:3d}")
        print("=" * 60)
        
        if self.results["failed"] == 0 and self.results["errors"] == 0:
            print("✅ ALL TESTS PASSED")
            return 0
        else:
            print("❌ SOME TESTS FAILED")
            return 1


# ═══════════════════════════════════════════════════════════════
# CLI
# ═══════════════════════════════════════════════════════════════

def main():
    """Main test runner"""
    import argparse
    
    parser = argparse.ArgumentParser(
        description="Jit Test Suite Runner"
    )
    parser.add_argument(
        "suite",
        nargs="?",
        default="unit",
        choices=["unit", "integration", "all"],
        help="Which test suite to run"
    )
    parser.add_argument(
        "-v", "--verbose",
        action="store_true",
        help="Verbose output"
    )
    parser.add_argument(
        "-s", "--stop-on-first-failure",
        action="store_true",
        help="Stop on first failure"
    )
    
    args = parser.parse_args()
    
    # Update config based on CLI args
    config = TEST_CONFIG.copy()
    if args.verbose:
        config["execution"]["verbosity"] = 3
    if args.stop_on_first_failure:
        config["execution"]["fail_fast"] = True
    
    # Run tests
    runner = JitTestRunner(config)
    
    if args.suite == "all":
        runner.run_all()
    else:
        runner.run_suite(args.suite)
    
    runner.print_summary()
    return runner.results["failed"] + runner.results["errors"]


if __name__ == "__main__":
    sys.exit(main())
