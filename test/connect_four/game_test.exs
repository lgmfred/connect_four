defmodule ConnectFour.GameTest do
  use ExUnit.Case, async: true

  import ConnectFour.Registry, only: [via_tuple: 1]

  alias ConnectFour.Game
  alias ConnectFour.Rules

  setup do
    {:ok, _} = Application.ensure_all_started(:connect_four)
    :ok
  end

  test "initial state initializes properly" do
    game_name = "test_game1"
    {:ok, _game_pid} = Game.start_link(game_name, name: "Player1", color: :red)
    state = :sys.get_state(via_tuple(game_name))

    assert state.player1 == %{name: "Player1", color: :red, token: :player1}
    assert state.player2 == %{name: nil, color: nil, token: :player2}
    assert state.rules == %Rules{state: :initialized}
    assert state.status == :active
    assert state.outcome == :in_progress
    assert state.ended_reason == nil
    assert %DateTime{} = state.started_at
    assert state.ended_at == nil
  end

  test "state change first requires adding a player after initialization" do
    game_name = "test_game2"
    {:ok, _game_pid} = Game.start_link(game_name, name: "Player1", color: :red)
    assert :error = Game.drop_token(game_name, :player1, 3)
    assert :error = Game.drop_token(game_name, :player2, 5)
  end

  test "add_player/3: adding a player works correctly" do
    game_name = "test_game3"
    {:ok, _game_pid} = Game.start_link(game_name, name: "Player1", color: :red)
    assert :ok = Game.add_player(game_name, "Player2", :yellow)
    state2 = :sys.get_state(via_tuple(game_name))

    assert state2.rules == %Rules{state: :player1_turn}
    assert state2.player2.name == "Player2"
    assert state2.player2.color == :yellow
  end

  test "add_player/3 stores the second player's color" do
    game_name = "test_game_with_player_color"
    {:ok, _game_pid} = Game.start_link(game_name, name: "Player1", color: :red)

    assert :ok = Game.add_player(game_name, "Player2", :blue)

    assert %{player2: %{name: "Player2", color: :blue}} = :sys.get_state(via_tuple(game_name))
  end

  test "add_player/3: fails if the second player already joined" do
    game_name = "test_game4"
    {:ok, _game_pid} = Game.start_link(game_name, name: "Player1", color: :red)
    :ok = Game.add_player(game_name, "Player2", :yellow)
    assert :error = Game.add_player(game_name, "AnotherPlayer", :green)
  end

  test "drop/2: dropping a token updates the board" do
    game_name = "test_game5"
    {:ok, _game_pid} = Game.start_link(game_name, name: "Player1", color: :red)
    :ok = Game.add_player(game_name, "Player2", :yellow)
    state1 = :sys.get_state(via_tuple(game_name))

    assert :no_win = Game.drop_token(game_name, :player1, 0)

    state2 = :sys.get_state(via_tuple(game_name))

    refute state1.board == state2.board
  end

  test "winning move records the completed outcome and end time" do
    game_name = "test_game_win_metadata"
    {:ok, _game_pid} = Game.start_link(game_name, name: "Player1", color: :red)
    :ok = Game.add_player(game_name, "Player2", :yellow)

    assert :no_win = Game.drop_token(game_name, :player1, 0)
    assert :no_win = Game.drop_token(game_name, :player2, 1)
    assert :no_win = Game.drop_token(game_name, :player1, 0)
    assert :no_win = Game.drop_token(game_name, :player2, 1)
    assert :no_win = Game.drop_token(game_name, :player1, 0)
    assert :no_win = Game.drop_token(game_name, :player2, 1)
    assert :win = Game.drop_token(game_name, :player1, 0)

    assert %{
             status: :finished,
             outcome: {:win, :player1},
             ended_reason: :completed,
             ended_at: %DateTime{}
           } = :sys.get_state(via_tuple(game_name))
  end

  test "idle timeout retires a finished game without overwriting its outcome" do
    game_name = "test_finished_game_retirement"
    {:ok, _game_pid} = Game.start_link(game_name, name: "Player1", color: :red)
    :ok = Game.add_player(game_name, "Player2", :yellow)

    :no_win = Game.drop_token(game_name, :player1, 0)
    :no_win = Game.drop_token(game_name, :player2, 1)
    :no_win = Game.drop_token(game_name, :player1, 0)
    :no_win = Game.drop_token(game_name, :player2, 1)
    :no_win = Game.drop_token(game_name, :player1, 0)
    :no_win = Game.drop_token(game_name, :player2, 1)
    :win = Game.drop_token(game_name, :player1, 0)

    {:ok, pid} = ConnectFour.Registry.lookup_game(game_name)
    true = Process.unlink(pid)
    ref = Process.monitor(pid)

    send(pid, :timeout)

    assert_receive {:DOWN, ^ref, :process, ^pid, :normal}
    refute Process.alive?(pid)

    assert {:ok,
            %{
              status: :finished,
              outcome: {:win, :player1},
              ended_reason: :completed,
              ended_at: %DateTime{}
            }} = ConnectFour.Store.get(game_name)
  end

  test "dropping a token fails for invalid moves" do
    game_name = "test_game6"
    {:ok, _game_pid} = Game.start_link(game_name, name: "Player1", color: :red)
    :ok = Game.add_player(game_name, "Player2", :yellow)

    assert {:error, :invalid_cell} = Game.drop_token(game_name, :player1, -1)
    assert {:error, :invalid_cell} = Game.drop_token(game_name, :player1, 7)
  end

  test "drop_token/3: with full column returns an error" do
    game_name = "test_game7"
    {:ok, _game_pid} = Game.start_link(game_name, name: "Player1", color: :red)
    :ok = Game.add_player(game_name, "Player2", :yellow)
    board = List.duplicate(:player2, 7) |> List.duplicate(6)

    _new_state = :sys.replace_state(via_tuple(game_name), fn state -> %{state | board: board} end)

    assert {:error, :column_full} = Game.drop_token(game_name, :player1, 0)
  end

  test "handles game :timeout message correctly" do
    game_name = "test_game8"
    {:ok, _game_pid} = Game.start_link(game_name, name: "Player1", color: :red)
    {:ok, pid} = ConnectFour.Registry.lookup_game(game_name)
    true = Process.unlink(pid)

    ref = Process.monitor(pid)

    send(pid, :timeout)

    assert_receive {:DOWN, ^ref, :process, ^pid, {:shutdown, :timeout}}
    refute Process.alive?(pid)

    assert {:ok,
            %{
              status: :timed_out,
              outcome: :no_result,
              ended_reason: :timed_out,
              ended_at: %DateTime{}
            }} = ConnectFour.Store.get(game_name)
  end
end
