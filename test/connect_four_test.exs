defmodule ConnectFourTest do
  use ExUnit.Case
  doctest ConnectFour

  setup do
    {:ok, _} = Application.ensure_all_started(:connect_four)
    :ok
  end

  test "creates, joins, plays, reads, and stops a game through the public API" do
    game_id = "public_api_#{System.unique_integer([:positive])}"

    assert {:ok, pid} = ConnectFour.create_game(game_id, "Player1")
    assert Process.alive?(pid)

    assert %{status: :active, player1: %{name: "Player1"}, player2: %{name: nil}} =
             ConnectFour.get_state(game_id)

    assert :ok = ConnectFour.join_game(game_id, "Player2")
    assert :no_win = ConnectFour.drop_token(game_id, :player1, 0)

    assert %{board: board, player2: %{name: "Player2"}} = ConnectFour.get_state(game_id)
    assert :player1 = board |> Enum.at(5) |> Enum.at(0)

    assert :ok = ConnectFour.stop_game(game_id)
    assert Enum.any?(ConnectFour.list_games(), &(&1.id == game_id and &1.status == :stopped))
  end
end
