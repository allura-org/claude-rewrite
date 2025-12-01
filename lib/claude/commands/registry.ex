defmodule Claude.Commands.Registry do
  @moduledoc """
  Handles registration of application commands (slash commands) with Discord.

  This module is responsible for:
  - Registering commands on bot startup
  - Handling command interactions
  - Routing commands to their respective handlers
  """

  require Logger

  alias Nostrum.Api.ApplicationCommand

  @doc """
  Registers all application commands with Discord.

  Should be called after the bot has connected (READY event received).
  """
  @spec register_commands() :: :ok | {:error, term()}
  def register_commands do
    Logger.info("Registering application commands...")

    commands = [
      Claude.Commands.Info.definition(),
      Claude.Commands.Help.definition()
    ]

    case ApplicationCommand.bulk_overwrite_global_commands(commands) do
      {:ok, registered} ->
        Logger.info("Successfully registered #{length(registered)} application commands")
        :ok

      {:error, reason} = error ->
        Logger.error("Failed to register application commands: #{inspect(reason)}")
        error
    end
  end

  @doc """
  Handles an interaction create event.
  Routes the interaction to the appropriate command handler.
  """
  @spec handle_interaction(Nostrum.Struct.Interaction.t()) :: :ok
  def handle_interaction(interaction) do
    command_name = interaction.data.name

    Logger.debug("Handling command: #{command_name}")

    case command_name do
      "info" -> Claude.Commands.Info.handle(interaction)
      "help" -> Claude.Commands.Help.handle(interaction)
      _ ->
        Logger.warning("Unknown command: #{command_name}")
        respond_unknown_command(interaction)
    end

    :ok
  end

  defp respond_unknown_command(interaction) do
    Nostrum.Api.Interaction.create_response(interaction, %{
      type: 4,
      data: %{
        content: "Unknown command. Use `/help` to see available commands."
      }
    })
  end
end
