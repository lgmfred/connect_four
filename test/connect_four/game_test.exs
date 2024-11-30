defmodule ConnectFour.GameTest do
  use ExUnit.Case, async: true

  import ConnectFour.Registry, only: [via_tuple: 1]
  import ExUnit.CaptureLog

  alias ConnectFour.Game
  alias ConnectFour.Rules

  setup do
    {:ok, _} = Application.ensure_all_started(:connect_four)
    :ok
  end

  test "initial state initializes properly" do
    game_name = "test_game1"
    {:ok, _game_pid} = Game.start_link(game_name, name: "Player1")
    state = :sys.get_state(via_tuple(game_name))

    assert state.player1 == %{name: "Player1", token: :player1}
    assert state.player2 == %{name: nil, token: :player2}
    assert state.rules == %Rules{state: :initialized}
  end

  test "state change first requires adding a player after initialization" do
    game_name = "test_game2"
    {:ok, _game_pid} = Game.start_link(game_name, name: "Player1")
    assert :error = Game.drop_token(game_name, :player1, 0, 3)
    assert :error = Game.drop_token(game_name, :player2, 0, 5)
  end

  test "add_player/2: adding a player works correctly" do
    game_name = "test_game3"
    {:ok, _game_pid} = Game.start_link(game_name, name: "Player1")
    assert :ok = Game.add_player(game_name, "Player2")
    state2 = :sys.get_state(via_tuple(game_name))

    assert state2.rules == %Rules{state: :player1_turn}
    assert state2.player2.name == "Player2"
  end

  test "add_player/2: fails if the second player already joined" do
    game_name = "test_game4"
    {:ok, _game_pid} = Game.start_link(game_name, name: "Player1")
    :ok = Game.add_player(game_name, "Player2")
    assert :error = Game.add_player(game_name, "AnotherPlayer")
  end

  test "drop/2: dropping a token updates the board" do
    game_name = "test_game5"
    {:ok, _game_pid} = Game.start_link(game_name, name: "Player1")
    :ok = Game.add_player(game_name, "Player2")
    state1 = :sys.get_state(via_tuple(game_name))

    assert :no_win = Game.drop_token(game_name, :player1, 0, 0)

    state2 = :sys.get_state(via_tuple(game_name))

    refute state1.board == state2.board
  end

  test "dropping a token fails for invalid moves" do
    game_name = "test_game6"
    {:ok, _game_pid} = Game.start_link(game_name, name: "Player1")
    :ok = Game.add_player(game_name, "Player2")

    assert {:error, :invalid_cell} = Game.drop_token(game_name, :player1, -1, 0)
    assert {:error, :invalid_cell} = Game.drop_token(game_name, :player1, 0, 7)
  end

  test "drop_token/4: with full column returns an error" do
    game_name = "test_game7"
    {:ok, _game_pid} = Game.start_link(game_name, name: "Player1")
    :ok = Game.add_player(game_name, "Player2")
    board = List.duplicate(:player2, 7) |> List.duplicate(6)

    _new_state = :sys.replace_state(via_tuple(game_name), fn state -> %{state | board: board} end)

    assert {:error, :column_full} = Game.drop_token(game_name, :player1, 0, 0)
  end

  test "handles game :timeout message correctly" do
    game_name = "test_game8"
    {:ok, _game_pid} = Game.start_link(game_name, name: "Player1")
    {:ok, pid} = ConnectFour.Registry.lookup_game(game_name)
    true = Process.unlink(pid)

    ref = Process.monitor(pid)

    log =
      capture_log(fn ->
        send(pid, :timeout)
        Process.sleep(50)
      end)

    assert log =~ "A game has timed out"

    assert_receive {:DOWN, ^ref, :process, ^pid, {:shutdown, :timeout}}
    refute Process.alive?(pid)
    assert {:error, :not_found} = ConnectFour.Registry.lookup_game(game_name)
  end
end
