# Lesson: MCP SDK Tool Schemas must be Zod Objects

**Date**: 2026-06-13 | **Context**: innomcp-server-node crash

## The Pattern
When registering tools via the `@modelcontextprotocol/sdk`, the `inputSchema` must be a valid Zod schema (e.g., `z.object({ ... })`). Providing a raw JavaScript object that *looks* like a JSON schema will cause the server to throw `Error: inputSchema must be a Zod schema or raw shape` during initialization.

## The Failure Mode
The server fails to boot (`MCP_NOT_READY`), but the error is only visible in the stderr logs of the process, not the high-level health check.

## How to Apply
1. Import `z` from `zod`.
2. Define `inputSchema` using `z.object({ ... })`.
3. If using `enum`, use `z.enum(["val1", "val2"])`.
4. If using optional fields, use `.optional()`.

Related: [[innomcp-server-node-boot-failures]]
