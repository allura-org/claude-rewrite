import Config

# Nostrum configuration
config :nostrum,
  youtubedl: nil,
  streamlink: nil

# Logger configuration
config :logger, :console,
  level: :info,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id, :user_id, :channel_id]


# Claude bot configuration
config :claude,
  # Discord configuration
  discord: %{
    token: nil
  },

  # LLM provider configuration
  llm: %{
    # The LLM provider module to use (Claude.LLM.Providers.OpenAI is the default)
    provider: Claude.LLM.Providers.OpenAI,

    # Model to use for chat completions
    model: "claude-opus-4-5",

    # API key for the LLM provider
    llm_api_key: nil,

    # Base URL for the OpenAI-compatible API
    llm_base_url: "https://aihubmix.com/v1",

    # Maximum tokens in LLM response
    max_tokens: 1024,

    # Maximum messages to include in context
    max_context_messages: 50,

    # Rate limiting: milliseconds between messages per user
    rate_limit_ms: 2_000
  }

import_config "#{config_env()}.exs"
