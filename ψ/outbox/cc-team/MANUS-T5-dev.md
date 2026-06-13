<!-- cc-team deliverable
 group: MANUS (manus-parity scaffolds: tools, agent loop, SSE, workspace stream, artifacts, contract tests, docs)
 member: T5 role=dev model=deepseek/deepseek-v4-pro
 finish_reason: stop | tokens: {"prompt_tokens":223,"completion_tokens":1591,"total_tokens":1814,"prompt_tokens_details":{"cached_tokens":0,"audio_tokens":0,"video_tokens":0},"completion_tokens_details":{"reasoning_tokens":1139,"image_tokens":0},"cache_creation_input_tokens":0} | 19s
 generated: 2026-06-13T05:42:56.178Z -->
// innomcp-node/src/tools/registry.ts
// Standalone ToolRegistry: manages tool definitions and exports OpenAI-compatible function-calling specs.
// No external dependencies – intended to be wired later into the existing innomcp-node project.

/**
 * A tool that the agent can invoke. The `inputSchema` should be a valid JSON Schema (draft-07) object
 * describing the expected parameters (the top-level is usually `{"type": "object", "properties": {...}, "required": [...]}`).
 */
export interface Tool {
  name: string;
  description: string;
  inputSchema: Record<string, unknown>;
}

/**
 * Registry for all available tools.
 */
export class ToolRegistry {
  private readonly tools: Map<string, Tool> = new Map();

  /**
   * Add a tool to the registry. Throws if a tool with the same name already exists.
   */
  register(tool: Tool): void {
    if (this.tools.has(tool.name)) {
      throw new Error(`Tool "${tool.name}" is already registered.`);
    }
    this.tools.set(tool.name, tool);
  }

  /**
   * Retrieve a tool by name, or undefined if not found.
   */
  get(name: string): Tool | undefined {
    return this.tools.get(name);
  }

  /**
   * Return all registered tools.
   */
  list(): Tool[] {
    return Array.from(this.tools.values());
  }

  /**
   * Convert the registered tools into the array shape expected by OpenAI's function-calling API.
   * Each element follows the pattern: `{ type: "function", function: { name, description, parameters: inputSchema } }`.
   */
  toOpenAIToolSpecs(): Array<{
    type: 'function';
    function: {
      name: string;
      description: string;
      parameters: Record<string, unknown>;
    };
  }> {
    return this.list().map((tool) => ({
      type: 'function' as const,
      function: {
        name: tool.name,
        description: tool.description,
        parameters: tool.inputSchema,
      },
    }));
  }
}
