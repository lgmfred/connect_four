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
    ## If we had a database, we'd fetch all active games from it and start a game process for
    ## each one. For now, we just start with an empty list.
    []
    |> Enum.each(fn %{id: id} = game_params ->
      ConnectFour.DynamicSupervisor.spawn_game(id, game_params)
    end)
  end
end
