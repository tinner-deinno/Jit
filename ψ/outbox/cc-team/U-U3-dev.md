<!-- cc-team deliverable
 group: U (innomcp UI debug wave — central backend URL helper, fix broken fetches, hide test creds, VQA regression spec)
 member: U3 role=dev model=zai-org/GLM-5.1
 finish_reason: stop | tokens: {"prompt_tokens":297,"completion_tokens":1040,"total_tokens":1337,"prompt_tokens_details":{"cached_tokens":0,"audio_tokens":0,"video_tokens":0},"completion_tokens_details":{"reasoning_tokens":917,"reasoning_tokens_estimated":true,"image_tokens":0},"cache_creation_input_tokens":0} | 35s
 generated: 2026-06-12T08:54:48.695Z -->
            {process.env.NODE_ENV !== "production" && (
            {/* Test Credentials Hint */}
            <div className="bg-blue-50 dark:bg-blue-900/20 border border-blue-200 dark:border-blue-800 rounded-lg p-4">
              <p className="text-sm font-semibold text-blue-800 dark:text-blue-300 mb-2">
                🔑 Test Credentials
              </p>
              <div className="space-y-1 text-xs text-blue-700 dark:text-blue-400 font-mono">
                <p><strong>Admin:</strong> admin@example.local / &lt;REDACTED_PASSWORD&gt;</p>
                <p><strong>User:</strong> user@example.local / &lt;REDACTED_PASSWORD&gt;</p>
                <p><strong>Officer:</strong> officer@example.local / &lt;REDACTED_PASSWORD&gt;</p>
              </div>
            </div>
            )}
