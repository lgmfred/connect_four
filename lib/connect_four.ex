defmodule ConnectFour do
  @moduledoc """
  Public API for creating and playing Connect Four games.

  ## Examples

      iex> {:ok, _apps} = Application.ensure_all_started(:connect_four)
      iex> game_id = "public-api-doctest"
      iex> {:ok, pid} = ConnectFour.create_game(game_id, "Player 1")
      iex> Process.alive?(pid)
      true
      iex> ConnectFour.join_game(game_id, "Player 2")
      :ok
      iex> ConnectFour.drop_token(game_id, :player1, 3)
      :no_win
      iex> state = ConnectFour.get_state(game_id)
      iex> state.player1.name
      "Player 1"
      iex> state.player2.name
      "Player 2"
      iex> state.board |> Enum.at(5) |> Enum.at(3)
      :player1
      iex> ConnectFour.stop_game(game_id)
      :ok
  """

  alias ConnectFour.Game
  alias ConnectFour.GameSupervisor

  @type game_id :: binary()
  @type player :: :player1 | :player2

  @doc """
  Create a new game with the first player.
  """
  @spec create_game(game_id(), binary()) :: Supervisor.on_start_child()
  def create_game(game_id, player_name)
      when is_binary(game_id) and is_binary(player_name) do
    GameSupervisor.spawn_game(game_id, name: player_name)
  end

  @doc """
  Join an existing game as the second player.
  """
  @spec join_game(game_id(), binary()) :: :ok | :error
  def join_game(game_id, player_name)
      when is_binary(game_id) and is_binary(player_name) do
    Game.add_player(game_id, player_name)
  end

  @doc """
  Drop a token into a column.
  """
  @spec drop_token(game_id(), player(), non_neg_integer()) ::
          ConnectFour.Board.status() | :error | {:error, atom()}
  def drop_token(game_id, player, column) do
    Game.drop_token(game_id, player, column)
  end

  @doc """
  Return the current game state.
  """
  @spec get_state(game_id()) :: Game.state()
  def get_state(game_id) when is_binary(game_id) do
    Game.get_state(game_id)
  end

  @doc """
  Stop a running game and remove it from the runtime cache.
  """
  @spec stop_game(game_id()) :: :ok
  def stop_game(game_id) when is_binary(game_id) do
    GameSupervisor.stop_game(game_id)
  end
end
