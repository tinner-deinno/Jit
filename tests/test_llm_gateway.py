"""
test_llm_gateway.py — Tests for the unified multi-provider LLM gateway
 chamu (QA/Tester) — Trust nothing, test everything

Covers limbs/llm.sh + limbs/providers/*.sh + config/providers.json:
  1. Static integrity  — scripts parse, JSON valid, every agent routable
  2. Resolution        — per-agent provider/model, provider/model strings, prefix inference
  3. Fallback chains   — ordering, cross-provider failover candidates
  4. Availability      — ready/not-ready flags (claude ready, openai keyless → not ready)
  5. Regression        — empty-field TSV delimiter bug (column shift) stays fixed
  6. Concurrency lock  — jit_with_lock serializes same-name, parallelizes different-name
  7. Live (gated)      — real calls when JIT_LIVE_TESTS=1 (claude + ollama + clean stdout)

Live tests are skipped unless JIT_LIVE_TESTS=1 to keep the suite deterministic/offline.
"""

import json
import os
import subprocess
import time
import unittest

PROJECT_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
LIMBS_DIR = os.path.join(PROJECT_ROOT, 'limbs')
LLM = os.path.join(LIMBS_DIR, 'llm.sh')
LIB = os.path.join(LIMBS_DIR, 'lib.sh')
PROVIDERS_JSON = os.path.join(PROJECT_ROOT, 'config', 'providers.json')
PROVIDERS_DIR = os.path.join(LIMBS_DIR, 'providers')

LIVE = os.environ.get('JIT_LIVE_TESTS') == '1'
ALL_AGENTS = ['jit', 'soma', 'innova', 'lak', 'neta', 'vaja', 'chamu', 'rupa',
              'pada', 'netra', 'karn', 'mue', 'pran', 'lung', 'sayanprasathan']


def run_llm(args, timeout=120):
    """Run llm.sh with args. Returns CompletedProcess (text mode)."""
    env = {**os.environ, 'JIT_LOG': '/tmp/test-llm-gateway.log',
           'JIT_LOCK_DIR': '/tmp/test-manusat-locks'}
    return subprocess.run(['bash', LLM] + args, stdout=subprocess.PIPE,
                          stderr=subprocess.PIPE, text=True, env=env, timeout=timeout)


