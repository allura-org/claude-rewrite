defmodule Claude.MessageConsumer do
  @moduledoc """
  Nostrum consumer that handles Discord gateway events.

  This module receives events from Discord and routes them appropriately:
  - READY events capture the bot's user ID and register slash commands
  - MESSAGE_CREATE events that mention the bot are sent to MessageHandler
  - INTERACTION_CREATE events are routed to the Commands.Registry
  """

  @behaviour Nostrum.Consumer

  require Logger

  alias Claude.{Config, MessageHandler, Utils}
  alias Claude.Commands.Registry, as: CommandRegistry

  # Handle READY event - captures bot user ID and registers commands
  def handle_event({:READY, ready_data, _ws_state}) do
    bot_user_id = ready_data.user.id
    Logger.info("Bot connected as #{ready_data.user.username} (ID: #{bot_user_id})")
    Config.set_bot_user_id(bot_user_id)

    # wait for any other init to happen
    Process.sleep(1_000)
    CommandRegistry.register_commands()

    :ok
  end

  # Handle INTERACTION_CREATE - routes slash commands to handlers
  def handle_event({:INTERACTION_CREATE, interaction, _ws_state}) do
    # Handle interactions in a separate process to not block the consumer
    CommandRegistry.handle_interaction(interaction)
  end

  # Handle MESSAGE_CREATE - routes messages to MessageHandler
  def handle_event({:MESSAGE_CREATE, msg, _ws_state}) do
    # Quick checks before spawning a task
    cond do
      Utils.from_bot?(msg) ->
        :ok

      not Utils.guild_message?(msg) ->
        :ok

      true ->
        # Handle in a separate process to not block the consumer
        MessageHandler.handle_message(msg)
    end
  end

  # Catch-all for other events
  def handle_event(_event), do: :ok
end
