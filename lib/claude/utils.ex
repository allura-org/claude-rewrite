defmodule Claude.Utils do
  @moduledoc """
  Utility functions for the Claude Discord bot.

  Provides helpers for message formatting, channel history fetching,
  and context building.
  """

  require Logger

  @history_cutoff_marker "[DO NOT COUNT PAST THIS MESSAGE]"

  @doc """
  Formats a Discord message into a JSON-encodable map for context.
  """
  @spec format_message(Nostrum.Struct.Message.t(), Nostrum.Snowflake.t()) :: map()
  def format_message(message, guild_id) do
    nickname = get_member_nickname(guild_id, message.author.id)
    content = replace_mentions_with_usernames(message.content || "", message)

    %{
      username: message.author.username,
      nickname: nickname,
      content: content,
      timestamp: DateTime.to_iso8601(message.timestamp),
      has_image: has_attachments?(message),
      id: to_string(message.id),
      reply_to: get_reply_id(message),
      mentions: get_mention_ids(message)
    }
  end

  @doc """
  Builds the full channel context string for the LLM.
  """
  @spec build_channel_context(
    channel_info :: map(),
    message_history :: list(map()),
    current_message :: Nostrum.Struct.Message.t(),
    guild_id :: Nostrum.Snowflake.t()
  ) :: String.t()
  def build_channel_context(channel_info, message_history, current_message, guild_id) do
    channel_json = Jason.encode!(channel_info, pretty: true)
    history_text = format_history(message_history)
    current_time = DateTime.utc_now() |> DateTime.to_iso8601()
    current_msg_json = format_current_message(current_message, guild_id)

    """
    Channel Info:
    #{channel_json}
    Channel History (Oldest to Newest, displayed in JSON for clarity):
    #{history_text}
    ---
    The current time is #{current_time}.
    Please respond to this message as Claude (use plaintext. do not use JSON, that is only for clarity): #{current_msg_json}
    """
  end

  @doc """
  Fetches channel history using the Discord REST API.

  Returns messages in reverse chronological order (newest first).
  Stops at the history cutoff marker if found.
  """
  @spec get_channel_history(Nostrum.Snowflake.t(), Nostrum.Snowflake.t(), pos_integer()) ::
    list(Nostrum.Struct.Message.t())
  def get_channel_history(channel_id, current_message_id, limit \\ 50) do
    # Fetch messages before the current message using the REST API
    case Nostrum.Api.Channel.messages(channel_id, limit, {:before, current_message_id}) do
      {:ok, messages} ->
        # Messages come in reverse chronological order (newest first)
        # Stop at cutoff marker if present
        take_until_cutoff(messages, [])

      {:error, reason} ->
        Logger.warning("Failed to fetch channel history: #{inspect(reason)}")
        []
    end
  end

  @doc """
  Gets channel information for context.
  """
  @spec get_channel_info(Nostrum.Snowflake.t(), Nostrum.Snowflake.t()) ::
    {:ok, map()} | {:error, term()}
  def get_channel_info(channel_id, _guild_id) do
    case Nostrum.Api.Channel.get(channel_id) do
      {:ok, channel} ->
        {:ok, %{
          name: channel.name,
          nsfw: Map.get(channel, :nsfw, false)
        }}

      {:error, reason} ->
        Logger.warning("Failed to fetch channel #{channel_id}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Extracts an image URL from message attachments.

  Returns the first image attachment as a base64 data URL, or nil if none.
  """
  @spec extract_image_url(Nostrum.Struct.Message.t()) :: String.t() | nil
  def extract_image_url(%{attachments: attachments}) when is_list(attachments) do
    attachments
    |> Enum.find(&is_image_attachment?/1)
    |> case do
      nil -> nil
      attachment -> attachment.url
    end
  end
  def extract_image_url(_), do: nil

  @doc """
  Checks if the bot is mentioned in a message.
  """
  @spec bot_mentioned?(Nostrum.Struct.Message.t()) :: boolean()
  def bot_mentioned?(message) do
    bot_id = Claude.Config.bot_user_id()

    cond do
      is_nil(bot_id) -> false
      is_nil(message.mentions) -> false
      true -> Enum.any?(message.mentions, fn user -> user.id == bot_id end)
    end
  end

  @doc """
  Checks if a message is from a bot.
  """
  @spec from_bot?(Nostrum.Struct.Message.t()) :: boolean()
  def from_bot?(%{author: %{bot: true}}), do: true
  def from_bot?(_), do: false

  @doc """
  Checks if a message is from a guild (not a DM).
  """
  @spec guild_message?(Nostrum.Struct.Message.t()) :: boolean()
  def guild_message?(%{guild_id: nil}), do: false
  def guild_message?(%{guild_id: _}), do: true
  def guild_message?(_), do: false

  # Private Functions

  defp get_member_nickname(guild_id, user_id) do
    case Claude.MemberCache.get_display_name(guild_id, user_id) do
      {:ok, name} -> name
      {:error, _} -> nil
    end
  end

  defp replace_mentions_with_usernames(content, message) do
    mentions = message.mentions || []

    Enum.reduce(mentions, content, fn user, acc ->
      String.replace(acc, "<@#{user.id}>", "<@#{user.username}>")
      |> String.replace("<@!#{user.id}>", "<@#{user.username}>")
    end)
  end

  defp has_attachments?(%{attachments: attachments}) when is_list(attachments),
    do: length(attachments) > 0
  defp has_attachments?(_), do: false

  defp get_reply_id(%{message_reference: %{message_id: id}}) when not is_nil(id),
    do: to_string(id)
  defp get_reply_id(_), do: nil

  defp get_mention_ids(%{mentions: mentions}) when is_list(mentions),
    do: Enum.map(mentions, & &1.id)
  defp get_mention_ids(_), do: []

  defp format_history(messages) do
    messages
    |> Enum.reverse()  # Convert to chronological order
    |> Enum.map(&Jason.encode!/1)
    |> Enum.join("\n")
  end

  defp format_current_message(message, guild_id) do
    nickname = get_member_nickname(guild_id, message.author.id)

    %{
      username: message.author.username,
      nickname: nickname,
      content: message.content || "",
      timestamp: DateTime.to_iso8601(message.timestamp),
      has_image: has_attachments?(message),
      id: to_string(message.id),
      reply_to: get_reply_id(message),
      mentions: get_mention_ids(message)
    }
    |> Jason.encode!(pretty: true)
  end

  defp take_until_cutoff([], acc), do: Enum.reverse(acc)
  defp take_until_cutoff([msg | rest], acc) do
    if msg.content == @history_cutoff_marker do
      Enum.reverse(acc)
    else
      take_until_cutoff(rest, [msg | acc])
    end
  end

  defp is_image_attachment?(%{content_type: content_type}) when is_binary(content_type) do
    String.starts_with?(content_type, "image/")
  end
  defp is_image_attachment?(_), do: false
end
