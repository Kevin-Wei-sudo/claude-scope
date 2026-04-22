package io.sandwichlab.claudescope.service.oauth

object OAuthConfig {
    // Values mirror ios/ClaudeScope UsageService.swift. Keep in sync with Swift client_id.
    const val CLIENT_ID = "9d1c250a-e61b-44d9-88ed-5944d1962f5e"

    const val AUTHORIZE_URL = "https://claude.ai/oauth/authorize"
    const val TOKEN_URL = "https://platform.claude.com/v1/oauth/token"
    const val USAGE_URL = "https://api.anthropic.com/api/oauth/usage"
    const val USERINFO_URL = "https://api.anthropic.com/api/oauth/userinfo"
    const val REDIRECT_URI = "https://platform.claude.com/oauth/code/callback"

    const val ANTHROPIC_BETA_HEADER = "oauth-2025-04-20"

    val DEFAULT_SCOPES = listOf("user:profile", "user:inference")
}
