defmodule ConnectFour.GameSupervisorTest do
  use ExUnit.Case, async: true

  describe "ConnectFour.GameSupervisor" do
    setup do
      {:ok, _} = Application.ensure_all_started(:connect_four)
      :ok
    end

    test "starts the supervisor" do
      assert Process.alive?(Process.whereis(ConnectFour.GameSupervisor))
    end

    test "spawns a game process" do
      {:ok, pid} = ConnectFour.GameSupervisor.spawn_game("game_1", name: "Player1", color: :red)
      assert Process.alive?(pid)
    end

    test "supervisor tracks spawned games" do
      {:ok, pid} = ConnectFour.GameSupervisor.spawn_game("game_2", name: "Player1", color: :red)
      children = DynamicSupervisor.which_children(ConnectFour.GameSupervisor)

      assert Enum.any?(children, fn
               {_, child_pid, :worker, _} -> child_pid == pid
               _ -> false
             end)
    end

    test ":transient strategy does not restart child on normal exit" do
      {:ok, pid} = ConnectFour.GameSupervisor.spawn_game("game_3", name: "Player3", color: :red)

      assert {:ok, ^pid} = ConnectFour.Registry.lookup_game("game_3")

      DynamicSupervisor.terminate_child(ConnectFour.GameSupervisor, pid)

      Process.sleep(100)

      refute Process.alive?(pid)

      assert {:error, :not_found} = ConnectFour.Registry.lookup_game("game_3")
    end

    test ":transient strategy restarts child on abnormal exit with" do
      {:ok, pid} = ConnectFour.GameSupervisor.spawn_game("game_4", name: "Player4", color: :red)
      assert {:ok, ^pid} = ConnectFour.Registry.lookup_game("game_4")

      assert Process.alive?(pid)

      Process.exit(pid, :kill)
      Process.sleep(100)

      refute Process.alive?(pid)

      {:ok, new_pid} = ConnectFour.Registry.lookup_game("game_4")
      assert Process.alive?(new_pid)

      refute new_pid == pid
    end

    test "abnormal restart restores both players and the persisted game state" do
      game_id = "crash_restore_#{System.unique_integer([:positive])}"

      {:ok, pid} =
        ConnectFour.GameSupervisor.spawn_game(game_id, name: "Player 1", color: :red)

      assert :ok = ConnectFour.join_game(game_id, "Player 2", :yellow)
      assert :no_win = ConnectFour.drop_token(game_id, :player1, 6)

      catch_exit(ConnectFour.drop_token(game_id, :player2, 6))
      Process.sleep(100)

      assert {:ok, restarted_pid} = ConnectFour.Registry.lookup_game(game_id)
      refute restarted_pid == pid

      assert %{
               player1: %{name: "Player 1", color: :red},
               player2: %{name: "Player 2", color: :yellow},
               rules: %ConnectFour.Rules{state: :player2_turn},
               board: board
             } = ConnectFour.get_state(game_id)

      assert :player1 = board |> Enum.at(5) |> Enum.at(6)
      assert nil == board |> Enum.at(4) |> Enum.at(6)
    end

    test "stop_game/1 stops the game process" do
      {:ok, pid} = ConnectFour.GameSupervisor.spawn_game("game_5", name: "Player5", color: :red)
      assert Process.alive?(pid)
      ConnectFour.GameSupervisor.stop_game("game_5")
      Process.sleep(100)
      refute Process.alive?(pid)
      assert {:error, :not_found} = ConnectFour.Registry.lookup_game("game_5")
    end
  end
end
