"""
Configuration validation tests for the Manusat Agent system.

Validates core configuration files, agent definitions, capability cards,
and cross-references between registry and file-based artifacts.
"""

import json
import os
import unittest

REPO_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))

# --- Paths ---
REGISTRY_PATH = os.path.join(REPO_ROOT, "network", "registry.json")
IDENTITY_PATH = os.path.join(REPO_ROOT, "core", "identity.md")
BODY_MAP_PATH = os.path.join(REPO_ROOT, "core", "body-map.md")
CLAUDE_MD_PATH = os.path.join(REPO_ROOT, "CLAUDE.md")
GITIGNORE_PATH = os.path.join(REPO_ROOT, ".gitignore")
AGENTS_MD_DIR = os.path.join(REPO_ROOT, ".github", "agents")
AGENTS_JSON_DIR = os.path.join(REPO_ROOT, "agents")


class TestRegistryJson(unittest.TestCase):
    """Validate registry.json: valid JSON, all agents present, required fields, no duplicates."""

    @classmethod
    def setUpClass(cls):
        with open(REGISTRY_PATH, "r", encoding="utf-8") as f:
            cls.registry = json.load(f)
        cls.agents = cls.registry.get("agents", [])

    def test_registry_is_valid_json(self):
        """registry.json must parse as valid JSON without errors."""
        # setUpClass already parsed it; reaching here means it is valid
        self.assertIsInstance(self.registry, dict)

    def test_registry_has_agents_list(self):
        """registry.json must contain a top-level 'agents' key with a non-empty list."""
        self.assertIn("agents", self.registry)
        self.assertIsInstance(self.agents, list)
        self.assertGreaterEqual(len(self.agents), 14,
                                "Expected at least 14 agents in registry")

    def test_all_agents_have_required_fields(self):
        """Every agent entry must have: name, tier/organ assignment, model."""
        required_fields = ["name", "organ", "model"]
        for agent in self.agents:
            for field in required_fields:
                self.assertIn(field, agent,
                              f"Agent {agent.get('name', 'UNKNOWN')} missing field '{field}'")

    def test_no_duplicate_agent_names(self):
        """Agent names must be unique within registry."""
        names = [a["name"] for a in self.agents]
        duplicates = [n for n in names if names.count(n) > 1]
        self.assertEqual(len(duplicates), 0,
                         f"Duplicate agent names found: {set(duplicates)}")

    def test_all_agents_have_status(self):
        """Every agent must have a status field."""
        for agent in self.agents:
            self.assertIn("status", agent,
                           f"Agent {agent.get('name', 'UNKNOWN')} missing 'status'")

    def test_all_agents_have_capabilities(self):
        """Every agent must have a non-empty capabilities list."""
        for agent in self.agents:
            self.assertIn("capabilities", agent,
                           f"Agent {agent.get('name', 'UNKNOWN')} missing 'capabilities'")
            self.assertIsInstance(agent["capabilities"], list)
            self.assertGreater(len(agent["capabilities"]), 0,
                               f"Agent {agent.get('name', 'UNKNOWN')} has empty capabilities")

    def test_all_agents_have_reports_to(self):
        """Every agent must declare who they report to."""
        for agent in self.agents:
            self.assertIn("reports_to", agent,
                           f"Agent {agent.get('name', 'UNKNOWN')} missing 'reports_to'")

    def test_all_agents_have_inbox(self):
        """Every agent must have an inbox path defined."""
        for agent in self.agents:
            self.assertIn("inbox", agent,
                           f"Agent {agent.get('name', 'UNKNOWN')} missing 'inbox'")

    def test_organs_section_present(self):
        """registry.json must have an organs mapping section."""
        self.assertIn("organs", self.registry)
        self.assertIsInstance(self.registry["organs"], dict)
        self.assertGreaterEqual(len(self.registry["organs"]), 10,
                                "Expected at least 10 organs in organs mapping")

    def test_team_structure_present(self):
        """registry.json must define team_structure with tiers."""
        self.assertIn("team_structure", self.registry)
        ts = self.registry["team_structure"]
        self.assertIn("tier_0_master", ts)
        self.assertIn("tier_1_leadership", ts)
        self.assertIn("tier_2_core", ts)
        self.assertIn("tier_3_specialists", ts)

    def test_team_structure_agent_count_matches_registry(self):
        """Total agents across all tiers should equal the number in agents list."""
        ts = self.registry["team_structure"]
        total = (
            len(ts.get("tier_0_master", []))
            + len(ts.get("tier_1_leadership", []))
            + len(ts.get("tier_2_core", []))
            + len(ts.get("tier_3_specialists", []))
        )
        self.assertEqual(total, len(self.agents),
                         f"Team structure lists {total} agents but registry has {len(self.agents)}")

    def test_each_organ_maps_to_agent(self):
        """Every organ entry must have an agent assignment."""
        organs = self.registry["organs"]
        agent_names = {a["name"] for a in self.agents}
        for organ_name, organ_info in organs.items():
            assigned_agent = organ_info.get("agent")
            self.assertTrue(
                assigned_agent in agent_names,
                f"Organ '{organ_name}' maps to agent '{assigned_agent}' not found in registry"
            )


