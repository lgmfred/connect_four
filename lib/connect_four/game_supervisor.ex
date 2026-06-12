defmodule ConnectFour.GameSupervisor do
  use DynamicSupervisor

  require Logger

  alias ConnectFour.Game
  alias ConnectFour.Store

  @spec start_link(keyword()) :: Supervisor.on_start()
  def start_link(opts) do
    DynamicSupervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    Logger.debug(
      "GameSupervisor started with PID #{inspect(self())}; game processes will be supervised dynamically"
    )

    DynamicSupervisor.init(strategy: :one_for_one)
  end

  @spec spawn_game(binary(), keyword()) :: Supervisor.on_start_child()
  def spawn_game(id, opts) when is_binary(id) and is_list(opts) do
    Logger.debug(
      "PID #{inspect(self())} is requesting GameSupervisor to start/restart game #{id}"
    )

    child_spec = %{
      id: ConnectFour.Game,
      start: {__MODULE__, :start_game, [id, opts]},
      restart: :transient
    }

    {:ok, _pid} = DynamicSupervisor.start_child(__MODULE__, child_spec)
  end

  @doc false
  @spec start_game(binary(), keyword()) :: GenServer.on_start()
  def start_game(id, fallback_opts) do
    opts =
      case Store.get(id) do
        {:ok, %{status: :active} = state} -> [state: state]
        _any -> fallback_opts
      end

    Game.start_link(id, opts)
  end

  @spec stop_game(binary()) :: :ok
  def stop_game(game_id), do: Game.stop(game_id)
end
