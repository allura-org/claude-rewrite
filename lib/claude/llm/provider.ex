defmodule Claude.LLM.Provider do
  @moduledoc """
  Behaviour for LLM providers.

  Implement this behaviour to add support for new LLM backends.
  Each provider must implement chat completion and configuration validation.

  ## Example Implementation

      defmodule Claude.LLM.Providers.MyProvider do
        @behaviour Claude.LLM.Provider

        @impl true
        def name, do: "My Provider"

        @impl true
        def validate_config do
          if my_api_key_present?() do
            :ok
          else
            {:error, "API key not configured"}
          end
        end

        @impl true
        def chat_completion(messages, options) do
          # Implementation here
          {:ok, "Response text"}
        end
      end
  """

  @type role :: :system | :user | :assistant

  @type text_content :: %{
    type: :text,
    text: String.t()
  }

  @type image_content :: %{
    type: :image_url,
    image_url: %{url: String.t()}
  }

  @type content :: String.t() | list(text_content() | image_content())

  @type message :: %{
    role: role(),
    content: content()
  }

  @type options :: %{
    optional(:model) => String.t(),
    optional(:max_tokens) => pos_integer(),
    optional(:temperature) => float()
  }

  @type response :: {:ok, String.t()} | {:error, term()}

  @doc """
  Returns the human-readable name of this provider.
  """
  @callback name() :: String.t()

  @doc """
  Validates that the provider is properly configured.

  Returns `:ok` if ready to use, or `{:error, reason}` if misconfigured.
  """
  @callback validate_config() :: :ok | {:error, String.t()}

  @doc """
  Performs a chat completion request.

  Takes a list of messages and options, returns the assistant's response text.
  """
  @callback chat_completion(messages :: list(message()), options :: options()) :: response()

  @doc """
  Optional callback to check if the provider supports image inputs.
  Defaults to false if not implemented.
  """
  @callback supports_images?() :: boolean()

  @optional_callbacks [supports_images?: 0]
end
