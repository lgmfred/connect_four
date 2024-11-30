defmodule ConnectFour.DynamicSupervisorTest do
  use ExUnit.Case, async: true

  describe "ConnectFour.DynamicSupervisor" do
    setup do
      {:ok, _} = Application.ensure_all_started(:connect_four)
      :ok
    end

    test "starts the supervisor" do
      assert Process.alive?(Process.whereis(ConnectFour.DynamicSupervisor))
    end

    test "spawns a game process" do
      {:ok, pid} = ConnectFour.DynamicSupervisor.spawn_game("game_1", name: "Player1")
      assert Process.alive?(pid)
    end

    test "supervisor tracks spawned games" do
      {:ok, pid} = ConnectFour.DynamicSupervisor.spawn_game("game_2", name: "Player1")
      children = DynamicSupervisor.which_children(ConnectFour.DynamicSupervisor)

      assert Enum.any?(children, fn
               {_, child_pid, :worker, _} -> child_pid == pid
               _ -> false
             end)
    end

    test ":transient strategy does not restart child on normal exit" do
      {:ok, pid} = ConnectFour.DynamicSupervisor.spawn_game("game_3", name: "Player3")

      assert {:ok, ^pid} = ConnectFour.Registry.lookup_game("game_3")

      DynamicSupervisor.terminate_child(ConnectFour.DynamicSupervisor, pid)

      Process.sleep(100)

      refute Process.alive?(pid)

      assert {:error, :not_found} = ConnectFour.Registry.lookup_game("game_3")
    end

    test ":transient strategy restarts child on abnormal exit with" do
      {:ok, pid} = ConnectFour.DynamicSupervisor.spawn_game("game_4", name: "Player4")
      assert {:ok, ^pid} = ConnectFour.Registry.lookup_game("game_4")

      assert Process.alive?(pid)

      Process.exit(pid, :kill)
      Process.sleep(100)

      refute Process.alive?(pid)

      {:ok, new_pid} = ConnectFour.Registry.lookup_game("game_4")
      assert Process.alive?(new_pid)

      refute new_pid == pid
    end

    test "stop_game/1 stops the game process" do
      {:ok, pid} = ConnectFour.DynamicSupervisor.spawn_game("game_5", name: "Player5")
      assert Process.alive?(pid)
      ConnectFour.DynamicSupervisor.stop_game("game_5")
      Process.sleep(100)
      refute Process.alive?(pid)
      assert {:error, :not_found} = ConnectFour.Registry.lookup_game("game_5")
    end
  end
end
