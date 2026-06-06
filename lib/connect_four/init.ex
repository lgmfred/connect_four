defmodule ConnectFour.Init do
  use GenServer

  require Logger

  alias ConnectFour.Store

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    start_game_processes()
    :ignore
  end

  defp start_game_processes do
    Store.active()
    |> Enum.each(fn %{id: id} = game_state ->
      ConnectFour.GameSupervisor.spawn_game(id, state: game_state)
    end)
  end
end
