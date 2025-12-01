defmodule Claude.MemberCache do
  @moduledoc """
  ETS-backed cache for Discord guild member information.

  Caches member data (which includes nicknames) to avoid repeated API calls.
  Uses a composite key of {guild_id, user_id} since members are guild-specific.
  """

  use GenServer

  require Logger

  @table_name :claude_member_cache

  # Client API

  @doc """
  Starts the member cache GenServer.
  """
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Gets a member from cache or fetches from Discord API if not present.
  """
  @spec get_member(Nostrum.Snowflake.t(), Nostrum.Snowflake.t()) ::
    {:ok, Nostrum.Struct.Guild.Member.t()} | {:error, term()}
  def get_member(guild_id, user_id) do
    case :ets.lookup(@table_name, {:member, guild_id, user_id}) do
      [{_, member}] ->
        {:ok, member}

      [] ->
        fetch_and_cache_member(guild_id, user_id)
    end
  end

  @doc """
  Caches a member directly (useful when we already have the member data).
  """
  @spec put_member(Nostrum.Snowflake.t(), Nostrum.Struct.Guild.Member.t()) :: :ok
  def put_member(guild_id, %{user_id: user_id} = member) do
    :ets.insert(@table_name, {{:member, guild_id, user_id}, member})
    :ok
  end

  @doc """
  Invalidates a cached member.
  """
  @spec invalidate(Nostrum.Snowflake.t(), Nostrum.Snowflake.t()) :: :ok
  def invalidate(guild_id, user_id) do
    :ets.delete(@table_name, {:member, guild_id, user_id})
    :ok
  end

  @doc """
  Invalidates all cached members for a guild.
  """
  @spec invalidate_guild(Nostrum.Snowflake.t()) :: :ok
  def invalidate_guild(guild_id) do
    :ets.match_delete(@table_name, {{:member, guild_id, :_}, :_})
    :ok
  end

  @doc """
  Clears all cached members.
  """
  @spec clear() :: :ok
  def clear do
    :ets.delete_all_objects(@table_name)
    :ok
  end

  @doc """
  Gets the display name for a member (nickname if present, otherwise username).
  """
  @spec get_display_name(Nostrum.Snowflake.t(), Nostrum.Snowflake.t()) ::
    {:ok, String.t()} | {:error, term()}
  def get_display_name(guild_id, user_id) do
    case get_member(guild_id, user_id) do
      {:ok, member} ->
        display_name = member.nick || get_username_fallback(user_id)
        {:ok, display_name}

      {:error, _} = error ->
        error
    end
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

  defp fetch_and_cache_member(guild_id, user_id) do
    case Nostrum.Api.Guild.member(guild_id, user_id) do
      {:ok, member} ->
        :ets.insert(@table_name, {{:member, guild_id, user_id}, member})
        {:ok, member}

      {:error, reason} = error ->
        Logger.warning("Failed to fetch member #{user_id} in guild #{guild_id}: #{inspect(reason)}")
        error
    end
  end

  defp get_username_fallback(user_id) do
    case Claude.UserCache.get_user(user_id) do
      {:ok, user} -> user.username
      {:error, _} -> "Unknown User"
    end
  end
end
