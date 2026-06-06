defmodule ConnectFour.GameSupervisor do
  use DynamicSupervisor

  require Logger

  alias ConnectFour.Cache
  alias ConnectFour.Game
  alias ConnectFour.Store

  @spec start_link(keyword()) :: Supervisor.on_start()
  def start_link(opts) do
    DynamicSupervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    Logger.info(
      "GameSupervisor started with PID #{inspect(self())}; game processes will be supervised dynamically"
    )

    DynamicSupervisor.init(strategy: :one_for_one)
  end

  @spec spawn_game(binary(), keyword()) :: Supervisor.on_start_child()
  def spawn_game(id, opts) when is_binary(id) and is_list(opts) do
    source = if Keyword.has_key?(opts, :state), do: "persisted state", else: "new game request"

    Logger.info(
      "PID #{inspect(self())} is requesting GameSupervisor to start game #{id} from #{source}"
    )

    child_spec = %{
      id: ConnectFour.Game,
      start: {ConnectFour.Game, :start_link, [id, opts]},
      restart: :transient
    }

    case DynamicSupervisor.start_child(__MODULE__, child_spec) do
      {:ok, pid} = result ->
        Logger.info("GameSupervisor started game #{id} with PID #{inspect(pid)} from #{source}")
        result

      {:ok, pid, _info} = result ->
        Logger.info("GameSupervisor started game #{id} with PID #{inspect(pid)} from #{source}")
        result

      {:error, {:already_started, pid}} = result ->
        Logger.info("Game #{id} is already running with PID #{inspect(pid)}")
        result

      result ->
        result
    end
  end

  @spec stop_game(binary()) :: :ok
  def stop_game(game_id) do
    {:ok, pid} = ConnectFour.Registry.lookup_game(game_id)
    :ok = Store.put(game_id, Map.put(Game.get_state(game_id), :status, :stopped))
    Cache.delete(game_id)
    DynamicSupervisor.terminate_child(__MODULE__, pid)
  end
end
