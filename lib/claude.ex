defmodule Claude do
  @moduledoc """
  Claude Discord Bot - An AI-powered Discord bot.

  This is the main module for the Claude Discord bot application.
  It provides a public API for querying bot status and version information.

  ## Main Components

  - `Claude.Application` - OTP Application and supervision tree
  - `Claude.MessageConsumer` - Nostrum consumer for Discord events
  - `Claude.MessageHandler` - Processes incoming Discord messages
  - `Claude.LLM` - LLM provider facade
  - `Claude.Commands` - Slash command handlers

  ## Configuration

  See `Claude.Config` for all configuration options. The bot can be configured via:
  - Config files (`config/config.exs`, `config/dev.exs`, etc.)
  - Environment variables (`CLAUDE_*`)

  ## Usage

  Start the bot with:

      iex -S mix

  Or for production:

      MIX_ENV=prod mix run --no-halt

  ## Example

      # Check bot status
      Claude.status()
      #=> %{version: "0.1.0", bot_user_id: 123456789, provider: "OpenAI-compatible", model: "claude-opus-4-5"}

      # Get version
      Claude.version()
      #=> "0.1.0"
  """

  @doc """
  Returns the application version.

  ## Example

      iex> is_binary(Claude.version())
      true
  """
  @spec version() :: String.t()
  def version do
    case Application.spec(:claude, :vsn) do
      nil -> "dev"
      vsn -> to_string(vsn)
    end
  end

  @doc """
  Returns bot status information.

  Returns a map containing:
  - `:version` - Application version
  - `:bot_user_id` - Discord user ID of the bot (nil if not connected)
  - `:provider` - Name of the configured LLM provider
  - `:model` - Configured LLM model name

  ## Example

      iex> status = Claude.status()
      iex> Map.keys(status) |> Enum.sort()
      [:bot_user_id, :model, :provider, :version]
  """
  @spec status() :: map()
  def status do
    %{
      version: version(),
      bot_user_id: Claude.Config.bot_user_id(),
      provider: Claude.LLM.provider_name(),
      model: Claude.Config.model()
    }
  end

  @doc """
  Checks if the bot is connected to Discord.

  Returns `true` if the bot has successfully connected and received
  its user ID from Discord, `false` otherwise.

  ## Example

      iex> is_boolean(Claude.connected?())
      true
  """
  @spec connected?() :: boolean()
  def connected? do
    Claude.Config.bot_user_id() != nil
  end

  @doc """
  Returns information about the configured LLM provider.

  ## Example

      iex> info = Claude.llm_info()
      iex> Map.keys(info) |> Enum.sort()
      [:base_url, :model, :provider, :supports_images]
  """
  @spec llm_info() :: map()
  def llm_info do
    %{
      provider: Claude.LLM.provider_name(),
      model: Claude.Config.model(),
      base_url: Claude.Config.llm_base_url(),
      supports_images: Claude.LLM.supports_images?()
    }
  end
end
