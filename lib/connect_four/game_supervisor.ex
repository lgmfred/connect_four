defmodule ConnectFour.GameSupervisor do
  use DynamicSupervisor

  alias ConnectFour.Cache
  alias ConnectFour.Game
  alias ConnectFour.Store

  @spec start_link(keyword()) :: Supervisor.on_start()
  def start_link(opts) do
    DynamicSupervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  @spec spawn_game(binary(), keyword()) :: Supervisor.on_start_child()
  def spawn_game(id, opts) when is_binary(id) and is_list(opts) do
    child_spec = %{
      id: ConnectFour.Game,
      start: {ConnectFour.Game, :start_link, [id, opts]},
      restart: :transient
    }

    DynamicSupervisor.start_child(__MODULE__, child_spec)
  end

  @spec stop_game(binary()) :: :ok
  def stop_game(game_id) do
    {:ok, pid} = ConnectFour.Registry.lookup_game(game_id)
    :ok = Store.put(game_id, Map.put(Game.get_state(game_id), :status, :stopped))
    Cache.delete(game_id)
    DynamicSupervisor.terminate_child(__MODULE__, pid)
  end
end
