defmodule Claude.MessageHandler do
  @moduledoc """
  Handles message processing and AI response generation.

  This module is responsible for:
  - Processing messages that mention the bot
  - Building context from channel history
  - Calling the LLM API
  - Sending responses back to Discord
  """

  require Logger

  alias Claude.{Config, LLM, RateLimiter, Utils}
  alias Nostrum.Api

  @doc """
  Processes a guild message that mentions the bot.

  This is the main entry point for message handling.
  """
  @spec handle_message(Nostrum.Struct.Message.t()) :: :ok | {:error, term()}
  def handle_message(message) do
    with :ok <- validate_message(message),
         :ok <- RateLimiter.check_and_wait(message.author.id) do
      process_message(message)
    else
      {:error, :invalid_message} ->
        Logger.debug("Skipping invalid message")
        :ok

      {:error, reason} ->
        Logger.warning("Failed to handle message: #{inspect(reason)}")
        {:error, reason}
    end
  end

  # Private Implementation

  defp validate_message(message) do
    cond do
      Utils.from_bot?(message) ->
        {:error, :invalid_message}

      not Utils.guild_message?(message) ->
        {:error, :invalid_message}

      not Utils.bot_mentioned?(message) ->
        {:error, :invalid_message}

      is_nil(message.content) and empty_attachments?(message) ->
        {:error, :invalid_message}

      true ->
        :ok
    end
  end

  defp empty_attachments?(%{attachments: []}), do: true
  defp empty_attachments?(%{attachments: nil}), do: true
  defp empty_attachments?(_), do: false

  defp process_message(message) do
    guild_id = message.guild_id
    channel_id = message.channel_id

    Logger.info("Processing message from #{message.author.username} in channel #{channel_id}")

    # Start typing indicator in background
    typing_task = start_typing_indicator(channel_id)

    try do
      result = do_process_message(message, guild_id, channel_id)
      result
    after
      # Always stop typing indicator
      stop_typing_indicator(typing_task)
    end
  end

  defp do_process_message(message, guild_id, channel_id) do
    with {:ok, channel_info} <- Utils.get_channel_info(channel_id, guild_id),
         message_history <- build_message_history(channel_id, message.id, guild_id),
         context <- Utils.build_channel_context(channel_info, message_history, message, guild_id),
         image_url <- Utils.extract_image_url(message),
         messages <- build_llm_messages(context, image_url),
         {:ok, response} <- LLM.chat(messages) do
      send_response(message, response)
    else
      {:error, reason} ->
        Logger.error("Error processing message: #{inspect(reason)}")
        send_error_response(message, reason)
        {:error, reason}
    end
  end

  defp build_message_history(channel_id, current_message_id, guild_id) do
    channel_id
    |> Utils.get_channel_history(current_message_id, Config.max_context_messages())
    |> Enum.map(&Utils.format_message(&1, guild_id))
  end

  defp build_llm_messages(context, nil) do
    [
      LLM.system_message(Config.system_prompt()),
      LLM.user_message(context)
    ]
  end

  defp build_llm_messages(context, image_url) do
    [
      LLM.system_message(Config.system_prompt()),
      LLM.user_message_with_image(context, image_url)
    ]
  end

  defp send_response(original_message, response) do
    # Split response by newlines as in the Python version
    lines = String.split(response, "\n", trim: true)

    case lines do
      [] ->
        Logger.warning("Empty response from LLM")
        :ok

      [first_line | rest_lines] ->
        # First line is a reply to the original message
        send_reply(original_message, first_line)

        # Subsequent lines are regular messages
        Enum.each(rest_lines, fn line ->
          if String.trim(line) != "" do
            Process.sleep(100)  # Small delay between messages
            send_message(original_message.channel_id, String.trim(line))
          end
        end)

        :ok
    end
  end

  defp send_reply(message, content) do
    case Api.Message.create(message.channel_id, %{
      content: content,
      message_reference: %{message_id: message.id}
    }) do
      {:ok, _} -> :ok
      {:error, reason} ->
        Logger.error("Failed to send reply: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp send_message(channel_id, content) do
    case Api.Message.create(channel_id, content) do
      {:ok, _} -> :ok
      {:error, reason} ->
        Logger.error("Failed to send message: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp send_error_response(message, reason) do
    error_content = case reason do
      {:http_error, _} -> "Sorry, I couldn't connect to the AI service :c"
      {:transport_error, _} -> "Sorry, I couldn't connect to the AI service :c"
      {:api_error, _} -> "Sorry, something went wrong with the AI service :c"
      _ -> "An unexpected error occurred :c"
    end

    send_reply(message, error_content)
  end

  # Typing Indicator

  defp start_typing_indicator(channel_id) do
    Task.async(fn ->
      typing_loop(channel_id)
    end)
  end

  defp stop_typing_indicator(task) do
    Task.shutdown(task, :brutal_kill)
  end

  defp typing_loop(channel_id) do
    case Api.Channel.start_typing(channel_id) do
      :ok -> :ok
      {:error, reason} ->
        Logger.warning("Failed to trigger typing indicator: #{inspect(reason)}")
    end

    # Typing indicator lasts about 10 seconds, refresh every 5
    Process.sleep(5_000)
    typing_loop(channel_id)
  end
end
