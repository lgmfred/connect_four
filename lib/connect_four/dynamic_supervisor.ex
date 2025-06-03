defmodule ConnectFour.DynamicSupervisor do
  use DynamicSupervisor

  require Logger

  alias ConnectFour.Cache

  @spec start_link(keyword()) :: Supervisor.on_start()
  def start_link(opts) do
    DynamicSupervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  @spec spawn_game(binary(), map()) :: {:ok, pid()}
  def spawn_game(id, params) do
    child_spec = %{
      id: ConnectFour.Game,
      start: {ConnectFour.Game, :start_link, [id, params]},
      restart: :transient
    }

    {:ok, _pid} = DynamicSupervisor.start_child(__MODULE__, child_spec)
  end

  @spec stop_game(binary()) :: :ok
  def stop_game(game_id) do
    {:ok, pid} = ConnectFour.Registry.lookup_game(game_id)
    Cache.delete(game_id)
    DynamicSupervisor.terminate_child(__MODULE__, pid)
  end
end
