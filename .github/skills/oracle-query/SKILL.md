---
name: oracle-query
description: "Query the Arra Oracle V3 knowledge base for wisdom, patterns, and learnings. Use when: searching Oracle, asking what innova knows, querying knowledge base, ถามองค์ความรู้, ค้นหาความรู้, oracle search"
---

# Oracle Query Skill

Query the Arra Oracle V3 running at `http://localhost:47778`

## Steps

1. **Check Oracle health**
   ```bash
   curl -s http://localhost:47778/api/health
   ```

2. **Search for relevant knowledge**
   ```bash
   curl -s "http://localhost:47778/api/search?q=<QUERY>"
   ```

3. **If Oracle is not running, start it**
   ```bash
   export PATH="$HOME/.bun/bin:$PATH"
   cd /workspaces/arra-oracle-v3
   ORACLE_PORT=47778 bun run server > /tmp/oracle-server.log 2>&1 &
   sleep 3 && curl -s http://localhost:47778/api/health
   ```

4. **Learn something new** (after tasks)
   ```bash
   curl -s -X POST http://localhost:47778/api/learn \
     -H "Content-Type: application/json" \
     -d '{"pattern":"<title>","content":"<what-learned>","type":"learning","concepts":["tag1","tag2"],"origin":"innova-jit"}'
   ```

## Output Format

Return search results with:
- Number of results found
- Top 3 most relevant (id, type, concepts)
- Key content excerpt
