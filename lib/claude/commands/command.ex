defmodule Claude.Commands.Command do
  @moduledoc """
  Behaviour for slash command implementations.

  All slash commands should implement this behaviour to ensure consistency
  and enable automatic discovery.

  ## Example

      defmodule Claude.Commands.MyCommand do
        @behaviour Claude.Commands.Command

        @impl true
        def name, do: "mycommand"

        @impl true
        def definition do
          %{
            name: "mycommand",
            description: "Does something cool",
            type: 1  # CHAT_INPUT
          }
        end

        @impl true
        def handle(interaction) do
          Nostrum.Api.Interaction.create_response(interaction, %{
            type: 4,
            data: %{content: "Hello!"}
          })
          :ok
        end
      end

  ## Command Types

  Discord command types:
  - `1` - CHAT_INPUT (slash command)
  - `2` - USER (right-click on user)
  - `3` - MESSAGE (right-click on message)

  ## Response Types

  Interaction response types:
  - `1` - PONG (for ping)
  - `4` - CHANNEL_MESSAGE_WITH_SOURCE
  - `5` - DEFERRED_CHANNEL_MESSAGE_WITH_SOURCE
  - `6` - DEFERRED_UPDATE_MESSAGE
  - `7` - UPDATE_MESSAGE
  """

  @type command_option :: %{
          name: String.t(),
          description: String.t(),
          type: integer(),
          required: boolean() | nil,
          choices: list(map()) | nil
        }

  @type command_definition :: %{
          name: String.t(),
          description: String.t(),
          type: integer(),
          options: list(command_option()) | nil
        }

  @doc """
  Returns the command name (used for routing).

  This should match the `name` field in `definition/0`.
  """
  @callback name() :: String.t()

  @doc """
  Returns the command definition for Discord registration.

  The definition should include at minimum:
  - `name` - Command name (1-32 chars, lowercase, no spaces)
  - `description` - Command description (1-100 chars)
  - `type` - Command type (1 for slash commands)

  Optionally:
  - `options` - List of command options/arguments
  """
  @callback definition() :: command_definition()

  @doc """
  Handles the command interaction.

  Called when a user invokes the command. Should respond to the interaction
  using `Nostrum.Api.Interaction.create_response/2`.

  Returns `:ok` on success, `{:error, reason}` on failure.
  """
  @callback handle(Nostrum.Struct.Interaction.t()) :: :ok | {:error, term()}

  @doc """
  Optional callback to check if the command is enabled.
  Defaults to true if not implemented.
  """
  @callback enabled?() :: boolean()

  @optional_callbacks [enabled?: 0]

  @doc """
  Helper to check if a module implements the Command behaviour.
  """
  @spec implements?(module()) :: boolean()
  def implements?(module) do
    behaviours = module.module_info(:attributes)[:behaviour] || []
    __MODULE__ in behaviours
  end
end
