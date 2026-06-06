defmodule ConnectFour.Store do
  use GenServer

  require Logger

  @moduledoc """
  Durable game-state storage backed by DETS.
  """

  @table_name __MODULE__.DETS

  @type game_id :: binary()
  @type game_state :: ConnectFour.Game.state()

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @spec put(game_id(), game_state()) :: :ok | {:error, term()}
  def put(game_id, game_state) do
    GenServer.call(__MODULE__, {:put, game_id, game_state})
  end

  @spec get(game_id()) :: {:ok, game_state()} | {:error, :not_found}
  def get(game_id) do
    GenServer.call(__MODULE__, {:get, game_id})
  end

  @spec all() :: [game_state()]
  def all do
    GenServer.call(__MODULE__, :all)
  end

  @spec active() :: [game_state()]
  def active do
    GenServer.call(__MODULE__, :active)
  end

  @spec delete(game_id()) :: :ok | {:error, term()}
  def delete(game_id) do
    GenServer.call(__MODULE__, {:delete, game_id})
  end

  @impl true
  def init(opts) do
    Process.flag(:trap_exit, true)

    path = Keyword.get(opts, :path, configured_path())
    File.mkdir_p!(Path.dirname(path))

    Logger.info("Store PID #{inspect(self())} is opening DETS game store at #{path}")

    case :dets.open_file(@table_name, file: String.to_charlist(path), type: :set, repair: true) do
      {:ok, @table_name} ->
        Logger.info("Store PID #{inspect(self())} opened DETS game store")
        {:ok, %{table: @table_name, path: path}}

      {:error, reason} ->
        Logger.error("Failed to open DETS game store: #{inspect(reason)}")
        {:stop, reason}
    end
  end

  @impl true
  def handle_call({:put, game_id, game_state}, _from, state) do
    reply =
      with :ok <- :dets.insert(state.table, {game_id, game_state}) do
        :dets.sync(state.table)
      end

    {:reply, reply, state}
  end

  def handle_call({:get, game_id}, _from, state) do
    reply =
      case :dets.lookup(state.table, game_id) do
        [{^game_id, game_state}] -> {:ok, game_state}
        [] -> {:error, :not_found}
      end

    {:reply, reply, state}
  end

  def handle_call(:all, _from, state) do
    game_states =
      :dets.foldl(fn {_game_id, game_state}, acc -> [game_state | acc] end, [], state.table)

    {:reply, game_states, state}
  end

  def handle_call(:active, _from, state) do
    active_game_states =
      :dets.foldl(
        fn {_game_id, game_state}, acc ->
          if active?(game_state), do: [game_state | acc], else: acc
        end,
        [],
        state.table
      )

    {:reply, active_game_states, state}
  end

  def handle_call({:delete, game_id}, _from, state) do
    reply =
      with :ok <- :dets.delete(state.table, game_id) do
        :dets.sync(state.table)
      end

    {:reply, reply, state}
  end

  @impl true
  def terminate(_reason, state) do
    Logger.info("Store PID #{inspect(self())} is closing DETS game store at #{state.path}")
    :dets.close(state.table)
    :ok
  end

  defp configured_path do
    Application.get_env(:connect_four, :store_path, default_path())
  end

  defp default_path do
    Path.expand("data/connect_four_games.dets")
  end

  defp active?(game_state) do
    Map.get(game_state, :status, :active) == :active
  end
end
