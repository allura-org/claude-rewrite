defmodule Claude.RateLimiter do
  @moduledoc """
  GenServer that manages per-user rate limiting for message processing.

  Tracks the last message time for each user and enforces a configurable
  delay between messages to prevent spam.

  ## Usage

  The recommended way to use the rate limiter is via `check_and_wait/1`:

      case Claude.RateLimiter.check_and_wait(user_id) do
        :ok -> process_message(...)
        {:error, reason} -> handle_error(reason)
      end

  This function checks if the user is rate limited, waits if necessary
  (in the caller's process, not blocking the GenServer), and updates
  the timestamp.

  ## API Functions

  - `check/1` - Check rate limit status without updating (non-blocking)
  - `update/1` - Update the user's timestamp (after successful check)
  - `check_and_wait/1` - Convenience: check, wait if needed, update
  - `time_until_allowed/1` - Get wait time without side effects
  - `clear_user/1` - Reset rate limit for a user
  - `clear_all/0` - Reset all rate limits
  """

  use GenServer

  require Logger

  @type user_id :: Nostrum.Snowflake.t()
  @type check_result :: {:ok, :allowed} | {:ok, {:wait, pos_integer()}}

  # Client API

  @doc """
  Starts the rate limiter GenServer.
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, %{}, name: name)
  end

  @doc """
  Checks if a user can send a message (non-blocking).

  Returns:
  - `{:ok, :allowed}` if the user can proceed immediately
  - `{:ok, {:wait, ms}}` if the user should wait `ms` milliseconds

  This function does NOT update the user's timestamp. Call `update/1` after
  successfully processing the message, or use `check_and_wait/1` for convenience.
  """
  @spec check(user_id()) :: check_result()
  def check(user_id) do
    GenServer.call(__MODULE__, {:check, user_id})
  end

  @doc """
  Updates the user's last message timestamp.

  Call this after successfully processing a rate-limited action.
  """
  @spec update(user_id()) :: :ok
  def update(user_id) do
    GenServer.cast(__MODULE__, {:update, user_id})
  end

  @doc """
  Convenience function that checks rate limit, waits if necessary, and updates timestamp.

  The wait happens in the caller's process, NOT in the GenServer, so other
  users can still be served while one user is waiting.

  Returns:
  - `:ok` after the user is allowed to proceed (may have waited)
  - `{:error, reason}` if something goes wrong
  """
  @spec check_and_wait(user_id()) :: :ok | {:error, term()}
  def check_and_wait(user_id) do
    case check(user_id) do
      {:ok, :allowed} ->
        update(user_id)
        :ok

      {:ok, {:wait, wait_ms}} ->
        Logger.debug("Rate limiting user #{user_id}, waiting #{wait_ms}ms")
        # Sleep in the caller's process, not the GenServer
        Process.sleep(wait_ms)
        update(user_id)
        :ok
    end
  end

  @doc """
  Legacy API: Checks and updates in one call.

  Deprecated: Use `check_and_wait/1` instead for non-blocking behavior.
  This function is kept for backwards compatibility but now delegates
  to `check_and_wait/1`.
  """
  @deprecated "Use check_and_wait/1 instead"
  @spec check_and_update(user_id()) :: {:ok, non_neg_integer()} | {:error, term()}
  def check_and_update(user_id) do
    case check(user_id) do
      {:ok, :allowed} ->
        update(user_id)
        {:ok, 0}

      {:ok, {:wait, wait_ms}} ->
        Logger.debug("Rate limiting user #{user_id}, waiting #{wait_ms}ms")
        Process.sleep(wait_ms)
        update(user_id)
        {:ok, wait_ms}
    end
  end

  @doc """
  Checks how long a user must wait before sending another message.
  Does not update the timestamp.

  Returns the number of milliseconds to wait (0 if can proceed immediately).
  """
  @spec time_until_allowed(user_id()) :: non_neg_integer()
  def time_until_allowed(user_id) do
    case check(user_id) do
      {:ok, :allowed} -> 0
      {:ok, {:wait, ms}} -> ms
    end
  end

  @doc """
  Clears rate limit data for a specific user.
  """
  @spec clear_user(user_id()) :: :ok
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
  def handle_call({:check, user_id}, _from, state) do
    rate_limit_ms = Claude.Config.rate_limit_ms()
    current_time = System.monotonic_time(:millisecond)

    result =
      case Map.get(state.user_times, user_id) do
        nil ->
          # First message from this user
          {:ok, :allowed}

        last_time ->
          elapsed = current_time - last_time

          if elapsed >= rate_limit_ms do
            {:ok, :allowed}
          else
            wait_time = rate_limit_ms - elapsed
            {:ok, {:wait, wait_time}}
          end
      end

    {:reply, result, state}
  end

  @impl true
  def handle_cast({:update, user_id}, state) do
    current_time = System.monotonic_time(:millisecond)
    new_state = put_in(state.user_times[user_id], current_time)
    {:noreply, new_state}
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
