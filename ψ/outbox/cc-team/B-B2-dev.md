<!-- cc-team deliverable
 group: B (TICKET-006 Phase 2: Manus-pattern integration PoC for innomcp — request_id wrapper, skill registration, tests)
 member: B2 role=dev model=Qwen/Qwen3.7-Max
 finish_reason: stop | tokens: {"prompt_tokens":175,"completion_tokens":3023,"total_tokens":3198,"prompt_tokens_details":{"cached_tokens":0,"audio_tokens":0,"video_tokens":0},"completion_tokens_details":{"reasoning_tokens":2228,"image_tokens":0},"cache_creation_input_tokens":0} | 56s
 generated: 2026-06-10T19:22:38.172Z -->
{
  "skills": [
    {
      "id": "mouth_broadcast",
      "name": "Broadcast Message",
      "description": "Broadcasts a message to a specific agent's inbox with an optional prefix.",
      "inputs": {
        "agent": {
          "type": "string",
          "required": true
        },
        "message": {
          "type": "string",
          "required": true
        },
        "prefix": {
          "type": "string",
          "required": false,
          "default": ""
        }
      },
      "outputs": {
        "message_id": {
          "type": "string"
        },
        "delivered_at": {
          "type": "string"
        },
        "inbox_size": {
          "type": "integer"
        }
      },
      "errors": [
        {
          "code": "AGENT_NOT_FOUND",
          "when": "The specified agent identifier does not match any active agent."
        },
        {
          "code": "INBOX_OVERFLOW",
          "when": "The target agent's inbox has reached its maximum capacity."
        }
      ]
    },
    {
      "id": "oracle_knowledge_search",
      "name": "Knowledge Search",
      "description": "Searches the central knowledge base and returns relevant documents or snippets.",
      "inputs": {
        "query": {
          "type": "string",
          "required": true
        },
        "limit": {
          "type": "integer",
          "required": false,
          "default": 5
        }
      },
      "outputs": {
        "results": {
          "type": "array"
        },
        "search_time_ms": {
          "type": "number"
        }
      },
      "errors": [
        {
          "code": "EMPTY_QUERY",
          "when": "The provided search query is empty or contains only whitespace."
        },
        {
          "code": "INDEX_UNAVAILABLE",
          "when": "The underlying knowledge base index is currently offline or unreachable."
        }
      ]
    },
    {
      "id": "verifier_test_runner",
      "name": "Test Runner",
      "description": "Executes a test suite or specific tests and calculates pass/fail metrics.",
      "inputs": {
        "test_suite": {
          "type": "string",
          "required": true
        },
        "tests": {
          "type": "array",
          "required": false,
          "default": []
        }
      },
      "outputs": {
        "passed": {
          "type": "integer"
        },
        "failed": {
          "type": "integer"
        },
        "total": {
          "type": "integer"
        },
        "pass_rate": {
          "type": "number"
        },
        "failures": {
          "type": "array"
        }
      },
      "errors": [
        {
          "code": "SUITE_NOT_FOUND",
          "when": "The specified test suite name does not exist in the registry."
        },
        {
          "code": "RUNNER_CRASH",
          "when": "The test execution environment encountered a fatal exception."
        }
      ]
    }
  ]
}