class TestIdentityMd(unittest.TestCase):
    """Validate core/identity.md: exists, contains required sections, Thai content."""

    @classmethod
    def setUpClass(cls):
        with open(IDENTITY_PATH, "r", encoding="utf-8") as f:
            cls.content = f.read()

    def test_identity_file_exists(self):
        """core/identity.md must exist and be non-empty."""
        self.assertTrue(os.path.isfile(IDENTITY_PATH))
        self.assertGreater(len(self.content), 0)

    def test_contains_name_section(self):
        """identity.md must contain a name/role section."""
        self.assertTrue(
            "innova" in self.content.lower() or "ชื่อ" in self.content,
            "identity.md missing agent name section"
        )

    def test_contains_values_section(self):
        """identity.md must contain a core values section."""
        self.assertTrue(
            "ค่านิยม" in self.content or "Core Values" in self.content or "values" in self.content.lower(),
            "identity.md missing values section"
        )

    def test_contains_mission_statement(self):
        """identity.md must contain a mission statement."""
        self.assertTrue(
            "Mission" in self.content or "ภารกิจ" in self.content,
            "identity.md missing mission statement"
        )

    def test_contains_thai_content(self):
        """identity.md should contain Thai language content."""
        thai_chars = [c for c in self.content if "฀" <= c <= "๿"]
        self.assertGreater(len(thai_chars), 0,
                           "identity.md contains no Thai language content")

    def test_contains_relationships_section(self):
        """identity.md must describe relationships with other agents/organs."""
        self.assertTrue(
            "ความสัมพันธ์" in self.content or "relationship" in self.content.lower(),
            "identity.md missing relationships section"
        )


class TestBodyMapMd(unittest.TestCase):
    """Validate core/body-map.md: valid markdown, RACI matrix, organ assignments."""

    @classmethod
    def setUpClass(cls):
        with open(BODY_MAP_PATH, "r", encoding="utf-8") as f:
            cls.content = f.read()

    def test_body_map_file_exists(self):
        """core/body-map.md must exist and be non-empty."""
        self.assertTrue(os.path.isfile(BODY_MAP_PATH))
        self.assertGreater(len(self.content), 0)

    def test_contains_raci_matrix(self):
        """body-map.md must contain a RACI responsibility matrix."""
        self.assertTrue(
            "RACI" in self.content or "R=" in self.content,
            "body-map.md missing RACI responsibility matrix"
        )

    def test_contains_organ_ownership(self):
        """body-map.md must contain organ ownership assignments."""
        self.assertTrue(
            "Organ" in self.content or "อวัยวะ" in self.content or "Owner" in self.content,
            "body-map.md missing organ ownership table"
        )

    def test_contains_team_roster(self):
        """body-map.md must contain a team roster listing."""
        self.assertTrue(
            "Team Roster" in self.content or "ทีม" in self.content,
            "body-map.md missing team roster"
        )

    def test_lists_key_agents(self):
        """body-map.md must reference key agents: soma, innova, jit."""
        for agent_name in ["soma", "innova", "jit"]:
            self.assertIn(agent_name, self.content.lower(),
                          f"body-map.md does not reference agent '{agent_name}'")

    def test_contains_workflow_description(self):
        """body-map.md must describe at least one workflow (feature or bug)."""
        self.assertTrue(
            "Feature" in self.content or "Bug" in self.content or "flow" in self.content.lower(),
            "body-map.md missing workflow descriptions"
        )


