defmodule Claude.LLM.Providers.OpenAI do
  @moduledoc """
  OpenAI-compatible API provider.

  Works with OpenAI, Azure OpenAI, and any OpenAI-compatible API
  (like vLLM, text-generation-webui, LocalAI, etc.)
  """

  @behaviour Claude.LLM.Provider

  require Logger

  @default_max_retries 3
  @default_base_delay_ms 1_000

  # Behaviour Implementation

  @impl true
  def name, do: "OpenAI-compatible"

  @impl true
  def validate_config do
    api_key = Claude.Config.llm_api_key()
    base_url = Claude.Config.llm_base_url()

    cond do
      api_key == "" or is_nil(api_key) ->
        {:error, "LLM API key not configured"}

      base_url == "" or is_nil(base_url) ->
        {:error, "LLM base URL not configured"}

      true ->
        :ok
    end
  end

  @impl true
  def supports_images?, do: true

  @impl true
  def chat_completion(messages, options \\ %{}) do
    with :ok <- validate_config() do
      do_chat_completion(messages, options, 0)
    end
  end

  # Private Implementation

  defp do_chat_completion(messages, options, attempt) do
    max_retries = Map.get(options, :max_retries, @default_max_retries)

    payload = build_payload(messages, options)
    headers = build_headers()
    url = build_url()

    Logger.debug("LLM request attempt #{attempt + 1}/#{max_retries} to #{url}")

    case make_request(url, payload, headers) do
      {:ok, response_body} ->
        parse_response(response_body)

      {:error, {:http_error, status, _body}} when status in [400, 401, 403] ->
        # Don't retry client errors
        Logger.error("LLM API client error: HTTP #{status}")
        {:error, {:http_error, status}}

      {:error, reason} when attempt < max_retries - 1 ->
        # Retry with exponential backoff
        delay = calculate_backoff(attempt)
        Logger.warning("LLM API error (attempt #{attempt + 1}), retrying in #{delay}ms: #{inspect(reason)}")
        Process.sleep(delay)
        do_chat_completion(messages, options, attempt + 1)

      {:error, reason} ->
        Logger.error("LLM API failed after #{max_retries} attempts: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp build_payload(messages, options) do
    model = Map.get(options, :model, Claude.Config.model())
    max_tokens = Map.get(options, :max_tokens, Claude.Config.max_tokens())

    payload = %{
      model: model,
      messages: format_messages(messages),
      max_tokens: max_tokens
    }

    # Add optional parameters
    payload
    |> maybe_add(:temperature, options)
    |> maybe_add(:top_p, options)
    |> maybe_add(:presence_penalty, options)
    |> maybe_add(:frequency_penalty, options)
  end

  defp format_messages(messages) do
    Enum.map(messages, fn msg ->
      %{
        role: to_string(msg.role),
        content: format_content(msg.content)
      }
    end)
  end

  defp format_content(content) when is_binary(content), do: content
  defp format_content(content) when is_list(content) do
    Enum.map(content, fn
      %{type: :text, text: text} ->
        %{"type" => "text", "text" => text}

      %{type: :image_url, image_url: %{url: url}} ->
        %{"type" => "image_url", "image_url" => %{"url" => url}}

      other ->
        other
    end)
  end

  defp build_headers do
    api_key = Claude.Config.llm_api_key()
    [
      {"authorization", "Bearer #{api_key}"},
      {"content-type", "application/json"}
    ]
  end

  defp build_url do
    base_url = Claude.Config.llm_base_url()
    "#{String.trim_trailing(base_url, "/")}/chat/completions"
  end

  defp make_request(url, payload, headers) do
    case Req.post(url, json: payload, headers: headers, receive_timeout: 120_000) do
      {:ok, %Req.Response{status: 200, body: body}} ->
        {:ok, body}

      {:ok, %Req.Response{status: status, body: body}} ->
        {:error, {:http_error, status, body}}

      {:error, %Req.TransportError{reason: reason}} ->
        {:error, {:transport_error, reason}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp parse_response(body) when is_map(body) do
    case body do
      %{"choices" => [%{"message" => %{"content" => content}} | _]} ->
        {:ok, content}

      %{"error" => error} ->
        {:error, {:api_error, error}}

      _ ->
        {:error, {:unexpected_response, body}}
    end
  end

  defp parse_response(body) do
    {:error, {:invalid_response, body}}
  end

  defp calculate_backoff(attempt) do
    # Exponential backoff with jitter
    base_delay = @default_base_delay_ms
    max_delay = 30_000

    delay = min(base_delay * :math.pow(2, attempt), max_delay)
    jitter = :rand.uniform(round(delay * 0.1))

    round(delay + jitter)
  end

  defp maybe_add(map, key, options) do
    case Map.get(options, key) do
      nil -> map
      value -> Map.put(map, key, value)
    end
  end
end
