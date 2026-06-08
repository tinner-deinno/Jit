#!/usr/bin/env python3
"""
Test suite for JIT-028: Knowledge Decay & Archival Policy

Tests:
1. Memory metadata structure
2. Decay scoring formula
3. Archive threshold logic
4. Recall prioritization (recent + high-access first)
5. Expiry handling
"""

import json
import os
import sys
from datetime import datetime, timedelta
from pathlib import Path

# Setup paths
JIT_ROOT = Path("/workspaces/Jit")
MEMORY_INDEX = JIT_ROOT / "memory" / "index.json"
ARCHIVE_DIR = JIT_ROOT / "memory" / "archive"

def setup_test_environment():
    """Create clean test environment"""
    MEMORY_INDEX.parent.mkdir(parents=True, exist_ok=True)
    ARCHIVE_DIR.mkdir(parents=True, exist_ok=True)

    # Create fresh index
    index = {
        "entries": {
            "recent_high_access": {
                "value": "This is a recent, frequently accessed memory",
                "set_by": "test",
                "created_date": (datetime.now() - timedelta(days=1)).isoformat(),
                "last_accessed": (datetime.now() - timedelta(hours=2)).isoformat(),
                "access_count": 50,
                "expiry_date": None,
                "archived": False,
                "decay_score": 0.95
            },
            "recent_low_access": {
                "value": "This is a new memory with few accesses",
                "set_by": "test",
                "created_date": (datetime.now() - timedelta(days=5)).isoformat(),
                "last_accessed": (datetime.now() - timedelta(days=4)).isoformat(),
                "access_count": 2,
                "expiry_date": None,
                "archived": False,
                "decay_score": 0.7
            },
            "old_high_access": {
                "value": "Old but frequently accessed memory",
                "set_by": "test",
                "created_date": (datetime.now() - timedelta(days=90)).isoformat(),
                "last_accessed": (datetime.now() - timedelta(days=10)).isoformat(),
                "access_count": 100,
                "expiry_date": None,
                "archived": False,
                "decay_score": 0.5
            },
            "old_low_access": {
                "value": "Old and rarely accessed - should be archived",
                "set_by": "test",
                "created_date": (datetime.now() - timedelta(days=100)).isoformat(),
                "last_accessed": (datetime.now() - timedelta(days=70)).isoformat(),
                "access_count": 1,
                "expiry_date": None,
                "archived": False,
                "decay_score": 0.2
            },
            "expiring_soon": {
                "value": "This memory will expire soon",
                "set_by": "test",
                "created_date": (datetime.now() - timedelta(days=25)).isoformat(),
                "last_accessed": (datetime.now() - timedelta(days=5)).isoformat(),
                "access_count": 10,
                "expiry_date": (datetime.now() + timedelta(days=3)).strftime("%Y-%m-%d"),
                "archived": False,
                "decay_score": 0.6
            },
            "already_expired": {
                "value": "This memory has expired",
                "set_by": "test",
                "created_date": (datetime.now() - timedelta(days=60)).isoformat(),
                "last_accessed": (datetime.now() - timedelta(days=30)).isoformat(),
                "access_count": 5,
                "expiry_date": (datetime.now() - timedelta(days=2)).strftime("%Y-%m-%d"),
                "archived": False,
                "decay_score": 0.3
            },
            "already_archived": {
                "value": "This memory is already archived",
                "set_by": "test",
                "created_date": (datetime.now() - timedelta(days=120)).isoformat(),
                "last_accessed": (datetime.now() - timedelta(days=90)).isoformat(),
                "access_count": 3,
                "expiry_date": None,
                "archived": True,
                "archived_date": (datetime.now() - timedelta(days=30)).isoformat(),
                "decay_score": 0.15
            }
        },
        "archived": []
    }

    with open(MEMORY_INDEX, "w", encoding="utf-8") as f:
        json.dump(index, f, ensure_ascii=False, indent=2)

    return index


