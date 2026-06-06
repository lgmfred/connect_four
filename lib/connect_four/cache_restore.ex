defmodule ConnectFour.CacheRestore do
  use GenServer

  require Logger

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def transfer_ets_table do
    GenServer.call(__MODULE__, :transfer_ets_table)
  end

  @impl true
  def init(_opts) do
    Logger.info(
      "CacheRestore started with PID #{inspect(self())}; ready to hold the ETS cache if ConnectFour.Cache restarts"
    )

    {:ok, nil}
  end

  @impl true
  def handle_call(:transfer_ets_table, {from_pid, _tag}, table_id) do
    if from_pid == Process.whereis(ConnectFour.Cache) do
      do_transfer(table_id)
    else
      Logger.warning("Transfer can only be triggered by the ConnectFour.Cache process")
      {:reply, :error, table_id}
    end
  end

  @impl true
  def handle_info({:"ETS-TRANSFER", table_id, _from, _data}, _state) do
    Logger.info(
      "CacheRestore PID #{inspect(self())} is backing up ETS cache from ConnectFour.Cache"
    )

    {:noreply, table_id}
  end

  def do_transfer(nil) do
    Logger.info("CacheRestore PID #{inspect(self())} does not own an ETS table yet")
    {:reply, :no_backup, nil}
  end

  def do_transfer(table_id) do
    cache_pid = Process.whereis(ConnectFour.Cache)

    Logger.info(
      "CacheRestore PID #{inspect(self())} is transferring ETS table to ConnectFour.Cache PID #{inspect(cache_pid)}"
    )

    :ets.give_away(table_id, cache_pid, nil)
    {:reply, :restoring, nil}
  end
end
