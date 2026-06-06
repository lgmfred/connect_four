defmodule ConnectFour.Init do
  use GenServer

  require Logger

  alias ConnectFour.Store

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    Logger.info("Init started with PID #{inspect(self())}; hydrating active games from DETS")
    count = start_game_processes()

    Logger.info(
      "Init PID #{inspect(self())} finished; hydrated #{count} active games and will now terminate"
    )

    :ignore
  end

  defp start_game_processes do
    active_games = Store.active()

    Logger.info("Init PID #{inspect(self())} found #{length(active_games)} active games in DETS")

    Enum.each(active_games, fn %{id: id} = game_state ->
      Logger.info("Init PID #{inspect(self())} is hydrating active game #{id}")
      ConnectFour.GameSupervisor.spawn_game(id, state: game_state)
    end)

    length(active_games)
  end
end
