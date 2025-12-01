defmodule Claude.Commands.Info do
  @moduledoc """
  The /info slash command.

  Displays current bot configuration and status information.
  """

  require Logger

  alias Claude.{Config, LLM}

  @doc """
  Returns the command definition for registration with Discord.
  """
  @spec definition() :: map()
  def definition do
    %{
      name: "info",
      description: "Show bot information and current configuration",
      type: 1  # CHAT_INPUT
    }
  end

  @doc """
  Handles the /info command interaction.
  """
  @spec handle(Nostrum.Struct.Interaction.t()) :: :ok | {:error, term()}
  def handle(interaction) do
    Logger.info("Handling /info command from #{interaction.user.username}")

    embed = build_info_embed()

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
        Logger.error("Failed to respond to /info command: #{inspect(reason)}")
        error
    end
  end

  defp build_info_embed do
    model = Config.model()
    base_url = Config.llm_base_url()
    provider_name = LLM.provider_name()

    %{
      title: "Claude Bot Information",
      description: "A Discord bot powered by AI",
      color: 0x00FF00,  # Green
      fields: [
        %{
          name: "Model",
          value: model,
          inline: true
        },
        %{
          name: "Provider",
          value: provider_name,
          inline: true
        },
        %{
          name: "API Base",
          value: base_url,
          inline: true
        },
        %{
          name: "Status",
          value: "🟢 Online",
          inline: true
        },
        %{
          name: "Rate Limit",
          value: "#{div(Config.rate_limit_ms(), 1000)}s between messages",
          inline: true
        },
        %{
          name: "Context Size",
          value: "#{Config.max_context_messages()} messages",
          inline: true
        }
      ],
      footer: %{
        text: "Made with ❤️ by fizz"
      },
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    }
  end
end
