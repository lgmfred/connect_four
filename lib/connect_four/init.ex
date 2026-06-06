defmodule ConnectFour.Init do
  use GenServer

  require Logger

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    start_game_processes()
    :ignore
  end

  defp start_game_processes do
    ## ETS is only a runtime cache. Durable recovery after a deploy should come
    ## from a database or event log, then active games can be rehydrated here.
    []
    |> Enum.each(fn game_opts ->
      id = Keyword.fetch!(game_opts, :id)

      ConnectFour.GameSupervisor.spawn_game(id, Keyword.delete(game_opts, :id))
    end)
  end
end
