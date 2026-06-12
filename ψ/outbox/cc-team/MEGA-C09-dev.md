<!-- cc-team deliverable
 group: MEGA (56-task parallel burn across innomcp + Jit)
 member: C09 role=dev model=commandcode/deepseek/deepseek-v4-flash
 finish_reason: end_turn | tokens: {"prompt_tokens":125,"completion_tokens":1536,"total_tokens":1661} | 17s
 generated: 2026-06-12T19:29:19.423Z -->
{
  "hooks": {
    "SessionStart": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "session-start.js"
          }
        ]
      }
    ],
    "PreCompact": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "pre-compact.js"
          }
        ]
      }
    ],
    "PreToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [
          {
            "type": "command",
            "command": "config-protection.js"
          },
          {
            "type": "command",
            "command": "gateguard.js"
          }
        ]
      },
      {
        "matcher": "*",
        "hooks": [
          {
            "type": "command",
            "command": "observe.js"
          }
        ]
      }
    ],
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "stop-format-typecheck.sh"
          }
        ]
      }
    ]
  }
}
