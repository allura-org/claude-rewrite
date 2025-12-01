defmodule Claude.LLM do
  @moduledoc """
  Facade module for LLM provider interactions.

  Routes requests to the configured provider and provides a simple API
  for chat completion operations.

  ## Usage

      # Simple chat
      messages = [
        %{role: :system, content: "You are a helpful assistant."},
        %{role: :user, content: "Hello!"}
      ]

      case Claude.LLM.chat(messages) do
        {:ok, response} -> IO.puts(response)
        {:error, reason} -> IO.puts("Error: \#{inspect(reason)}")
      end

      # With options
      Claude.LLM.chat(messages, %{temperature: 0.7, max_tokens: 500})
  """

  require Logger

  alias Claude.LLM.Provider

  @type message :: Provider.message()
  @type options :: Provider.options()

  @doc """
  Performs a chat completion using the configured provider.

  ## Options

  - `:model` - Override the default model
  - `:max_tokens` - Maximum tokens in response
  - `:temperature` - Sampling temperature (0.0 - 2.0)

  ## Returns

  - `{:ok, response_text}` on success
  - `{:error, reason}` on failure
  """
  @spec chat(list(message()), options()) :: {:ok, String.t()} | {:error, term()}
  def chat(messages, opts \\ %{}) do
    provider = Claude.Config.llm_provider()
    options = merge_default_options(opts)

    Logger.debug("LLM chat request via #{provider.name()}")

    with :ok <- provider.validate_config() do
      provider.chat_completion(messages, options)
    end
  end

  @doc """
  Validates the current LLM configuration.

  Returns `:ok` if the configuration is valid, or `{:error, reason}` otherwise.
  """
  @spec validate_config() :: :ok | {:error, String.t()}
  def validate_config do
    provider = Claude.Config.llm_provider()
    provider.validate_config()
  end

  @doc """
  Returns the name of the currently configured provider.
  """
  @spec provider_name() :: String.t()
  def provider_name do
    provider = Claude.Config.llm_provider()
    provider.name()
  end

  @doc """
  Checks if the current provider supports image inputs.
  """
  @spec supports_images?() :: boolean()
  def supports_images? do
    provider = Claude.Config.llm_provider()

    if function_exported?(provider, :supports_images?, 0) do
      provider.supports_images?()
    else
      false
    end
  end

  @doc """
  Builds a system message.
  """
  @spec system_message(String.t()) :: message()
  def system_message(content) do
    %{role: :system, content: content}
  end

  @doc """
  Builds a user message.
  """
  @spec user_message(String.t()) :: message()
  def user_message(content) do
    %{role: :user, content: content}
  end

  @doc """
  Builds a user message with an image.
  """
  @spec user_message_with_image(String.t(), String.t()) :: message()
  def user_message_with_image(text, image_url) do
    %{
      role: :user,
      content: [
        %{type: :text, text: text},
        %{type: :image_url, image_url: %{url: image_url}}
      ]
    }
  end

  @doc """
  Builds an assistant message.
  """
  @spec assistant_message(String.t()) :: message()
  def assistant_message(content) do
    %{role: :assistant, content: content}
  end

  # Private Functions

  defp merge_default_options(opts) do
    defaults = %{
      model: Claude.Config.model(),
      max_tokens: Claude.Config.max_tokens()
    }

    Map.merge(defaults, opts)
  end
end
