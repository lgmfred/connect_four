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

  @players [:player1, :player2]

  @type status :: :active | :finished | :stopped | :timed_out

  @type state :: %{
          id: binary(),
          status: status(),
          board: Board.t(),
          rules: Rules.t(),
          player1: map(),
          player2: map()
        }

  @doc """
  Start a game and register it with the given name in the registry
  """

  @spec start_link(binary(), keyword()) :: GenServer.on_start()
  def start_link(id, opts) when is_binary(id) do
    GenServer.start_link(__MODULE__, [{:id, id} | opts], name: via_tuple(id))
  end

  @doc """
  Add a player to the given game
  """
  @spec add_player(binary(), binary()) :: :ok | :error
  def add_player(game, name) when is_binary(name) do
    GenServer.call(via_tuple(game), {:add_player, name})
  end

  @doc """
  Drop a token into the given column.
  """
  @spec drop_token(binary(), atom(), non_neg_integer()) ::
          Board.status() | :error | {:error, atom()}
  def drop_token(game, player, col) when player in @players and is_integer(col) do
    GenServer.call(via_tuple(game), {:drop_token, player, col})
  end

  @doc """
  Return the current game state.
  """
  @spec get_state(binary()) :: state()
  def get_state(game) do
    GenServer.call(via_tuple(game), :get_state)
  end

  @impl true
  def init(params) do
    {:ok, params, {:continue, :upsert_to_cache}}
  end

  @impl true
  def handle_continue(:upsert_to_cache, state) do
    game_id = Keyword.fetch!(state, :id)

    state_data =
      case Cache.get(game_id) do
        {:ok, state} -> normalize_state(state)
        {:error, :not_found} -> load_state(game_id, state)
      end

    :ok = Cache.put(game_id, state_data)
    :ok = Store.put(game_id, state_data)
    {:noreply, state_data, @timeout}
  end

  defp load_state(game_id, opts) do
    case Keyword.fetch(opts, :state) do
      {:ok, state} -> normalize_state(state)
      :error -> load_state_from_store(game_id, opts)
    end
  end

  defp load_state_from_store(game_id, opts) do
    case Store.get(game_id) do
      {:ok, state} -> load_stored_state(state, opts)
      {:error, :not_found} -> fresh_state(game_id, Keyword.fetch!(opts, :name))
    end
  end

  defp load_stored_state(state, opts) do
    state = normalize_state(state)

    if state.status == :active do
      state
    else
      fresh_state(state.id, Keyword.fetch!(opts, :name))
    end
  end

  defp fresh_state(id, name) do
    player1 = %{name: name, token: :player1}
    player2 = %{name: nil, token: :player2}

    %{
      id: id,
      status: :active,
      player1: player1,
      player2: player2,
      board: Board.new(),
      rules: Rules.new()
    }
  end

  @impl true
  def handle_call({:add_player, name}, _from, state) do
    with {:ok, rules} <- Rules.check(state.rules, :add_player) do
      state
      |> update_player2_name(name)
      |> update_rules(rules)
      |> reply_success(:ok)
    else
      :error -> reply_error(state, :error)
    end
  end

  def handle_call({:drop_token, player, col}, _from, state) do
    with {:ok, rules} <- Rules.check(state.rules, {:drop_token, player}),
         {:ok, cell} <- Cell.new(0, col),
         {:ok, _actual_cell, win_status, board} <- Board.drop(state.board, cell, player),
         {:ok, rules} <- Rules.check(rules, {:win_check, win_status}) do
      state
      |> update_board(board)
      |> update_rules(rules)
      |> reply_success(win_status)
    else
      :error -> reply_error(state, :error)
      error -> reply_error(state, error)
    end
  end

  def handle_call(:get_state, _from, state) do
    {:reply, state, state, @timeout}
  end

  @impl true
  def handle_info(:timeout, state) do
    Logger.debug("The game: #{state.id} has timed out")
    {:stop, {:shutdown, :timeout}, state}
  end

  @impl true
  def terminate({:shutdown, :timeout}, state) do
    Cache.delete(state.id)
    Store.put(state.id, Map.put(state, :status, :timed_out))
    :ok
  end

  def terminate(:shutdown, _state) do
    :ok
  end

  def terminate(reason, state) do
    Logger.error("Game: #{state.id} terminated for an unknown reason: #{inspect(reason)}")
    :ok
  end

  defp update_player2_name(state, name), do: put_in(state.player2.name, name)

  defp update_board(state, board), do: %{state | board: board}

  defp update_rules(state, rules), do: %{state | rules: rules}

  defp reply_error(state, error), do: {:reply, error, state, @timeout}

  defp reply_success(state, reply) do
    state = update_status(state)

    :ok = Store.put(state.id, state)
    :ok = Cache.put(state.id, state)
    {:reply, reply, state, @timeout}
  end

  defp update_status(%{rules: %Rules{state: :game_over}} = state) do
    %{state | status: :finished}
  end

  defp update_status(state), do: %{state | status: :active}

  defp normalize_state(state), do: Map.put_new(state, :status, :active)
end