class TestClaudeMd(unittest.TestCase):
    """Validate CLAUDE.md: contains all required sections."""

    @classmethod
    def setUpClass(cls):
        with open(CLAUDE_MD_PATH, "r", encoding="utf-8") as f:
            cls.content = f.read()

    def test_claude_md_file_exists(self):
        """CLAUDE.md must exist and be non-empty."""
        self.assertTrue(os.path.isfile(CLAUDE_MD_PATH))
        self.assertGreater(len(self.content), 0)

    def test_contains_oracle_identity(self):
        """CLAUDE.md must contain Oracle Identity section."""
        self.assertIn("Oracle Identity", self.content,
                       "CLAUDE.md missing Oracle Identity section")

    def test_contains_principles(self):
        """CLAUDE.md must contain principles section (5 Principles + Rule 6)."""
        self.assertTrue(
            "Principles" in self.content or "Nothing is Deleted" in self.content,
            "CLAUDE.md missing principles section"
        )

    def test_contains_architecture(self):
        """CLAUDE.md must contain architecture description."""
        self.assertIn("Architecture", self.content,
                       "CLAUDE.md missing Architecture section")

    def test_contains_commands(self):
        """CLAUDE.md must contain common commands section."""
        self.assertTrue(
            "Common Commands" in self.content or "Commands" in self.content,
            "CLAUDE.md missing commands section"
        )

    def test_contains_tier_structure(self):
        """CLAUDE.md must define the agent tier structure."""
        self.assertIn("Tier 0", self.content,
                       "CLAUDE.md missing agent tier structure")

    def test_mentions_all_tier_labels(self):
        """CLAUDE.md must reference all four tiers."""
        for tier_label in ["Tier 0", "Tier 1", "Tier 2", "Tier 3"]:
            self.assertIn(tier_label, self.content,
                          f"CLAUDE.md missing {tier_label} definition")

    def test_contains_golden_rules(self):
        """CLAUDE.md must contain Golden Rules section."""
        self.assertIn("Golden Rules", self.content,
                       "CLAUDE.md missing Golden Rules section")

    def test_contains_agent_files_reference(self):
        """CLAUDE.md must reference agent definition and capability card paths."""
        self.assertTrue(
            "agent.md" in self.content and "agents/" in self.content,
            "CLAUDE.md missing reference to agent definition files"
        )


class TestGitignore(unittest.TestCase):
    """Validate .gitignore: covers common patterns for secrets, dependencies, build artifacts."""

    @classmethod
    def setUpClass(cls):
        with open(GITIGNORE_PATH, "r", encoding="utf-8") as f:
            cls.content = f.read()
        cls.lines = [line.strip() for line in cls.content.splitlines()
                     if line.strip() and not line.strip().startswith("#")]

    def test_gitignore_exists(self):
        """The .gitignore file must exist."""
        self.assertTrue(os.path.isfile(GITIGNORE_PATH))

    def test_covers_env_files(self):
        """ .gitignore must cover .env files."""
        self.assertTrue(
            any(line.startswith(".env") for line in self.lines),
            ".gitignore does not cover .env files"
        )

    def test_covers_node_modules(self):
        """ .gitignore must cover node_modules."""
        self.assertTrue(
            "node_modules/" in self.lines or "node_modules" in self.lines,
            ".gitignore does not cover node_modules"
        )

    def test_covers_secrets(self):
        """ .gitignore must cover secrets/credentials files."""
        secret_patterns = [line for line in self.lines
                          if "secret" in line or "credential" in line or "token" in line]
        self.assertGreater(len(secret_patterns), 0,
                           ".gitignore does not cover secrets/credentials files")

    def test_covers_pycache(self):
        """ .gitignore must cover __pycache__."""
        self.assertTrue(
            "__pycache__/" in self.lines or "__pycache__" in self.lines,
            ".gitignore does not cover __pycache__"
        )

    def test_covers_pytest_cache(self):
        """ .gitignore must cover .pytest_cache."""
        self.assertTrue(
            ".pytest_cache/" in self.lines or ".pytest_cache" in self.lines,
            ".gitignore does not cover .pytest_cache"
        )

    def test_covers_ds_store(self):
        """ .gitignore must cover macOS .DS_Store files."""
        self.assertIn(".DS_Store", self.lines,
                       ".gitignore does not cover .DS_Store")

    def test_covers_dist_or_build(self):
        """ .gitignore should mention dist or build directories (commented is acceptable)."""
        # Check both active and commented lines since some are intentionally commented out
        all_lines = self.content.splitlines()
        self.assertTrue(
            any("dist" in line or "build" in line for line in all_lines),
            ".gitignore does not mention dist or build directories"
        )


