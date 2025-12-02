defmodule Claude.Commands.Help do
  @moduledoc """
  The /help slash command.

  Displays help information about the bot's features and usage.
  """

  @behaviour Claude.Commands.Command

  require Logger

  @impl Claude.Commands.Command
  def name, do: "help"

  @impl Claude.Commands.Command
  def definition do
    %{
      name: "help",
      description: "Show help information about how to use the bot",
      type: 1  # CHAT_INPUT
    }
  end

  @impl Claude.Commands.Command
  def handle(interaction) do
    Logger.info("Handling /help command from #{interaction.user.username}")

    embed = build_help_embed()

    response = %{
      type: 4,  # CHANNEL_MESSAGE_WITH_SOURCE
      data: %{
        embeds: [embed]
      }
    }

    case Nostrum.Api.Interaction.create_response(interaction, response) do
      {:ok, _} -> :ok
      :ok -> :ok
      {:error, reason} = error ->
        Logger.error("Failed to respond to /help command: #{inspect(reason)}")
        error
    end
  end

  defp build_help_embed do
    %{
      title: "Claude Bot Help",
      description: "How to use this bot",
      color: 0x0099FF,  # Blue
      fields: [
        %{
          name: "💬 Chat with Claude",
          value: "Just mention me in any message and I'll respond! I can see message history for context.",
          inline: false
        },
        %{
          name: "🖼️ Image Support",
          value: "Attach an image to your message when mentioning me, and I'll be able to see and discuss it.",
          inline: false
        },
        %{
          name: "📝 Clear History",
          value: "Send `[DO NOT COUNT PAST THIS MESSAGE]` to clear conversation history from that point forward.",
          inline: false
        },
        %{
          name: "⚙️ Bot Info",
          value: "Use `/info` to see current configuration and status.",
          inline: false
        },
        %{
          name: "❓ Commands",
          value: """
          `/help` - Show this help message
          `/info` - Show bot configuration and status
          """,
          inline: false
        }
      ],
      footer: %{
        text: "Rate limit: Messages are throttled to prevent spam"
      },
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    }
  end
end