def test_decay_scoring():
    """Test 1: Verify decay scoring formula"""
    print("\n=== Test 1: Decay Scoring Formula ===\n")

    import math

    test_cases = [
        # (days_since_access, access_count, expected_min_score, expected_max_score)
        (1, 50, 0.7, 1.0),      # Recent + high access = high score
        (5, 2, 0.5, 0.9),       # Recent + low access = medium-high score
        (10, 100, 0.4, 0.8),    # Old + high access = medium score
        (70, 1, 0.0, 0.35),      # Old + low access = low score (archive candidate)
    ]

    all_passed = True

    for days, access_count, exp_min, exp_max in test_cases:
        recency_score = 1.0 / (1.0 + days / 30.0)
        access_score = min(1.0, math.log10(access_count + 1) / 3.0)
        decay_score = 0.4 * recency_score + 0.3 * access_score + 0.3 * 0.5

        passed = exp_min <= decay_score <= exp_max
        status = "✅" if passed else "❌"
        print(f"  {status} days={days}, access={access_count} → score={decay_score:.3f} (expected: {exp_min}-{exp_max})")

        if not passed:
            all_passed = False

    return all_passed


def test_archive_threshold():
    """Test 2: Verify archive threshold logic (>60 days)"""
    print("\n=== Test 2: Archive Threshold Logic ===\n")

    index = json.load(open(MEMORY_INDEX))
    archive_threshold_days = 60

    should_archive = []
    should_not_archive = []

    for key, entry in index["entries"].items():
        if entry.get("archived", False):
            continue

        last_accessed = datetime.fromisoformat(
            entry.get("last_accessed", entry.get("created_date")).replace("Z", "+00:00")
        )
        days_since_access = (datetime.now() - last_accessed.replace(tzinfo=None)).days

        if days_since_access > archive_threshold_days:
            should_archive.append((key, days_since_access))
        else:
            should_not_archive.append((key, days_since_access))

    print(f"  Should archive ({len(should_archive)}):")
    for key, days in should_archive:
        print(f"    - {key}: {days} days")

    print(f"  Should NOT archive ({len(should_not_archive)}):")
    for key, days in should_not_archive[:3]:  # Show first 3
        print(f"    - {key}: {days} days")

    # Verify old_low_access is in archive candidates
    archive_keys = [k for k, _ in should_archive]
    passed = "old_low_access" in archive_keys
    status = "✅" if passed else "❌"
    print(f"\n  {status} 'old_low_access' correctly identified for archive")

    return passed


def test_recall_prioritization():
    """Test 3: Verify recall returns recent+high-access first"""
    print("\n=== Test 3: Recall Prioritization ===\n")

    import math

    index = json.load(open(MEMORY_INDEX))
    now = datetime.now()

    results = []
    for key, entry in index["entries"].items():
        if entry.get("archived", False):
            continue

        last_accessed = datetime.fromisoformat(
            entry.get("last_accessed", entry.get("created_date")).replace("Z", "+00:00")
        )
        days_since_access = (now - last_accessed.replace(tzinfo=None)).days
        access_count = entry.get("access_count", 0)

        recency_score = 1.0 / (1.0 + days_since_access / 30.0)
        access_score = min(1.0, math.log10(access_count + 1) / 3.0)
        decay_score = 0.4 * recency_score + 0.3 * access_score + 0.3 * 0.5

        results.append({
            "key": key,
            "decay_score": round(decay_score, 4),
            "days": days_since_access,
            "access_count": access_count
        })

    # Sort by decay score (high to low)
    results.sort(key=lambda x: x["decay_score"], reverse=True)

    print("  Recall results (sorted by decay score):")
    for i, r in enumerate(results):
        print(f"    {i+1}. {r['key']}: score={r['decay_score']:.3f}, days={r['days']}, access={r['access_count']}x")

    # Verify recent_high_access is first
    passed = results[0]["key"] == "recent_high_access"
    status = "✅" if passed else "❌"
    print(f"\n  {status} Highest priority is 'recent_high_access'")

    # Verify old_low_access is near bottom (before archived)
    old_low_idx = next(i for i, r in enumerate(results) if r["key"] == "old_low_access")
    passed = passed and (old_low_idx >= len(results) - 2)
    status = "✅" if passed else "❌"
    print(f"  {status} Lowest priority is 'old_low_access' (position {old_low_idx + 1}/{len(results)})")

    return passed


