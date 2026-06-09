"""
Pytest configuration and shared fixtures for Jit (จิต) multi-agent system tests.

Provides:
- tmp_bus_dir: Temporary bus directory for isolation
- mock_oracle: Mock Oracle API responses
- agent_inbox_setup: Initialize agent inboxes for tests
"""
import pytest
import tempfile
import shutil
import os
import json


@pytest.fixture(scope="session")
def tmp_bus_dir():
    """Create temporary bus directory for tests.

    Provides an isolated /tmp directory to simulate the message bus
    without interfering with real agent communication.

    Yields:
        str: Path to temporary bus directory
    """
    bus_dir = tempfile.mkdtemp(prefix="jit-bus-test-")
    yield bus_dir
    shutil.rmtree(bus_dir, ignore_errors=True)


@pytest.fixture
def mock_oracle(monkeypatch):
    """Mock Oracle API responses for limbs/oracle.sh tests.

    Patches the oracle search function to return empty results
    by default, preventing external API calls during tests.

    Args:
        monkeypatch: pytest monkeypatch fixture

    Yields:
        callable: Mock function that can be configured per-test
    """
    def mock_search(*args, **kwargs):
        return {"results": [], "status": "ok"}

    def mock_learn(*args, **kwargs):
        return {"status": "ok", "id": "mock-learning-id"}

    # Patch both search and learn functions
    monkeypatch.setattr("limbs.oracle.search", mock_search, raising=False)
    monkeypatch.setattr("limbs.oracle.learn", mock_learn, raising=False)
    yield mock_search


@pytest.fixture
def agent_inbox_setup(tmp_bus_dir):
    """Initialize agent inboxes for tests.

    Creates inbox directories for all 14 agents in the multi-agent system.

    Args:
        tmp_bus_dir: Temporary bus directory fixture

    Yields:
        str: Path to initialized bus directory with agent inboxes
    """
    # All 14 agents from network/registry.json
    agents = [
        "jit", "soma", "innova", "lak", "neta",      # Tier 0-2
        "vaja", "chamu", "rupa", "pada",             # Tier 3 specialists
        "netra", "karn", "mue", "pran", "sayanprasathan"  # Tier 3 organs
    ]

    for agent in agents:
        inbox_path = os.path.join(tmp_bus_dir, agent)
        os.makedirs(inbox_path, exist_ok=True)

    yield tmp_bus_dir


@pytest.fixture
def mock_message(tmp_bus_dir):
    """Create a test message in the bus format.

    Args:
        tmp_bus_dir: Temporary bus directory fixture

    Yields:
        callable: Function that creates messages for testing
    """
    created_messages = []

    def _create_message(to_agent, subject, body, from_agent="test"):
        """Create a message file in the bus format."""
        import time
        inbox_path = os.path.join(tmp_bus_dir, to_agent)
        os.makedirs(inbox_path, exist_ok=True)

        timestamp = int(time.time() * 1000)
        msg_id = f"msg-{timestamp}-{to_agent}"

        message = {
            "id": msg_id,
            "from": from_agent,
            "to": to_agent,
            "subject": subject,
            "body": body,
            "timestamp": timestamp,
            "ttl": 3600
        }

        msg_path = os.path.join(inbox_path, f"{msg_id}.json")
        with open(msg_path, "w") as f:
            json.dump(message, f, indent=2)

        created_messages.append(msg_path)
        return msg_path

    yield _create_message

    # Cleanup created messages
    for msg_path in created_messages:
        try:
            os.remove(msg_path)
        except OSError:
            pass


@pytest.fixture
def sample_config():
    """Provide sample configuration data for testing.

    Returns common configuration structures used across tests.

    Yields:
        dict: Sample configuration data
    """
    return {
        "bus_base_dir": "/tmp/manusat-bus",
        "oracle_url": "http://localhost:47778",
        "default_ttl": 3600,
        "max_retries": 3,
        "retry_delay": 1.0,
        "agents": ["jit", "soma", "innova", "lak", "neta", "vaja", "chamu"]
    }


@pytest.fixture(autouse=True)
def reset_env():
    """Reset environment variables before each test.

    Ensures tests don't leak environment state between runs.
    """
    original_env = os.environ.copy()
    yield
    os.environ.clear()
    os.environ.update(original_env)
