defmodule ConnectFour.Init do
  use GenServer

  require Logger

  alias ConnectFour.GameSupervisor
  alias ConnectFour.Store

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    Logger.debug(
      "#{__MODULE__} started with PID #{inspect(self())}; hydrating active games from Store ..."
    )

    count = start_game_processes()
    Logger.info("#{__MODULE__} hydrated #{count} active games and will now terminate.")

    :ignore
  end

  defp start_game_processes() do
    active_games = Store.active()

    Logger.debug("Found #{length(active_games)} active games in Store.")

    Enum.each(active_games, fn %{id: id} = game_state ->
      Logger.debug("Hydrating active game: #{id} ...")
      GameSupervisor.spawn_game(id, state: game_state)
    end)

    length(active_games)
  end
end
