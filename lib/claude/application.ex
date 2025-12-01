defmodule Claude.Application do
  @moduledoc """
  OTP Application for the Claude Discord bot.

  Starts and supervises all the core services:
  - Rate limiter for per-user message throttling
  - User cache for Discord user data
  - Member cache for guild member data
  - Nostrum bot for Discord gateway connection
  """

  use Application

  require Logger

  @impl true
  def start(_type, _args) do
    System.no_halt(true)

    Logger.info("Starting Claude Discord bot...")

    children = [
      # Core services - start before the bot
      Claude.RateLimiter,
      Claude.UserCache,
      Claude.MemberCache,

      # Discord bot - starts last after all services are ready
      {Nostrum.Bot, bot_options()}
    ]

    opts = [strategy: :one_for_one, name: Claude.Supervisor]

    case Supervisor.start_link(children, opts) do
      {:ok, pid} ->
        Logger.info("Claude bot supervisor started successfully")
        {:ok, pid}

      {:error, reason} = error ->
        Logger.error("Failed to start Claude bot: #{inspect(reason)}")
        error
    end
  end

  @impl true
  def stop(_state) do
    Logger.info("Claude bot shutting down...")
    :ok
  end

  # Private Functions

  defp bot_options do
    %{
      name: Claude,
      consumer: Claude.MessageConsumer,
      intents: [
        :direct_messages,
        :guild_messages,
        :message_content,
        :guilds,
        :guild_members
      ],
      wrapped_token: fn -> Claude.Config.discord_token() end
    }
  end
end