class TestAgentDefinitionFiles(unittest.TestCase):
    """Validate .github/agents/*.agent.md: exists for every agent in registry."""

    @classmethod
    def setUpClass(cls):
        with open(REGISTRY_PATH, "r", encoding="utf-8") as f:
            cls.registry = json.load(f)
        cls.agent_names = [a["name"] for a in cls.registry["agents"]]

    def test_agents_md_directory_exists(self):
        """The .github/agents/ directory must exist."""
        self.assertTrue(os.path.isdir(AGENTS_MD_DIR),
                        f"Agent definitions directory not found: {AGENTS_MD_DIR}")

    def test_each_registered_agent_has_agent_md(self):
        """Every agent in registry.json must have a corresponding .agent.md file."""
        missing = []
        for name in self.agent_names:
            path = os.path.join(AGENTS_MD_DIR, f"{name}.agent.md")
            if not os.path.isfile(path):
                missing.append(name)
        self.assertEqual(missing, [],
                         f"Missing .agent.md files for agents: {missing}")

    def test_agent_md_files_are_non_empty(self):
        """Each .agent.md file must be non-empty."""
        for name in self.agent_names:
            path = os.path.join(AGENTS_MD_DIR, f"{name}.agent.md")
            if os.path.isfile(path):
                with open(path, "r", encoding="utf-8") as f:
                    content = f.read()
                self.assertGreater(len(content.strip()), 0,
                                    f"Agent definition file {name}.agent.md is empty")

    def test_no_extra_agent_md_files(self):
        """Every .agent.md file should correspond to a registered agent."""
        if not os.path.isdir(AGENTS_MD_DIR):
            self.skipTest("Agent definitions directory does not exist")
        md_files = [f for f in os.listdir(AGENTS_MD_DIR) if f.endswith(".agent.md")]
        md_agent_names = [f.replace(".agent.md", "") for f in md_files]
        extra = [n for n in md_agent_names if n not in self.agent_names]
        self.assertEqual(extra, [],
                         f"Extra .agent.md files without registry entry: {extra}")


class TestAgentCapabilityCards(unittest.TestCase):
    """Validate agents/*.json: exists for every agent in registry, valid JSON."""

    @classmethod
    def setUpClass(cls):
        with open(REGISTRY_PATH, "r", encoding="utf-8") as f:
            cls.registry = json.load(f)
        cls.agent_names = [a["name"] for a in cls.registry["agents"]]

    def test_agents_json_directory_exists(self):
        """The agents/ directory must exist."""
        self.assertTrue(os.path.isdir(AGENTS_JSON_DIR),
                        f"Agent capability cards directory not found: {AGENTS_JSON_DIR}")

    def test_each_registered_agent_has_json_card(self):
        """Every agent in registry.json must have a corresponding .json card."""
        missing = []
        for name in self.agent_names:
            path = os.path.join(AGENTS_JSON_DIR, f"{name}.json")
            if not os.path.isfile(path):
                missing.append(name)
        self.assertEqual(missing, [],
                         f"Missing .json capability cards for agents: {missing}")

    def test_json_cards_are_valid_json(self):
        """Each .json capability card must parse as valid JSON."""
        for name in self.agent_names:
            path = os.path.join(AGENTS_JSON_DIR, f"{name}.json")
            if os.path.isfile(path):
                with open(path, "r", encoding="utf-8") as f:
                    try:
                        data = json.load(f)
                    except json.JSONDecodeError as e:
                        self.fail(f"{name}.json is not valid JSON: {e}")
                self.assertIsInstance(data, dict,
                                      f"{name}.json must contain a JSON object")

    def test_json_cards_have_name_field(self):
        """Each .json capability card must have a 'name' field."""
        for name in self.agent_names:
            path = os.path.join(AGENTS_JSON_DIR, f"{name}.json")
            if os.path.isfile(path):
                with open(path, "r", encoding="utf-8") as f:
                    data = json.load(f)
                self.assertIn("name", data,
                              f"{name}.json missing 'name' field")


