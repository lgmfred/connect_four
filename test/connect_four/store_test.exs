defmodule ConnectFour.StoreTest do
  use ExUnit.Case, async: false

  alias ConnectFour.Board
  alias ConnectFour.Rules
  alias ConnectFour.Store

  setup do
    {:ok, _} = Application.ensure_all_started(:connect_four)

    on_exit(fn ->
      Application.ensure_all_started(:connect_four)
    end)

    :ok
  end

  test "put/2, get/1, all/0, and delete/1 persist game state" do
    game_id = unique_game_id("store")
    state = game_state(game_id)

    assert :ok = Store.put(game_id, state)
    assert {:ok, ^state} = Store.get(game_id)
    assert Enum.any?(Store.all(), &(&1.id == game_id))

    assert :ok = Store.delete(game_id)
    assert {:error, :not_found} = Store.get(game_id)
  end

  test "active games are rehydrated after the application restarts" do
    game_id = unique_game_id("rehydrate")

    assert {:ok, _pid} = ConnectFour.create_game(game_id, "Player 1")
    assert :ok = ConnectFour.join_game(game_id, "Player 2")
    assert :no_win = ConnectFour.drop_token(game_id, :player1, 3)

    assert :ok = Application.stop(:connect_four)
    assert {:ok, _} = Application.ensure_all_started(:connect_four)

    assert %{
             status: :active,
             player1: %{name: "Player 1"},
             player2: %{name: "Player 2"},
             board: board
           } =
             ConnectFour.get_state(game_id)

    assert :player1 = board |> Enum.at(5) |> Enum.at(3)

    assert :ok = ConnectFour.stop_game(game_id)
  end

  test "stopped games stay in DETS and are not rehydrated on restart" do
    game_id = unique_game_id("stopped")

    assert {:ok, _pid} = ConnectFour.create_game(game_id, "Player 1")
    assert :ok = ConnectFour.join_game(game_id, "Player 2")
    assert :ok = ConnectFour.stop_game(game_id)

    assert {:ok, %{status: :stopped, player1: %{name: "Player 1"}}} = Store.get(game_id)
    assert Enum.any?(ConnectFour.list_games(), &(&1.id == game_id and &1.status == :stopped))

    assert :ok = Application.stop(:connect_four)
    assert {:ok, _} = Application.ensure_all_started(:connect_four)

    assert {:error, :not_found} = ConnectFour.Registry.lookup_game(game_id)
    assert {:ok, %{status: :stopped}} = Store.get(game_id)
  end

  defp unique_game_id(prefix) do
    "#{prefix}_#{System.unique_integer([:positive])}"
  end

  defp game_state(game_id) do
    %{
      id: game_id,
      status: :active,
      player1: %{name: "Player 1", token: :player1},
      player2: %{name: nil, token: :player2},
      board: Board.new(),
      rules: Rules.new()
    }
  end
end