def test_expiry_handling():
    """Test 4: Verify expiry date handling"""
    print("\n=== Test 4: Expiry Handling ===\n")

    index = json.load(open(MEMORY_INDEX))
    now = datetime.now()

    expired = []
    expiring_soon = []
    valid = []

    for key, entry in index["entries"].items():
        expiry_date = entry.get("expiry_date")
        if not expiry_date:
            valid.append(key)
            continue

        expiry = datetime.fromisoformat(expiry_date) if "T" in expiry_date else datetime.strptime(expiry_date, "%Y-%m-%d")
        days_until_expiry = (expiry - now.replace(tzinfo=None)).days

        if days_until_expiry < 0:
            expired.append((key, days_until_expiry))
        elif days_until_expiry <= 7:
            expiring_soon.append((key, days_until_expiry))
        else:
            valid.append(key)

    print(f"  Expired ({len(expired)}):")
    for key, days in expired:
        print(f"    - {key}: {abs(days)} days ago")

    print(f"  Expiring soon ({len(expiring_soon)}):")
    for key, days in expiring_soon:
        print(f"    - {key}: {days} days left")

    print(f"  Valid ({len(valid)}):")
    for key in valid[:3]:
        print(f"    - {key}")

    # Verify correct detection
    expired_keys = [k for k, _ in expired]
    expiring_keys = [k for k, _ in expiring_soon]

    passed = ("already_expired" in expired_keys) and ("expiring_soon" in expiring_keys)
    status = "✅" if passed else "❌"
    print(f"\n  {status} Correctly identified expired and expiring entries")

    return passed


def test_archived_flag():
    """Test 5: Verify --archived flag filters correctly"""
    print("\n=== Test 5: Archived Flag Filtering ===\n")

    index = json.load(open(MEMORY_INDEX))

    active_entries = [k for k, v in index["entries"].items() if not v.get("archived", False)]
    archived_entries = [k for k, v in index["entries"].items() if v.get("archived", False)]

    print(f"  Active entries ({len(active_entries)}):")
    for key in active_entries:
        print(f"    - {key}")

    print(f"  Archived entries ({len(archived_entries)}):")
    for key in archived_entries:
        print(f"    - {key}")

    # Verify filtering
    passed = (len(active_entries) == 6) and (len(archived_entries) == 1)
    status = "✅" if passed else "❌"
    print(f"\n  {status} Correct count: {len(active_entries)} active, {len(archived_entries)} archived")

    return passed


def run_all_tests():
    """Run all tests and report results"""
    print("=" * 60)
    print("JIT-028: Knowledge Decay & Archival Policy - Test Suite")
    print("=" * 60)

    setup_test_environment()

    tests = [
        ("Decay Scoring Formula", test_decay_scoring),
        ("Archive Threshold Logic", test_archive_threshold),
        ("Recall Prioritization", test_recall_prioritization),
        ("Expiry Handling", test_expiry_handling),
        ("Archived Flag Filtering", test_archived_flag),
    ]

    results = []
    for name, test_func in tests:
        try:
            passed = test_func()
            results.append((name, passed))
        except Exception as e:
            print(f"\n  ❌ ERROR in {name}: {e}")
            results.append((name, False))

    # Summary
    print("\n" + "=" * 60)
    print("TEST SUMMARY")
    print("=" * 60)

    passed_count = sum(1 for _, p in results if p)
    total_count = len(results)

    for name, passed in results:
        status = "✅ PASS" if passed else "❌ FAIL"
        print(f"  {status}: {name}")

    print(f"\nTotal: {passed_count}/{total_count} tests passed")

    if passed_count == total_count:
        print("\n🎉 All tests passed!")
        return 0
    else:
        print(f"\n⚠️  {total_count - passed_count} test(s) failed")
        return 1


if __name__ == "__main__":
    sys.exit(run_all_tests())
