defmodule ConnectFour.Game do
  use GenServer, restart: :transient

  alias ConnectFour.Cell
  alias ConnectFour.Board
  alias ConnectFour.Rules

  @players [:player1, :player2]

  @type state :: %{board: Board.t(), rules: Rules.t(), player1: map(), player2: map()}

  @doc """
  Start a game and register it with the given name in the registry
  """

  @spec start_link(binary(), keyword()) :: GenServer.on_start()
  def start_link(id, opts) when is_binary(id) do
    GenServer.start_link(__MODULE__, opts, name: via_tuple(id))
  end

  @doc """
  Add a player to the given game
  """
  @spec add_player(binary(), binary()) :: :ok | :error
  def add_player(game, name) when is_binary(name) do
    GenServer.call(via_tuple(game), {:add_player, name})
  end

  @doc """
  Drop a token in the given row and column
  """
  @spec drop_token(binary(), atom(), non_neg_integer(), non_neg_integer()) ::
          {:reply, term(), state()}
  def drop_token(game, player, row, col) when player in @players and is_integer(col) do
    GenServer.call(via_tuple(game), {:drop_token, player, row, col})
  end

  @impl true
  def init(params) do
    player1 = %{name: Keyword.fetch!(params, :name), token: :player1}
    player2 = %{name: nil, token: :player2}
    state = %{player1: player1, player2: player2, board: Board.new(), rules: Rules.new()}
    {:ok, state}
  end

  @impl true
  def handle_call({:add_player, name}, _from, state) do
    with {:ok, rules} <- Rules.check(state.rules, :add_player) do
      state
      |> update_player2_name(name)
      |> update_rules(rules)
      |> reply_success(:ok)
    else
      :error -> {:reply, :error, state}
    end
  end

  def handle_call({:drop_token, player, row, col}, _from, state) do
    with {:ok, rules} <- Rules.check(state.rules, {:drop_token, player}),
         {:ok, cell} <- Cell.new(row, col),
         {:ok, _actual_cell, win_status, board} <- Board.drop(state.board, cell, player),
         {:ok, rules} <- Rules.check(rules, {:win_check, win_status}) do
      state
      |> update_board(board)
      |> update_rules(rules)
      |> reply_success(win_status)
    else
      :error -> {:reply, :error, state}
      error -> {:reply, error, state}
    end
  end

  defp update_player2_name(state, name), do: put_in(state.player2.name, name)

  defp update_board(state, board), do: %{state | board: board}

  defp update_rules(state, rules), do: %{state | rules: rules}

  defp reply_success(state, reply), do: {:reply, reply, state}

  def via_tuple(name), do: {:via, Registry, {ConnectFour.Registry, name}}
end
