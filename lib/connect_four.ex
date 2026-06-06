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
      iex> Enum.any?(ConnectFour.list_games(), &(&1.id == game_id and &1.status == :stopped))
      true
  """

  alias ConnectFour.Cache
  alias ConnectFour.Game
  alias ConnectFour.GameSupervisor
  alias ConnectFour.Store

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
  Return an active game from the runtime cache.

  This is the spectator-friendly read path. It is eventually consistent with
  player commands because game processes update the cache asynchronously.
  """
  @spec get_game(game_id()) :: {:ok, Game.state()} | {:error, :not_found}
  def get_game(game_id) when is_binary(game_id) do
    Cache.get(game_id)
  end

  @doc """
  Return active games from the runtime cache.

  This is the spectator-friendly read path. It is eventually consistent with
  player commands because game processes update the cache asynchronously.
  """
  @spec list_active_games() :: [Game.state()]
  def list_active_games do
    Cache.get_all()
  end

  @doc """
  Return all persisted game records.
  """
  @spec list_games() :: [Game.state()]
  def list_games do
    Store.all()
  end

  @doc """
  Stop a running game and remove it from the runtime cache.

  The stopped game remains in durable storage for history and stats.
  """
  @spec stop_game(game_id()) :: :ok
  def stop_game(game_id) when is_binary(game_id) do
    GameSupervisor.stop_game(game_id)
  end
end
