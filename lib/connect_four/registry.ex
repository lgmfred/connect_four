defmodule ConnectFour.Registry do
  def child_spec(_opts) do
    Registry.child_spec(keys: :unique, name: __MODULE__)
  end

  @doc """
  Register a game in the registry.
  """
  @spec lookup_game(binary()) :: {:ok, pid()} | {:error, :not_found}
  def lookup_game(game_id) do
    case Registry.lookup(__MODULE__, game_id) do
      [{game_pid, _}] -> {:ok, game_pid}
      [] -> {:error, :not_found}
    end
  end

  @doc """
  Return the registry via tuple.
  """
  @spec via_tuple(binary()) :: tuple()
  def via_tuple(name), do: {:via, Registry, {__MODULE__, name}}
end
