#!/usr/bin/env bash
# limbs/ollama.sh — แขนขาของ innova: MDES Ollama API
# Usage: ./ollama.sh "prompt here"
# Example: ./ollama.sh "แนะนำตัวในฐานะ innova"

OLLAMA_URL="https://ollama.mdes-innova.online/api/generate"
OLLAMA_TOKEN="9e34679b9d60d8b984005ec46508579c"
MODEL="${OLLAMA_MODEL:-gemma4:26b}"
PROMPT="${1:-สวัสดี}"

curl -s --location "$OLLAMA_URL" \
  --header "Authorization: Bearer $OLLAMA_TOKEN" \
  --header "Content-Type: application/json" \
  --data "$(python3 -c "import json,sys; print(json.dumps({'model':'$MODEL','prompt':sys.argv[1],'stream':False}))" "$PROMPT")" \
  | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('response','ERROR: '+str(d)))"
