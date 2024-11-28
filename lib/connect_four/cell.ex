defmodule ConnectFour.Cell do
  alias __MODULE__

  @enforce_keys [:row, :col]
  defstruct [:row, :col]

  @type row :: 0..5
  @type col :: 0..6
  @type t :: %Cell{row: row(), col: col()}

  @rows 0..5
  @cols 0..6

  @doc """
  Create a new cell struct.

  ## Examples

      iex> ConnectFour.Cell.new(0, 0)
      {:ok, %ConnectFour.Cell{row: 0, col: 0}}

      iex> ConnectFour.Cell.new(6, 0)
      {:error, :invalid_cell}
  """

  @spec new(row(), col()) :: {:ok, t()} | {:error, :invalid_cell}
  def new(row, col) when row in @rows and col in @cols do
    {:ok, %Cell{row: row, col: col}}
  end

  def new(_row, _col), do: {:error, :invalid_cell}
end
