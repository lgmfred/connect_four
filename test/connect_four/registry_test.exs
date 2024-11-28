defmodule ConnectFour.RegistryTest do
  use ExUnit.Case, async: true

  setup do
    {:ok, _} = Application.ensure_all_started(:connect_four)
    :ok
  end

  test "lookup_game/1 returns error when no game is registered" do
    assert {:error, :not_found} = ConnectFour.Registry.lookup_game(:nonexistent_game)
  end

  test "lookup_game/1 returns game PID when a game is registered" do
    game_id = :test_game
    game_pid = self()
    {:ok, _owner} = Registry.register(ConnectFour.Registry, game_id, :meta)

    assert {:ok, ^game_pid} = ConnectFour.Registry.lookup_game(game_id)
  end
end
