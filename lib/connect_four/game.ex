defmodule ConnectFour.Game do
  use GenServer, restart: :transient

  require Logger

  import ConnectFour.Registry, only: [via_tuple: 1]

  alias ConnectFour.Cell
  alias ConnectFour.Board
  alias ConnectFour.Rules
  alias ConnectFour.Cache
  alias ConnectFour.Store

  @timeout :timer.minutes(5)
  @callback_timeout :timer.minutes(1)
  @colors [:red, :yellow, :blue, :green, :purple, :orange]

  @type player :: :player1 | :player2
  @type status :: :active | :finished | :stopped | :timed_out
  @type outcome :: :in_progress | :no_result | :draw | {:win, player()}
  @type ended_reason :: :completed | :stopped | :timed_out | nil

  @type state :: %{
          id: binary(),
          status: status(),
          outcome: outcome(),
          ended_reason: ended_reason(),
          started_at: DateTime.t(),
          ended_at: DateTime.t() | nil,
          board: Board.t(),
          rules: Rules.t(),
          player1: map(),
          player2: map()
        }

  @doc """
  Start a game and register it with the given name in the registry
  """

  @spec start_link(binary(), keyword()) :: GenServer.on_start()
  def start_link(id, opts) do
    GenServer.start_link(__MODULE__, [{:id, id} | opts], name: via_tuple(id))
  end

  @doc """
  Add a player to the given game
  """
  @spec add_player(binary(), binary(), atom()) :: :ok | :error
  def add_player(game_id, name, color) when color in @colors do
    GenServer.call(via_tuple(game_id), {:add_player, name, color}, @callback_timeout)
  end

  @doc """
  Drop a token into the given column.
  """
  @spec drop_token(binary(), atom(), non_neg_integer()) ::
          Board.status() | :error | {:error, atom()}
  def drop_token(game_id, player, col) do
    GenServer.call(via_tuple(game_id), {:drop_token, player, col}, @callback_timeout)
  end

  @doc """
  Return the current game state.
  """
  @spec get_state(binary()) :: state()
  def get_state(game_id) do
    GenServer.call(via_tuple(game_id), :get_state, @callback_timeout)
  end

  @doc """
  Mark a live game process as stopped.
  """
  @spec stop(binary()) :: :ok
  def stop(game_id) do
    GenServer.call(via_tuple(game_id), :stop, @callback_timeout)
  end

  @impl true
  def init(id: id, state: %{id: id} = state) do
    {:ok, state, {:continue, :upsert_to_cache}}
  end

  def init([id: _id, name: _name, color: _color] = params) do
    {:ok, fresh_state(params), {:continue, :upsert_to_cache}}
  end

  @impl true
  def handle_continue(:upsert_to_cache, %{id: id} = state) do
    :ok = Cache.put(id, state)
    {:noreply, state, @timeout}
  end

  @impl true
  def handle_call({:add_player, name, color}, _from, state) do
    case Rules.check(state.rules, :add_player) do
      {:ok, rules} ->
        state
        |> update_player2(name, color)
        |> update_rules(rules)
        |> reply_success(:ok)

      :error ->
        reply_error(state, :error)
    end
  end

  def handle_call({:drop_token, player, col}, _from, state) do
    with {:ok, rules} <- Rules.check(state.rules, {:drop_token, player}),
         {:ok, cell} <- Cell.new(0, col),
         {:ok, actual_cell, win_status, board} <- Board.drop(state.board, cell, player),
         ## Maybe let's crash here, shall we?
         :ok <- maybe_crash_on_cell(actual_cell, player),
         {:ok, rules} <- Rules.check(rules, {:win_check, win_status}) do
      state
      |> update_board(board)
      |> update_rules(rules)
      |> apply_move_result(win_status, player)
      |> reply_success(win_status)
    else
      :error -> reply_error(state, :error)
      error -> reply_error(state, error)
    end
  end

  def handle_call(:get_state, _from, state) do
    {:reply, state, state, @timeout}
  end

  def handle_call(:stop, _from, state) do
    {:stop, {:shutdown, :stopped}, :ok, state}
  end

  @impl true
  def handle_info(:timeout, %{status: :finished} = state) do
    Logger.debug("The finished game: #{state.id} with PID: #{inspect(self())} has been retired")
    {:stop, :normal, state}
  end

  def handle_info(:timeout, state) do
    Logger.debug("The game: #{state.id} with PID: #{inspect(self())} has timed out")
    {:stop, {:shutdown, :timeout}, state}
  end

  @impl true
  def terminate({:shutdown, :stopped} = reason, state) do
    state = end_state(state, :stopped, :stopped)

    Store.put(state.id, state)
    Cache.delete(state.id)

    reason
  end

  def terminate({:shutdown, :timeout} = reason, state) do
    state = end_state(state, :timed_out, :timed_out)

    Store.put(state.id, state)
    Cache.delete(state.id)

    reason
  end

  def terminate(:normal, state) do
    Cache.delete(state.id)
    :ok
  end

  def terminate(reason, state) do
    Logger.error(
      "Game: #{state.id} with PID: #{inspect(self())} terminated for an unknown reason: #{inspect(reason)}"
    )

    :ok
  end

  defp fresh_state(params) when is_list(params) do
    id = Keyword.fetch!(params, :id)
    name = Keyword.fetch!(params, :name)
    color = Keyword.get(params, :color, :red)

    player1 = %{name: name, color: color, token: :player1}
    player2 = %{name: nil, color: nil, token: :player2}

    %{
      id: id,
      status: :active,
      outcome: :in_progress,
      ended_reason: nil,
      started_at: DateTime.utc_now(:second),
      ended_at: nil,
      player1: player1,
      player2: player2,
      board: Board.new(),
      rules: Rules.new()
    }
  end

  defp update_player2(state, name, color) do
    state
    |> put_in([:player2, :name], name)
    |> put_in([:player2, :color], color)
  end

  defp update_rules(state, rules), do: %{state | rules: rules}

  defp update_board(state, board), do: %{state | board: board}

  defp reply_success(state, reply) do
    :ok = Store.put(state.id, state)
    {:reply, reply, state, {:continue, :upsert_to_cache}}
  end

  defp reply_error(state, error), do: {:reply, error, state, @timeout}

  defp maybe_crash_on_cell(%Cell{row: 4, col: 6}, :player2) do
    raise "Deliberate crash when :player2 drops a token on cell row=4 col=6"
  end

  defp maybe_crash_on_cell(_cell, _player), do: :ok

  defp apply_move_result(state, :draw, _player) do
    state
    |> Map.put(:outcome, :draw)
    |> end_state(:finished, :completed)
  end

  defp apply_move_result(state, :win, player) do
    state
    |> Map.put(:outcome, {:win, player})
    |> end_state(:finished, :completed)
  end

  defp apply_move_result(state, :no_win, _player), do: state

  defp end_state(state, status, ended_reason) do
    state
    |> Map.put(:status, status)
    |> Map.put(:ended_reason, ended_reason)
    |> Map.put(:ended_at, DateTime.utc_now(:second))
    |> update_outcome()
  end

  defp update_outcome(%{outcome: :in_progress} = state) do
    %{state | outcome: :no_result}
  end

  defp update_outcome(state), do: state
end
