defmodule ConnectFour.Store do
  @moduledoc """
  Durable game-state storage backed by DETS.
  """
  use GenServer

  require Logger

  alias ConnectFour.Game

  @table_name __MODULE__.DETS

  @type game_id :: binary()
  @type game_state :: Game.state()

  @type filter :: map()

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @spec put(game_id(), game_state()) :: :ok | {:error, term()}
  def put(game_id, game_state) do
    GenServer.call(__MODULE__, {:put, game_id, game_state})
  end

  @spec get(game_id()) :: {:ok, game_state()} | {:error, :not_found}
  def get(game_id), do: GenServer.call(__MODULE__, {:get, game_id})

  @spec list_games() :: [game_state()]
  def list_games, do: GenServer.call(__MODULE__, :all)

  @spec active() :: [game_state()]
  def active, do: filter_games(%{status: :active})

  @spec filter_games(filter()) :: [game_state()]
  def filter_games(filter) do
    GenServer.call(__MODULE__, {:filter, filter})
  end

  @spec delete(game_id()) :: :ok | {:error, term()}
  def delete(game_id), do: GenServer.call(__MODULE__, {:delete, game_id})

  @impl true
  def init(opts) do
    Process.flag(:trap_exit, true)

    path = Keyword.get(opts, :path, configured_path())
    :ok = File.mkdir_p!(Path.dirname(path))

    Logger.debug("Store PID #{inspect(self())} is opening DETS game store at #{path}")

    case :dets.open_file(@table_name, file: String.to_charlist(path), type: :set, repair: true) do
      {:ok, @table_name} ->
        Logger.debug("Store PID #{inspect(self())} opened DETS game store")
        {:ok, %{table: @table_name, path: path}}

      {:error, reason} ->
        Logger.error("Failed to open DETS game store: #{inspect(reason)}")
        {:stop, reason}
    end
  end

  @impl true
  def handle_call({:put, game_id, game_state}, _from, state) do
    with :ok <- :dets.insert(state.table, {game_id, game_state}),
         :ok <- :dets.sync(state.table) do
      {:reply, :ok, state}
    else
      {:error, reason} ->
        Logger.error("DETS put failed with reason: #{inspect(reason)}")
        {:stop, reason, state}
    end
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
      :dets.foldl(
        fn {_game_id, game_state}, acc -> [game_state | acc] end,
        [],
        state.table
      )

    {:reply, game_states, state}
  end

  def handle_call({:filter, filter}, _from, state) do
    filtered_games =
      :dets.foldl(
        fn {_game_id, game_state}, acc ->
          if matches_filter?(game_state, filter), do: [game_state | acc], else: acc
        end,
        [],
        state.table
      )

    {:reply, filtered_games, state}
  end

  def handle_call({:delete, game_id}, _from, state) do
    with :ok <- :dets.delete(state.table, game_id),
         :ok <- :dets.sync(state.table) do
      {:reply, :ok, state}
    else
      {:error, reason} ->
        Logger.error("DETS delete failed with reason: #{inspect(reason)}")
        {:stop, reason, state}
    end
  end

  @impl true
  def terminate(_reason, state) do
    Logger.debug("Store PID #{inspect(self())} is closing DETS game store at #{state.path}")
    :dets.close(state.table)
    :ok
  end

  defp configured_path do
    Application.get_env(:connect_four, :store_path, default_path())
  end

  defp default_path do
    Path.expand("data/connect_four_games.dets")
  end

  defp matches_filter?(game_state, filter) do
    with true <- matches_status?(game_state, filter_value(filter, :status)),
         true <- matches_outcome?(game_state, filter_value(filter, :outcome)),
         true <- matches_player?(game_state, filter_value(filter, :player)) do
      true
    else
      false -> false
    end
  end

  defp filter_value(filter, key) when is_map(filter) do
    Map.get(filter, key) || Map.get(filter, Atom.to_string(key))
  end

  defp matches_status?(_game_state, value) when value in [nil, ""], do: true
  defp matches_status?(%{status: status}, value), do: status == normalize_status(value)

  defp matches_outcome?(_game_state, value) when value in [nil, ""], do: true
  defp matches_outcome?(%{outcome: {:win, _player}}, value) when value in [:win, "win"], do: true
  defp matches_outcome?(%{outcome: outcome}, value), do: outcome == normalize_outcome(value)
  defp matches_outcome?(_game_state, _value), do: false

  defp matches_player?(_game_state, value) when value in [nil, ""], do: true

  defp matches_player?(game_state, name) do
    name_lower = String.downcase(name)
    player1_name = String.downcase(get_in(game_state, [:player1, :name]) || "")
    player2_name = String.downcase(get_in(game_state, [:player2, :name]) || "")

    player1_name =~ name_lower or player2_name =~ name_lower
  end

  defp normalize_status("active"), do: :active
  defp normalize_status("finished"), do: :finished
  defp normalize_status("stopped"), do: :stopped
  defp normalize_status("timed_out"), do: :timed_out
  defp normalize_status(status), do: status

  defp normalize_outcome("in_progress"), do: :in_progress
  defp normalize_outcome("no_result"), do: :no_result
  defp normalize_outcome("draw"), do: :draw
  defp normalize_outcome(outcome), do: outcome
end
