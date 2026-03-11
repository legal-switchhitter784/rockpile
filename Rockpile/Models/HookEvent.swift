import Foundation

struct HookEvent: Decodable, Sendable {
    let sessionId: String
    let event: String
    let status: String
    let ts: Int?
    let tool: String?
    let error: String?
    let userPrompt: String?

    // Token usage (per-request, from plugin)
    let inputTokens: Int?
    let outputTokens: Int?
    let cacheReadTokens: Int?
    let cacheCreationTokens: Int?

    // Daily aggregate (read from ~/.claude/stats-cache.json by plugin)
    let dailyTokensUsed: Int?

    // Rate limit flag (429 detected)
    let rateLimited: Bool?

    /// Direct initializer — avoids JSON round-trip when synthesizing events (e.g. GatewaySessionRouter).
    init(sessionId: String, event: String, status: String, tool: String? = nil) {
        self.sessionId = sessionId
        self.event = event
        self.status = status
        self.ts = nil
        self.tool = tool
        self.error = nil
        self.userPrompt = nil
        self.inputTokens = nil
        self.outputTokens = nil
        self.cacheReadTokens = nil
        self.cacheCreationTokens = nil
        self.dailyTokensUsed = nil
        self.rateLimited = nil
    }

    enum CodingKeys: String, CodingKey {
        case sessionId = "session_id"
        case event, status, ts, tool, error
        case userPrompt = "user_prompt"
        case inputTokens = "input_tokens"
        case outputTokens = "output_tokens"
        case cacheReadTokens = "cache_read_tokens"
        case cacheCreationTokens = "cache_creation_tokens"
        case dailyTokensUsed = "daily_tokens_used"
        case rateLimited = "rate_limited"
    }
}
