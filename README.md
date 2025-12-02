# Claude Discord Bot (Elixir)

A Discord bot powered by LLM AI, ported from Python to Elixir using the Nostrum library.

## Features

- **AI Chat**: Mention the bot in any message to get an AI-powered response
- **Message Context**: Bot reads channel history to maintain conversation context
- **Image Support**: Attach images to your messages for AI analysis
- **Slash Commands**: `/help` and `/info` commands for bot information
- **Rate Limiting**: Per-user rate limiting to prevent spam
- **Typing Indicators**: Shows typing while processing requests
- **Extensible LLM Providers**: Easy to add new LLM backends

## Architecture

```
lib/
├── claude.ex                    # Main module with public API
├── claude/
│   ├── application.ex           # OTP Application & Supervisor
│   ├── config.ex                # Configuration (files & env vars)
│   ├── llm.ex                   # LLM facade module
│   ├── llm/
│   │   ├── provider.ex          # Provider behaviour
│   │   └── providers/
│   │       └── openai.ex        # OpenAI-compatible implementation
│   ├── message_consumer.ex      # Nostrum event handler
│   ├── message_handler.ex       # Message processing logic
│   ├── rate_limiter.ex          # Per-user rate limiting (non-blocking)
│   ├── user_cache.ex            # ETS-backed user cache
│   ├── member_cache.ex          # ETS-backed member cache
│   ├── utils.ex                 # Helper functions
│   └── commands/
│       ├── command.ex           # Command behaviour
│       ├── registry.ex          # Command registration & routing
│       ├── info.ex              # /info command
│       └── help.ex              # /help command
```

## Configuration

Edit `config/config.exs` to configure the bot:

```elixir
config :claude,
  discord: %{
    token: "YOUR_DISCORD_BOT_TOKEN"
  },
  llm: %{
    provider: Claude.LLM.Providers.OpenAI,
    model: "gpt-4",
    llm_api_key: "YOUR_LLM_API_KEY",
    llm_base_url: "https://api.openai.com/v1",
    max_tokens: 1024,
    max_context_messages: 50,
    rate_limit_ms: 2_000
  }
```

Alternatively, one can create `config/dev.exs` or `config/production.exs` to set configs specifically for those runtime environments.

### Environment Variables

You can also configure the bot using environment variables (these take priority over config files):

```bash
export CLAUDE_DISCORD_TOKEN="your-discord-token"
export CLAUDE_LLM_API_KEY="your-llm-api-key"
export CLAUDE_LLM_BASE_URL="https://api.openai.com/v1"
export CLAUDE_MODEL="gpt-4"
export CLAUDE_MAX_TOKENS="1024"
export CLAUDE_MAX_CONTEXT_MESSAGES="50"
export CLAUDE_RATE_LIMIT_MS="2000"
```

This is useful for deployments where you don't want to commit secrets to config files.

### Configuration Options

| Option | Description | Default |
|--------|-------------|---------|
| `provider` | LLM provider module | `Claude.LLM.Providers.OpenAI` |
| `model` | Model name for chat completions | `"doubao-seed-1-6-thinking-250615"` |
| `llm_api_key` | API key for the LLM provider | Required |
| `llm_base_url` | Base URL for OpenAI-compatible API | `"https://aihubmix.com/v1"` |
| `max_tokens` | Maximum tokens in LLM response | `1024` |
| `max_context_messages` | Messages to include in context | `50` |
| `rate_limit_ms` | Milliseconds between messages per user | `2000` |

## Installation & Running

1. **Install dependencies:**
   ```bash
   mix deps.get
   ```

2. **Configure the bot:**
   Edit `config/config.exs` with your Discord token and LLM API key.

3. **Run the bot:**
   ```bash
   mix run --no-halt
   ```

   Or in IEx for development:
   ```bash
   iex -S mix
   ```

## Usage

### Chat with the Bot

Mention the bot in any message:
```
@Claude what's the weather like today?
```

The bot will:
1. Read recent channel history for context
2. Show a typing indicator
3. Call the LLM API
4. Reply with the AI response

### Clear Conversation History

Send this message to reset context:
```
[DO NOT COUNT PAST THIS MESSAGE]
```

### Slash Commands

- `/help` - Show usage information
- `/info` - Display bot configuration and status

## Adding New LLM Providers

Implement the `Claude.LLM.Provider` behaviour:

```elixir
defmodule Claude.LLM.Providers.MyProvider do
  @behaviour Claude.LLM.Provider

  @impl true
  def name, do: "My Provider"

  @impl true
  def validate_config do
    # Return :ok or {:error, reason}
    :ok
  end

  @impl true
  def chat_completion(messages, options) do
    # Return {:ok, response_text} or {:error, reason}
    {:ok, "Hello!"}
  end

  @impl true
  def supports_images?, do: true
end
```

Then configure it:
```elixir
config :claude, :llm, %{
  provider: Claude.LLM.Providers.MyProvider,
  # ... other options
}
```

## Supervision Tree

```
Claude.Supervisor
├── Claude.RateLimiter (GenServer)
├── Claude.UserCache (ETS)
├── Claude.MemberCache (ETS)
└── Nostrum.Bot
    └── Claude.MessageConsumer
```

## Development

### Run Tests
```bash
mix test
```

### Generate Documentation
```bash
mix docs
```

## Todo

- [ ] `/image` command with fal.ai integration
- [ ] File-based logging with rotation
- [ ] Guild-specific configuration
- [ ] Conversation memory persistence

## Credits

- Original Python bot by fizz
- Elixir port uses [Nostrum](https://github.com/Kraigie/nostrum) for Discord API
- HTTP requests via [Req](https://github.com/wojtekmach/req)

## License

AGPLv3