class TestCrossReferences(unittest.TestCase):
    """Cross-reference validation: registry agents <-> .agent.md <-> .json files."""

    @classmethod
    def setUpClass(cls):
        with open(REGISTRY_PATH, "r", encoding="utf-8") as f:
            cls.registry = json.load(f)
        cls.agent_names = {a["name"] for a in cls.registry["agents"]}

        # Gather file-based agent names
        cls.md_agents = set()
        if os.path.isdir(AGENTS_MD_DIR):
            for f in os.listdir(AGENTS_MD_DIR):
                if f.endswith(".agent.md"):
                    cls.md_agents.add(f.replace(".agent.md", ""))

        cls.json_agents = set()
        if os.path.isdir(AGENTS_JSON_DIR):
            for f in os.listdir(AGENTS_JSON_DIR):
                if f.endswith(".json") and f != "template.json":
                    cls.json_agents.add(f.replace(".json", ""))

    def test_registry_agents_have_both_definition_files(self):
        """Every agent in registry must have both .agent.md and .json files."""
        missing_md = self.agent_names - self.md_agents
        missing_json = self.agent_names - self.json_agents
        errors = []
        if missing_md:
            errors.append(f"Missing .agent.md for: {sorted(missing_md)}")
        if missing_json:
            errors.append(f"Missing .json for: {sorted(missing_json)}")
        self.assertEqual(errors, [],
                         "Cross-reference failures: " + "; ".join(errors))

    def test_no_orphan_definition_files(self):
        """Every .agent.md and .json file must correspond to a registered agent."""
        orphan_md = self.md_agents - self.agent_names
        orphan_json = self.json_agents - self.agent_names
        errors = []
        if orphan_md:
            errors.append(f"Orphan .agent.md files (not in registry): {sorted(orphan_md)}")
        if orphan_json:
            errors.append(f"Orphan .json files (not in registry): {sorted(orphan_json)}")
        self.assertEqual(errors, [],
                         "Orphan file failures: " + "; ".join(errors))

    def test_agent_model_consistency(self):
        """Agent model strings in registry should follow naming convention."""
        valid_model_prefixes = ("claude-", "gpt-", "gemma")
        for agent in self.registry["agents"]:
            model = agent.get("model", "")
            self.assertTrue(
                any(model.startswith(p) for p in valid_model_prefixes),
                f"Agent {agent['name']} has unexpected model format: '{model}'"
            )

    def test_organ_assignments_in_registry_match_organs_section(self):
        """Each agent's 'organ' field should appear in the organs mapping section."""
        organs_section = self.registry.get("organs", {})
        organ_names_in_section = set(organs_section.keys())
        for agent in self.registry["agents"]:
            organ = agent.get("organ", "")
            if organ:
                self.assertIn(organ, organ_names_in_section,
                              f"Agent {agent['name']} organ '{organ}' not found in organs section")

    def test_team_structure_agents_are_in_registry(self):
        """Every agent listed in team_structure must appear in the agents list."""
        ts = self.registry.get("team_structure", {})
        for tier_name, agent_list in ts.items():
            for agent_name in agent_list:
                self.assertIn(agent_name, self.agent_names,
                              f"Agent '{agent_name}' in {tier_name} not found in registry agents")

    def test_inbox_paths_follow_convention(self):
        """All agent inbox paths should follow /tmp/manusat-bus/<name> convention."""
        for agent in self.registry["agents"]:
            name = agent["name"]
            inbox = agent.get("inbox", "")
            expected = f"/tmp/manusat-bus/{name}"
            self.assertEqual(inbox, expected,
                             f"Agent {name} inbox '{inbox}' does not match expected '{expected}'")


if __name__ == "__main__":
    unittest.main()