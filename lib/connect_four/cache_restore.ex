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
    Logger.info("Backing up ETS cache from ConnectFour.Cache")
    {:noreply, table_id}
  end

  def do_transfer(nil) do
    Logger.info("Heir process does not own ETS table, restore cache failed")
    {:reply, :no_backup, nil}
  end

  def do_transfer(table_id) do
    Logger.info("Restoring cache from heir to ConnectFour.Cache")
    :ets.give_away(table_id, Process.whereis(ConnectFour.Cache), nil)
    {:reply, :restoring, nil}
  end
end
