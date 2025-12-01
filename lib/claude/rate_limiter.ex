defmodule Claude.RateLimiter do
  @moduledoc """
  GenServer that manages per-user rate limiting for message processing.

  Tracks the last message time for each user and enforces a configurable
  delay between messages to prevent spam.
  """

  use GenServer

  require Logger

  # Client API

  @doc """
  Starts the rate limiter GenServer.
  """
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, %{}, name: name)
  end

  @doc """
  Checks if a user can send a message and updates their last message time.

  Returns:
  - `{:ok, 0}` if the user can proceed immediately
  - `{:ok, wait_ms}` if the user should wait (also waits internally)
  - `{:error, reason}` if something goes wrong
  """
  @spec check_and_update(Nostrum.Snowflake.t()) :: {:ok, non_neg_integer()} | {:error, term()}
  def check_and_update(user_id) do
    GenServer.call(__MODULE__, {:check_and_update, user_id})
  end

  @doc """
  Checks how long a user must wait before sending another message.
  Does not update the timestamp.

  Returns the number of milliseconds to wait (0 if can proceed immediately).
  """
  @spec time_until_allowed(Nostrum.Snowflake.t()) :: non_neg_integer()
  def time_until_allowed(user_id) do
    GenServer.call(__MODULE__, {:time_until_allowed, user_id})
  end

  @doc """
  Clears rate limit data for a specific user.
  """
  @spec clear_user(Nostrum.Snowflake.t()) :: :ok
  def clear_user(user_id) do
    GenServer.cast(__MODULE__, {:clear_user, user_id})
  end

  @doc """
  Clears all rate limit data.
  """
  @spec clear_all() :: :ok
  def clear_all do
    GenServer.cast(__MODULE__, :clear_all)
  end

  # Server Callbacks

  @impl true
  def init(_opts) do
    {:ok, %{user_times: %{}}}
  end

  @impl true
  def handle_call({:check_and_update, user_id}, _from, state) do
    rate_limit_ms = Claude.Config.rate_limit_ms()
    current_time = System.monotonic_time(:millisecond)

    case Map.get(state.user_times, user_id) do
      nil ->
        # First message from this user
        new_state = put_in(state.user_times[user_id], current_time)
        {:reply, {:ok, 0}, new_state}

      last_time ->
        elapsed = current_time - last_time

        if elapsed >= rate_limit_ms do
          # Enough time has passed
          new_state = put_in(state.user_times[user_id], current_time)
          {:reply, {:ok, 0}, new_state}
        else
          # Need to wait
          wait_time = rate_limit_ms - elapsed
          Logger.debug("Rate limiting user #{user_id}, waiting #{wait_time}ms")

          # Sleep for the required time
          Process.sleep(wait_time)

          # Update the timestamp after waiting
          new_current_time = System.monotonic_time(:millisecond)
          new_state = put_in(state.user_times[user_id], new_current_time)
          {:reply, {:ok, wait_time}, new_state}
        end
    end
  end

  @impl true
  def handle_call({:time_until_allowed, user_id}, _from, state) do
    rate_limit_ms = Claude.Config.rate_limit_ms()
    current_time = System.monotonic_time(:millisecond)

    wait_time =
      case Map.get(state.user_times, user_id) do
        nil -> 0
        last_time ->
          elapsed = current_time - last_time
          max(0, rate_limit_ms - elapsed)
      end

    {:reply, wait_time, state}
  end

  @impl true
  def handle_cast({:clear_user, user_id}, state) do
    new_state = update_in(state.user_times, &Map.delete(&1, user_id))
    {:noreply, new_state}
  end

  @impl true
  def handle_cast(:clear_all, state) do
    {:noreply, %{state | user_times: %{}}}
  end
end