class StaticIntegrity(unittest.TestCase):
    def test_scripts_parse(self):
        scripts = [LLM, LIB, os.path.join(LIMBS_DIR, 'prompt_proxy.sh')]
        scripts += [os.path.join(PROVIDERS_DIR, f) for f in os.listdir(PROVIDERS_DIR)
                    if f.endswith('.sh')]
        for s in scripts:
            r = subprocess.run(['bash', '-n', s], stderr=subprocess.PIPE, text=True)
            self.assertEqual(r.returncode, 0, f'syntax error in {s}: {r.stderr}')

    def test_providers_json_valid(self):
        with open(PROVIDERS_JSON) as f:
            cfg = json.load(f)
        self.assertIn('providers', cfg)
        self.assertIn('agents', cfg)
        self.assertIn('default_agent', cfg)
        # every provider declares an adapter file that exists
        for name, block in cfg['providers'].items():
            adapter = os.path.join(PROJECT_ROOT, block['adapter'])
            self.assertTrue(os.path.isfile(adapter), f'{name} adapter missing: {adapter}')

    def test_every_agent_has_route(self):
        with open(PROVIDERS_JSON) as f:
            agents = json.load(f)['agents']
        for a in ALL_AGENTS:
            self.assertIn(a, agents, f'agent {a} not in routing config')

    def test_adapters_implement_contract(self):
        # Every adapter must reject an unknown verb with usage on exit 2.
        for f in os.listdir(PROVIDERS_DIR):
            if not f.endswith('.sh'):
                continue
            r = subprocess.run(['bash', os.path.join(PROVIDERS_DIR, f), 'bogusverb'],
                               stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
            self.assertEqual(r.returncode, 2, f'{f} should exit 2 on unknown verb')
            self.assertIn('Usage', r.stderr)


class Resolution(unittest.TestCase):
    def test_agents_map_lists_all(self):
        out = run_llm(['agents']).stdout
        for a in ALL_AGENTS:
            self.assertIn(a, out)

    def test_chain_soma_order(self):
        # soma: opus → sonnet → ollama
        out = run_llm(['chain', 'soma']).stdout
        self.assertRegex(out, r'1\.\s+PRIMARY\s+claude/claude-opus')
        self.assertRegex(out, r'2\.\s+fallback#1\s+claude/claude-sonnet')
        self.assertRegex(out, r'3\.\s+fallback#2\s+ollama/gemma')

    def test_chain_lung_non_claude_primary(self):
        # lung deliberately runs Ollama primary with a Claude fallback (cross-provider)
        out = run_llm(['chain', 'lung']).stdout
        self.assertRegex(out, r'1\.\s+PRIMARY\s+ollama/')
        self.assertRegex(out, r'fallback#1\s+claude/')

    def test_model_string_provider_slash_model(self):
        # `--model ollama/gemma4:26b` → ollama is PRIMARY regardless of agent
        out = run_llm(['route', 'x', '--model', 'ollama/gemma4:26b']).stdout
        self.assertRegex(out, r'PRIMARY\s+→\s+ollama\s+/\s+gemma4:26b')

    def test_bare_model_prefix_inference(self):
        # bare gpt-* id should infer the openai provider
        out = run_llm(['route', 'x', '--model', 'gpt-4o-mini']).stdout
        self.assertRegex(out, r'PRIMARY\s+→\s+openai\s+/\s+gpt-4o-mini')


class Fallback(unittest.TestCase):
    def test_explicit_provider_keeps_resilience(self):
        # --provider openai (no key) must still list a claude/ollama fallback candidate
        out = run_llm(['route', 'x', '--provider', 'openai']).stdout
        self.assertRegex(out, r'PRIMARY\s+→\s+openai')
        self.assertTrue('claude' in out or 'ollama' in out,
                        'explicit provider should still get a fallback candidate')

    def test_no_fallback_flag(self):
        out = run_llm(['route', 'x', '--provider', 'openai', '--no-fallback']).stdout
        self.assertRegex(out, r'PRIMARY\s+→\s+openai')
        self.assertNotIn('fallback#1', out)


class Availability(unittest.TestCase):
    def test_claude_ready_openai_not(self):
        # Regression guard for the empty-field TSV delimiter bug: a column shift used to
        # make claude (empty base_url) read as 'disabled'. claude must show ready here.
        out = run_llm(['providers']).stdout
        # strip ANSI for robust matching
        import re
        clean = re.sub(r'\x1b\[[0-9;]*m', '', out)
        self.assertRegex(clean, r'claude\s+●\s*ready')
        self.assertRegex(clean, r'openai\s+○\s*not ready')


class ConcurrencyLock(unittest.TestCase):
    def test_same_name_serializes(self):
        log = '/tmp/test-lock-proof.log'
        if os.path.exists(log):
            os.remove(log)
        script = f'''
        source "{LIB}"
        export JIT_LOCK_DIR=/tmp/test-manusat-locks
        worker() {{ jit_with_lock "tagent" 10 -- bash -c \
          'echo "S $1 $(date +%s.%N)" >> {log}; sleep 0.5; echo "E $1 $(date +%s.%N)" >> {log}' _ "$1"; }}
        worker A & worker B & wait
        '''
        subprocess.run(['bash', '-c', script], check=True, timeout=30)
        with open(log) as f:
            lines = [ln.split() for ln in f if ln.strip()]
        # 4 events, and the two workers must not interleave (S,E of one before the other)
        self.assertEqual(len(lines), 4)
        order = [ln[1] for ln in lines]  # e.g. ['A','A','B','B'] or ['B','B','A','A']
        self.assertIn(order, [['A', 'A', 'B', 'B'], ['B', 'B', 'A', 'A']],
                      f'lock failed to serialize: {order}')

    def test_different_names_parallel(self):
        log = '/tmp/test-lock-parallel.log'
        if os.path.exists(log):
            os.remove(log)
        script = f'''
        source "{LIB}"
        export JIT_LOCK_DIR=/tmp/test-manusat-locks
        w() {{ jit_with_lock "$1" 10 -- bash -c \
          'echo "S $1 $(date +%s.%N)" >> {log}; sleep 0.5; echo "E $1 $(date +%s.%N)" >> {log}' _ "$1"; }}
        w nameA & w nameB & wait
        '''
        t0 = time.time()
        subprocess.run(['bash', '-c', script], check=True, timeout=30)
        elapsed = time.time() - t0
        # two 0.5s jobs under DIFFERENT locks should overlap → well under 1.0s serial sum
        self.assertLess(elapsed, 0.95, 'different-name locks should run in parallel')


@unittest.skipUnless(LIVE, 'set JIT_LIVE_TESTS=1 to run live provider calls')
class Live(unittest.TestCase):
    def test_claude_call_clean_stdout(self):
        r = run_llm(['call', 'Reply with exactly: PONG', '--provider', 'claude', '--model', 'haiku'])
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertTrue(r.stdout.strip(), 'empty completion')
        # The routing trace ("→ [PRIMARY] ลอง <provider>/<model> ...") must be on
        # stderr, never stdout. Use our Thai trace verb "ลอง" as the discriminator —
        # the model's own completion won't contain it, but our step() line will.
        self.assertNotIn('ลอง', r.stdout)
        self.assertIn('ลอง', r.stderr)

    def test_cross_provider_fallback_live(self):
        # openai (no key) → must fall through to claude and still return text
        r = run_llm(['call', 'Reply with exactly: OK', '--provider', 'openai', '--model', 'gpt-4o'])
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertTrue(r.stdout.strip())
        self.assertIn('claude', r.stderr)  # the fallback path is traced on stderr

    def test_ollama_call(self):
        r = run_llm(['call', 'ตอบสั้นๆ: สวัสดี', '--provider', 'ollama', '--model', 'small'])
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertTrue(r.stdout.strip())


if __name__ == '__main__':
    unittest.main(verbosity=2)
