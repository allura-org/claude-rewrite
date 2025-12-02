defmodule Claude.Commands.Registry do
  @moduledoc """
  Handles registration of application commands (slash commands) with Discord.

  This module is responsible for:
  - Registering commands on bot startup
  - Handling command interactions
  - Routing commands to their respective handlers

  ## Adding New Commands

  1. Create a new command module implementing `Claude.Commands.Command`
  2. Add it to the `@commands` list in this module
  3. The command will be automatically registered and routed
  """

  require Logger

  alias Nostrum.Api.ApplicationCommand

  # List of command modules that implement the Command behaviour
  @commands [
    Claude.Commands.Info,
    Claude.Commands.Help
  ]

  @doc """
  Returns the list of registered command modules.
  """
  @spec commands() :: [module()]
  def commands, do: @commands

  @doc """
  Registers all application commands with Discord.

  Should be called after the bot has connected (READY event received).
  """
  @spec register_commands() :: :ok | {:error, term()}
  def register_commands do
    Logger.info("Registering application commands...")

    definitions = Enum.map(@commands, & &1.definition())

    case ApplicationCommand.bulk_overwrite_global_commands(definitions) do
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

    case find_command(command_name) do
      nil ->
        Logger.warning("Unknown command: #{command_name}")
        respond_unknown_command(interaction)

      command_module ->
        command_module.handle(interaction)
    end

    :ok
  end

  # Private helpers

  defp find_command(name) do
    Enum.find(@commands, fn module -> module.name() == name end)
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
