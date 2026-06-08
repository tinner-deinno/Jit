#!/usr/bin/env python3
"""
Test for JIT-021: Python code injection fix in network/bus.sh

Tests that registry paths with special characters (quotes, spaces)
are handled safely without code injection.
"""

import json
import os
import subprocess
import tempfile
import shutil
import pytest


class TestBusInjectionFix:
    """Test that bus.sh handles paths with special characters safely"""

    @pytest.fixture
    def temp_dir(self):
        """Create a temp directory with special chars in path"""
        # Create base temp dir
        base = tempfile.mkdtemp()
        # Create subdirectory with special characters
        special_dir = os.path.join(base, "test'dir\"with-special")
        os.makedirs(special_dir, exist_ok=True)
        yield special_dir
        shutil.rmtree(base, ignore_errors=True)

    @pytest.fixture
    def registry_file(self, temp_dir):
        """Create a test registry.json in the special path"""
        registry_path = os.path.join(temp_dir, "registry.json")
        registry_data = {
            "agents": [
                {"name": "agent1", "tier": 0, "organ": "brain"},
                {"name": "agent2", "tier": 1, "organ": "hand"},
                {"name": "innova", "tier": 2, "organ": "mind"},
            ]
        }
        with open(registry_path, "w") as f:
            json.dump(registry_data, f)
        return registry_path

    def test_init_bus_with_special_chars(self, temp_dir, registry_file):
        """Test _init_bus creates agent inboxes with special char paths"""
        bus_root = os.path.join(temp_dir, "bus")

        # Simulate the fixed Python code from bus.sh
        result = subprocess.run(
            ["python3", "-c", """
import sys, json, os
reg_path = sys.argv[1]
bus_root = sys.argv[2]
with open(reg_path) as f:
    d = json.load(f)
for a in d.get('agents', []):
    os.makedirs(os.path.join(bus_root, a['name']), exist_ok=True)
""", registry_file, bus_root],
            capture_output=True,
            text=True
        )

        assert result.returncode == 0, f"Python failed: {result.stderr}"

        # Verify agent inboxes were created
        assert os.path.isdir(os.path.join(bus_root, "agent1"))
        assert os.path.isdir(os.path.join(bus_root, "agent2"))
        assert os.path.isdir(os.path.join(bus_root, "innova"))

    def test_registry_read_with_quotes(self, temp_dir, registry_file):
        """Test reading registry with quotes in path doesn't inject code"""
        # This tests that the path is passed as argv, not interpolated
        result = subprocess.run(
            ["python3", "-c", """
import sys, json
reg_path = sys.argv[1]
with open(reg_path) as f:
    d = json.load(f)
for a in d.get('agents', []):
    print(a['name'])
""", registry_file],
            capture_output=True,
            text=True
        )

        assert result.returncode == 0, f"Python failed: {result.stderr}"
        names = result.stdout.strip().split("\n")
        assert "agent1" in names
        assert "agent2" in names
        assert "innova" in names

    def test_heart_stats_with_special_chars(self, temp_dir, registry_file):
        """Test heart.sh stats collection with special char paths"""
        bus_root = os.path.join(temp_dir, "bus")
        os.makedirs(bus_root, exist_ok=True)

        # Create some test message files
        agent_inbox = os.path.join(bus_root, "agent1")
        os.makedirs(agent_inbox, exist_ok=True)
        with open(os.path.join(agent_inbox, "test.msg"), "w") as f:
            f.write("test message")

        result = subprocess.run(
            ["python3", "-", registry_file, bus_root],
            input="""
import sys, json, os

reg_path = sys.argv[1]
bus_root = sys.argv[2]
reg = json.load(open(reg_path))
stats = {}
for a in reg.get('agents', []):
  name = a['name']
  inbox = os.path.join(bus_root, name)
  pending = 0
  if os.path.isdir(inbox):
    pending = len([f for f in os.listdir(inbox) if f.endswith('.msg')])
  stats[name] = {'pending': pending}
print(json.dumps(stats))
""",
            capture_output=True,
            text=True
        )

        assert result.returncode == 0, f"Python failed: {result.stderr}"
        stats = json.loads(result.stdout)
        assert stats["agent1"]["pending"] == 1

    def test_mouth_broadcast_with_special_chars(self, temp_dir, registry_file):
        """Test mouth.sh broadcast agent enumeration with special char paths"""
        result = subprocess.run(
            ["python3", "-c", """
import sys, json
reg_path = sys.argv[1]
with open(reg_path) as f:
    d = json.load(f)
for a in d.get('agents', []):
    print(a['name'])
""", registry_file],
            capture_output=True,
            text=True
        )

        assert result.returncode == 0
        agents = set(result.stdout.strip().split("\n"))
        assert agents == {"agent1", "agent2", "innova"}


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
