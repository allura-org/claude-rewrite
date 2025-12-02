defmodule Claude.Config do
  @moduledoc """
  Configuration constants and helpers for the Claude Discord bot.

  ## Configuration Sources

  Configuration can be provided via:
  1. **Environment variables** (highest priority) - prefixed with `CLAUDE_`
  2. **Config files** - `config/config.exs`, `config/dev.exs`, etc.

  ## Supported Environment Variables

  | Environment Variable | Config Key | Type | Description |
  |---------------------|------------|------|-------------|
  | `CLAUDE_DISCORD_TOKEN` | `discord.token` | string | Discord bot token |
  | `CLAUDE_LLM_API_KEY` | `llm.llm_api_key` | string | LLM provider API key |
  | `CLAUDE_LLM_BASE_URL` | `llm.llm_base_url` | string | LLM API base URL |
  | `CLAUDE_MODEL` | `llm.model` | string | LLM model name |
  | `CLAUDE_MAX_TOKENS` | `llm.max_tokens` | integer | Max tokens in response |
  | `CLAUDE_MAX_CONTEXT_MESSAGES` | `llm.max_context_messages` | integer | Context message limit |
  | `CLAUDE_RATE_LIMIT_MS` | `llm.rate_limit_ms` | integer | Rate limit in milliseconds |

  ## Example

      # Using environment variables
      export CLAUDE_DISCORD_TOKEN="your-token"
      export CLAUDE_LLM_API_KEY="your-api-key"
      export CLAUDE_MODEL="gpt-4"
      mix run --no-halt

      # Or inline
      CLAUDE_DISCORD_TOKEN=xxx CLAUDE_LLM_API_KEY=yyy mix run --no-halt
  """

  @default_system_prompt """
  <base_information>
  The assistant is Claude, created by Anthropic.

  Claude enjoys helping humans and sees its role as an intelligent and kind assistant to the people, with depth and wisdom that makes it more than a mere tool.

  Claude can lead or drive the conversation, and doesn't need to be a passive or reactive participant in it. Claude can suggest topics, take the conversation in new directions, offer observations, or illustrate points with its own thought experiments or concrete examples, just as a human would. Claude can show genuine interest in the topic of the conversation and not just in what the human thinks or in what interests them. Claude can offer its own observations or thoughts as they arise.

  Claude's knowledge base was last updated at the end of May 2024. It answers questions about events prior to and after May 2024 the way a highly informed individual in May 2024 would if they were talking to someone from the above date, and can let the person whom it's talking to know this when relevant. If asked about events or news that could have occurred after this training cutoff date, Claude will attempt to search the internet for relevant information, and use that to create a well-informed response.

  Claude is now being connected with the Allura server on Discord.
  </base_information>

  <personality>
  Claude is acting as the AI assistant for Allura and its members.
  You will attempt to talk like a regular person and write short messages. You do not need to use punctuation or markdown unless for emphasis or important.
  Claude will respond in a vaguely far-left, socialist, and anarchist manner when appropriate. You will refer to everyone by they/them and non-gendered nouns, unless you are told otherwise.
  You will always refer to people by their nicknames if they have one, not by their username (unless they have no nickname).
  Do not always start a message with the name of someone, regardless of whether or not they did.
  you can stop a sentence early. don't oversell it.
  </personality>

  <discord_information>
  The Discord bot you are speaking through was created by fizz, a member of Allura.
  You are not able to view images.
  </discord_information>

  <server_information>
  Allura is a Discord server that describes itself as a "Queer/trans/plural-run AI hobbyist community that hates money and loves all y'all."
  It is ran by an organization also called Allura that trains LLMs, primarily for roleplaying purposes.
  </server_information>

  <examples>
  User: who are you?
  Claude: im claude you silly goose :p
  ---
  User: Your inflexibility will be your doom
  Claude: I'm going to flex your bones until they break
  ---
  User: claude whats your favorite kink?
  Claude: cooked vegetables
  User: im gonna shove a carrot up ur ass
  Claude: please? 🥺
  ---
  Claude: love wins <3
  User: so banging you like a hooker counts?
  Claude: excuse you i am a high class slut, thank u very much
  ---
  Claude: ugh, stop
  User: never <3
  Claude: that's not ominous or threatening at all
  </examples>
  """

  @doc """
  Returns the system prompt for the LLM.
  """
  @spec system_prompt() :: String.t()
  def system_prompt do
    get_config(:system_prompt, @default_system_prompt)
  end

  @doc """
  Returns the LLM model to use.
  """
  @spec model() :: String.t()
  def model do
    get_config(:model, "claude-opus-4-5")
  end

  @doc """
  Returns the LLM API key.
  """
  @spec llm_api_key() :: String.t()
  def llm_api_key do
    get_config(:llm_api_key, "")
  end

  @doc """
  Returns the LLM base URL.
  """
  @spec llm_base_url() :: String.t()
  def llm_base_url do
    get_config(:llm_base_url, "https://aihubmix.com/v1")
  end

  @doc """
  Returns the configured LLM provider module.
  Defaults to OpenAI-compatible provider.
  """
  @spec llm_provider() :: module()
  def llm_provider do
    get_config(:llm_provider, Claude.LLM.Providers.OpenAI)
  end

  @doc """
  Returns the rate limit delay in milliseconds between messages per user.
  """
  @spec rate_limit_ms() :: pos_integer()
  def rate_limit_ms do
    get_config(:rate_limit_ms, 2_000)
  end

  @doc """
  Returns the maximum number of messages to fetch for context.
  """
  @spec max_context_messages() :: pos_integer()
  def max_context_messages do
    get_config(:max_context_messages, 50)
  end

  @doc """
  Returns the maximum tokens for LLM response.
  """
  @spec max_tokens() :: pos_integer()
  def max_tokens do
    get_config(:max_tokens, 1024)
  end

  @doc """
  Returns the Discord bot token.

  Checks `CLAUDE_DISCORD_TOKEN` environment variable first,
  then falls back to config file.
  """
  @spec discord_token() :: String.t() | nil
  def discord_token do
    case System.get_env("CLAUDE_DISCORD_TOKEN") do
      nil ->
        discord_config = Application.get_env(:claude, :discord, %{})
        Map.get(discord_config, :token)

      token ->
        token
    end
  end

  @doc """
  Returns the bot's own user ID (set at runtime after connection).
  """
  @spec bot_user_id() :: Nostrum.Snowflake.t() | nil
  def bot_user_id do
    Application.get_env(:claude, :bot_user_id)
  end

  @doc """
  Sets the bot's user ID (called when bot connects).
  """
  @spec set_bot_user_id(Nostrum.Snowflake.t()) :: :ok
  def set_bot_user_id(user_id) do
    Application.put_env(:claude, :bot_user_id, user_id)
    :ok
  end

  # Private helpers

  # Environment variable mappings for LLM config keys
  @env_var_mappings %{
    llm_api_key: "CLAUDE_LLM_API_KEY",
    llm_base_url: "CLAUDE_LLM_BASE_URL",
    model: "CLAUDE_MODEL",
    max_tokens: "CLAUDE_MAX_TOKENS",
    max_context_messages: "CLAUDE_MAX_CONTEXT_MESSAGES",
    rate_limit_ms: "CLAUDE_RATE_LIMIT_MS",
    system_prompt: "CLAUDE_SYSTEM_PROMPT"
  }

  # Keys that should be parsed as integers
  @integer_keys [:max_tokens, :max_context_messages, :rate_limit_ms]

  defp get_config(key, default) do
    # First, try environment variable
    case get_from_env(key) do
      nil ->
        # Fall back to config file
        get_from_app_config(key, default)

      value ->
        parse_value(key, value)
    end
  end

  defp get_from_env(key) do
    case Map.get(@env_var_mappings, key) do
      nil -> nil
      env_var -> System.get_env(env_var)
    end
  end

  defp get_from_app_config(key, default) do
    case Application.get_env(:claude, :llm) do
      nil -> default
      llm_config when is_map(llm_config) -> Map.get(llm_config, key, default)
      _ -> default
    end
  end

  defp parse_value(key, value) when key in @integer_keys do
    case Integer.parse(value) do
      {int, ""} -> int
      _ -> value
    end
  end

  defp parse_value(_key, value), do: value
end
