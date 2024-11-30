defmodule ConnectFour.Cache do
  use GenServer

  require Logger

  alias ConnectFour.CacheRestore

  @ets_table_name __MODULE__.ETS

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def put(game_id, game_state) do
    GenServer.cast(__MODULE__, {:put, game_id, game_state})
  end

  def get(game_id) do
    case :ets.lookup(@ets_table_name, game_id) do
      [{^game_id, game_data}] -> {:ok, game_data}
      _ -> {:error, :not_found}
    end
  end

  def delete(game_id) do
    GenServer.cast(__MODULE__, {:delete, game_id})
  end

  @impl true
  def init(_opts) do
    ref = Process.monitor(CacheRestore)
    pid = Process.whereis(CacheRestore)

    cache_state =
      case CacheRestore.transfer_ets_table() do
        :no_backup ->
          :ets.new(
            @ets_table_name,
            [
              :set,
              :protected,
              :named_table,
              {:heir, Process.whereis(CacheRestore), nil},
              {:read_concurrency, true}
            ]
          )

          :cache_up

        :restoring ->
          :cache_down
      end

    {:ok, %{state: cache_state, ref: ref, pid: pid}}
  end

  @impl true
  def handle_cast({:put, game_id, game_state}, %{state: :cache_up} = state) do
    :ets.insert(@ets_table_name, {game_id, game_state})
    {:noreply, state}
  end

  def handle_cast({:put, _game_id, _game_state}, state) do
    Logger.warning("Cannot insert into cache, as it is currently down")
    {:noreply, state}
  end

  def handle_cast({:delete, game_id}, %{state: :cache_up} = state) do
    :ets.delete(@ets_table_name, game_id)
    {:noreply, state}
  end

  def handle_cast({:delete, _game_id}, state) do
    Logger.warning("Cannot delete from cache, as it is currently down")
    {:noreply, state}
  end

  @impl true
  def handle_info({:"ETS-TRANSFER", _table, _from, _date}, %{state: :cache_down} = state) do
    Logger.info("Cache has been successfully restored from heir process")
    {:noreply, %{state | state: :cache_up}}
  end

  def handle_info({:DOWN, ref, :process, _object, _reason}, %{ref: ref} = state) do
    :ok = Process.sleep(100)
    new_heir_pid = Process.whereis(CacheRestore)
    new_ref = Process.monitor(new_heir_pid)
    :ets.setopts(@ets_table_name, [{:heir, new_heir_pid, nil}])
    Logger.info("Updated heir process for ETS table to #{inspect(new_heir_pid)}")
    {:noreply, %{state | ref: new_ref, pid: new_heir_pid}}
  end
end
