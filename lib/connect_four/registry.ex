defmodule ConnectFour.Registry do
  def child_spec(_opts) do
    Registry.child_spec(keys: :unique, name: __MODULE__)
  end

  def lookup_game(game_id) do
    case Registry.lookup(__MODULE__, game_id) do
      [{game_pid, _}] -> {:ok, game_pid}
      [] -> {:error, :not_found}
    end
  end
end
