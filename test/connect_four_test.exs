defmodule ConnectFourTest do
  use ExUnit.Case
  doctest ConnectFour

  setup do
    {:ok, _} = Application.ensure_all_started(:connect_four)
    :ok
  end

  test "creates, joins, plays, reads, and stops a game through the public API" do
    game_id = "public_api_#{System.unique_integer([:positive])}"

    assert {:ok, pid} = ConnectFour.create_game(game_id, "Player1", :blue)
    assert Process.alive?(pid)

    assert %{
             status: :active,
             outcome: :in_progress,
             ended_at: nil,
             player1: %{name: "Player1", color: :blue},
             player2: %{name: nil}
           } =
             ConnectFour.get_state(game_id)

    assert :ok = ConnectFour.join_game(game_id, "Player2", :green)
    assert :no_win = ConnectFour.drop_token(game_id, :player1, 0)

    assert %{board: board, player2: %{name: "Player2", color: :green}} =
             ConnectFour.get_state(game_id)

    assert :player1 = board |> Enum.at(5) |> Enum.at(0)

    assert :ok = ConnectFour.stop_game(game_id)

    assert {:ok,
            %{
              status: :stopped,
              outcome: :no_result,
              ended_reason: :stopped,
              ended_at: %DateTime{}
            }} = ConnectFour.get_game(game_id)

    assert Enum.any?(ConnectFour.list_games(), &(&1.id == game_id))
    assert Enum.any?(ConnectFour.filter_games(%{status: :stopped}), &(&1.id == game_id))
  end

  test "spectator lookup falls back to DETS when the game is not cached" do
    game_id = "spectator_lookup_#{System.unique_integer([:positive])}"

    state = %{
      id: game_id,
      status: :stopped,
      outcome: :no_result,
      ended_reason: :stopped,
      started_at: DateTime.utc_now(),
      ended_at: DateTime.utc_now(),
      player1: %{name: "Player1", color: :red, token: :player1},
      player2: %{name: "Player2", color: :yellow, token: :player2},
      board: ConnectFour.Board.new(),
      rules: ConnectFour.Rules.new()
    }

    assert :ok = ConnectFour.Store.put(game_id, state)
    assert {:ok, ^state} = ConnectFour.get_game(game_id)
  end
end
