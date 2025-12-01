defmodule Claude.UserCache do
  @moduledoc """
  ETS-backed cache for Discord user information.

  Caches user data to avoid repeated API calls when formatting messages.
  """

  use GenServer

  require Logger

  @table_name :claude_user_cache

  # Client API

  @doc """
  Starts the user cache GenServer.
  """
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Gets a user from cache or fetches from Discord API if not present.
  """
  @spec get_user(Nostrum.Snowflake.t()) :: {:ok, Nostrum.Struct.User.t()} | {:error, term()}
  def get_user(user_id) do
    case :ets.lookup(@table_name, {:user, user_id}) do
      [{_, user}] ->
        {:ok, user}

      [] ->
        fetch_and_cache_user(user_id)
    end
  end

  @doc """
  Caches a user directly (useful when we already have the user data).
  """
  @spec put_user(Nostrum.Struct.User.t()) :: :ok
  def put_user(%{id: user_id} = user) do
    :ets.insert(@table_name, {{:user, user_id}, user})
    :ok
  end

  @doc """
  Invalidates a cached user.
  """
  @spec invalidate(Nostrum.Snowflake.t()) :: :ok
  def invalidate(user_id) do
    :ets.delete(@table_name, {:user, user_id})
    :ok
  end

  @doc """
  Clears all cached users.
  """
  @spec clear() :: :ok
  def clear do
    :ets.delete_all_objects(@table_name)
    :ok
  end

  # Server Callbacks

  @impl true
  def init(_opts) do
    table = :ets.new(@table_name, [:set, :public, :named_table, read_concurrency: true])
    {:ok, %{table: table}}
  end

  @impl true
  def handle_info(_msg, state) do
    {:noreply, state}
  end

  # Private Functions

  defp fetch_and_cache_user(user_id) do
    case Nostrum.Api.User.get(user_id) do
      {:ok, user} ->
        :ets.insert(@table_name, {{:user, user_id}, user})
        {:ok, user}

      {:error, reason} = error ->
        Logger.warning("Failed to fetch user #{user_id}: #{inspect(reason)}")
        error
    end
  end
end
