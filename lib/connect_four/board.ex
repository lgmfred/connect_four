defmodule ConnectFour.Board do
  @moduledoc """
  Board module to represent the game board and handle token placement.
  """
  alias ConnectFour.Cell

  @type cell :: Cell.t()
  @type token :: :player1 | :player2
  @type row :: [token() | nil]
  @type board_row :: [token() | nil]
  @type t :: [row()]
  @type status :: :win | :draw | :no_win

  @rows 6
  @cols 7

  @doc """
  Create a new 6x7 game board.

  ## Examples

      iex> ConnectFour.Board.new()
      [
        [nil, nil, nil, nil, nil, nil, nil],
        [nil, nil, nil, nil, nil, nil, nil],
        [nil, nil, nil, nil, nil, nil, nil],
        [nil, nil, nil, nil, nil, nil, nil],
        [nil, nil, nil, nil, nil, nil, nil],
        [nil, nil, nil, nil, nil, nil, nil]
      ]
  """
  @spec new() :: t()
  def new do
    nil
    |> List.duplicate(@cols)
    |> List.duplicate(@rows)
  end

  @doc """
  Drop a token into the specified column. It will "fall" to the lowest empty row.
  Returns the updated board or an error and whether the drop resulted in a win.
  This function is actually a pipe which also determines if there is a win.

  ## Parameters
    - `board`: The current game board.
    - `col`: The column number (0 to 6) where the token is dropped.
    - `token`: The token to drop (`:player1` or `:player2`).

  ## Examples

      iex> board = ConnectFour.Board.new()
      iex> is_list(board)
      true

      iex> {:ok, _cell, :no_win, updated_board} = ConnectFour.Board.drop(ConnectFour.Board.new(), %ConnectFour.Cell{row: 0, col: 3}, :player1)
      iex> is_list(updated_board)
      true
  """
  @spec drop(t(), cell(), token()) :: {:ok, cell(), status(), t()} | {:error, atom()}
  def drop(board, %Cell{col: col}, token) when col in 0..6 do
    board
    |> get_lowest_empty_cell(col)
    |> place_token(board, token)
    |> drop_result(token)
  end

  def drop(_board, _col, _token), do: {:error, :invalid_column}

  ## Find the lowest empty cell in the specified column.
  # Returns {:ok, {row, col}} or {:error, :column_full} if the column is full.
  defp get_lowest_empty_cell(board, col) do
    0..(@rows - 1)
    |> Enum.reverse()
    |> Enum.reduce_while({:error, :column_full}, fn row, acc ->
      case Enum.at(Enum.at(board, row), col) do
        nil -> {:halt, Cell.new(row, col)}
        _ -> {:cont, acc}
      end
    end)
  end

  ## Updates the board by placing the token in the specified cell (row and column).
  @spec place_token({:ok, cell()} | {:error, atom()}, t(), token()) ::
          {:ok, cell(), t()} | {:error, atom()}
  defp place_token({:ok, %Cell{row: row, col: col} = cell}, board, token) do
    updated_board =
      List.update_at(board, row, fn current_row ->
        List.replace_at(current_row, col, token)
      end)

    {:ok, cell, updated_board}
  end

  defp place_token(error, _board, _token), do: error

  ## Determines if the drop resulted in a win.
  def drop_result({:ok, %Cell{} = cell, board}, token) do
    {:ok, cell, win_check(board, cell, token), board}
  end

  def drop_result(error, _token), do: error

  ## Check if there is a win or a draw.
  defp win_check(board, %Cell{} = address, token) do
    case is_there_winner?(board, address, token) do
      true -> :win
      false -> if is_board_full?(board), do: :draw, else: :no_win
    end
  end

  ## Check if there is a win in any of the four possible directions.
  defp is_there_winner?(board, %Cell{} = cell, token) do
    [:horizontal, :vertical, :bottom_left_to_top_right, :top_left_to_bottom_right]
    |> Enum.any?(&check_winner(board, cell, token, &1))
  end

  defp check_winner(board, %Cell{row: row}, token, :horizontal) do
    board
    |> Enum.at(row)
    |> has_consecutive_four?(token)
  end

  defp check_winner(board, %Cell{col: col}, token, :vertical) do
    board
    |> Enum.map(&Enum.at(&1, col))
    |> has_consecutive_four?(token)
  end

  ## Diagonal directions fall here.
  defp check_winner(board, %Cell{} = cell, token, direction) do
    board
    |> extract_diagonal(cell, direction)
    |> has_consecutive_four?(token)
  end

  ## Extract the diagonal elements in the specified direction.
  # (bottom-left to top-right or top-left to bottom-right) from a given starting point.

  defp extract_diagonal(board, %Cell{row: row, col: col}, :bottom_left_to_top_right) do
    rows = length(board)
    cols = length(List.first(board))

    {row, col} =
      Enum.reduce_while(0..(rows + cols), {row, col}, fn
        _, {row, col} when row < rows - 1 and col > 0 ->
          {:cont, {row + 1, col - 1}}

        _, {row, col} ->
          {:halt, {row, col}}
      end)

    Enum.reduce_while(0..(rows + cols), {[], row, col}, fn
      _, {acc, row, col} when row >= 0 and col < cols ->
        element = Enum.at(Enum.at(board, row), col)
        {:cont, {[element | acc], row - 1, col + 1}}

      _, {acc, _, _} ->
        {:halt, Enum.reverse(acc)}
    end)
  end

  ## Almost the same as previous function. Who cares about duplication? Ha!
  defp extract_diagonal(board, %Cell{row: row, col: col}, :top_left_to_bottom_right) do
    rows = length(board)
    cols = length(List.first(board))

    {row, col} =
      Enum.reduce_while(0..(rows + cols), {row, col}, fn
        _, {row, col} when row > 0 and col > 0 ->
          {:cont, {row - 1, col - 1}}

        _, {row, col} ->
          {:halt, {row, col}}
      end)

    Enum.reduce_while(0..(rows + cols), {[], row, col}, fn
      _, {acc, row, col} when row < rows and col < cols ->
        element = Enum.at(Enum.at(board, row), col)
        {:cont, {[element | acc], row + 1, col + 1}}

      _, {acc, _, _} ->
        {:halt, Enum.reverse(acc)}
    end)
  end

  ## Check if a list contains a sequence of four consecutive tokens
  # and if the consecutive tokens belong to the specified player (token).
  defp has_consecutive_four?(list, token) do
    list
    |> Enum.chunk_by(& &1)
    |> Enum.any?(fn chunk -> length(chunk) >= 4 and hd(chunk) == token end)
  end

  # Check if the board is full (we drop tokens so just check the head of the board).
  defp is_board_full?([head | _tail] = _board) do
    Enum.all?(head, fn cell -> cell != nil end)
  end
end
