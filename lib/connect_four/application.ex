defmodule ConnectFour.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  require Logger

  @impl true
  def start(_type, _args) do
    children = [
      ConnectFour.CacheRestore,
      ConnectFour.Store,
      ConnectFour.Cache,
      ConnectFour.Registry,
      ConnectFour.GameSupervisor,
      ConnectFour.Init
    ]

    Logger.debug(
      "Starting ConnectFour supervision tree from PID #{inspect(self())}: CacheRestore -> Store -> Cache -> Registry -> GameSupervisor -> Init"
    )

    opts = [strategy: :one_for_one, name: ConnectFour.Supervisor]

    Supervisor.start_link(children, opts)
  end
end
