defmodule ConnectFour.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  require Logger

  @impl true
  def start(_type, _args) do
    children = [
      # Starts a worker by calling: ConnectFour.Worker.start_link(arg)
      # {ConnectFour.Worker, arg}

      ConnectFour.CacheRestore,
      ConnectFour.Cache,
      ConnectFour.Registry,
      ConnectFour.DynamicSupervisor,
      ConnectFour.Init
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: ConnectFour.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
