defmodule ConnectFour.BoardTest do
  use ExUnit.Case

  doctest ConnectFour.Board

  alias ConnectFour.Cell
  alias ConnectFour.Board

  @empty_row List.duplicate(nil, 7)
  @new_board List.duplicate(@empty_row, 6)

  test "new/0 returns a new empty board" do
    assert @new_board == Board.new()
  end

  test "drop/3 with invalid column returns an error" do
    cell1 = %Cell{row: 0, col: -5}
    cell2 = %Cell{row: 0, col: 7}

    assert {:error, :invalid_column} == Board.drop(@new_board, cell1, :player2)
    assert {:error, :invalid_column} == Board.drop(@new_board, cell2, :player1)
  end

  test "drop/3 with full column returns an error" do
    full_column_board = List.duplicate([:player2], 7) |> List.duplicate(6)
    cell1 = %Cell{row: 0, col: 0}
    cell2 = %Cell{row: 0, col: 6}

    assert {:error, :column_full} == Board.drop(full_column_board, cell1, :player1)
    assert {:error, :column_full} == Board.drop(full_column_board, cell2, :player2)
  end

  test "drop/3 with valid column updates the board" do
    row = [:player1 | List.duplicate(nil, 6)]
    board = Enum.reverse([row | List.duplicate(@empty_row, 5)])

    assert {:no_win, board} == Board.drop(@new_board, %Cell{row: 0, col: 0}, :player1)
  end

  test "drop/3 with valid column and existing board updates the board" do
    top_row = [:player2, :player2, nil, nil, :player2, :player2, :player2]
    full_row = [:player2, :player2, :player2, :player2, :player2, :player2, :player2]
    board = [top_row | List.duplicate(full_row, 5)]
    result = [List.replace_at(top_row, 3, :player1) | List.duplicate(full_row, 5)]

    assert {:no_win, result} == Board.drop(board, %Cell{row: 0, col: 3}, :player1)
  end

  test "drop/3 results in a horizontal win" do
    row = [:player1, :player1, nil, :player1, nil, nil, nil]
    board = List.duplicate(@empty_row, 5) ++ [row]

    assert {:win, _updated_board} = Board.drop(board, %Cell{row: 5, col: 2}, :player1)
  end

  test "drop/3 results in a vertical win" do
    row = [nil, nil, nil, nil, nil, :player2, nil]
    board = List.duplicate(@empty_row, 3) ++ List.duplicate(row, 3)

    assert {:win, _updated_board} = Board.drop(board, %Cell{row: 2, col: 5}, :player2)
  end

  test "drop/3 results in a diagonal (bottom-left to top-right) win" do
    row_1 = [nil, nil, nil, nil, nil, nil, :player1]
    row_2 = [nil, nil, nil, nil, nil, :player1, nil]
    row_3 = [nil, nil, nil, nil, :player1, nil, nil]
    row_4 = [nil, nil, nil, :player1, nil, nil, nil]
    row_5 = [nil, nil, :player1, nil, nil, nil, nil]
    row_6 = [nil, nil, nil, nil, nil, nil, nil]
    board = [row_1, row_2, row_3, row_4, row_5, row_6]

    assert {:win, _updated_board} = Board.drop(board, %Cell{row: 0, col: 1}, :player1)
  end

  test "drop/3 results in a diagonal (top-left to bottom-right) win" do
    # This setup creates a diagonal that goes from top-left to bottom-right
    row_1 = [nil, nil, nil, nil, nil, nil, nil]
    row_2 = [nil, nil, nil, nil, nil, nil, nil]
    row_3 = [nil, nil, nil, :player1, nil, nil, nil]
    row_4 = [nil, nil, nil, nil, :player1, nil, nil]
    row_5 = [nil, nil, nil, nil, nil, :player1, nil]
    row_6 = [nil, nil, nil, nil, nil, nil, nil]
    board = [row_1, row_2, row_3, row_4, row_5, row_6]

    assert {:win, _updated_board} = Board.drop(board, %Cell{row: 5, col: 6}, :player1)
  end

  test "drop/3 with a full board and no win results in draw" do
    board = [
      [:player1, :player2, :player1, nil, :player1, :player2, :player1],
      [:player2, :player1, :player2, :player1, :player2, :player1, :player2],
      [:player1, :player2, :player1, :player1, :player2, :player1, :player2],
      [:player2, :player1, :player2, :player2, :player1, :player2, :player1],
      [:player1, :player2, :player1, :player1, :player2, :player1, :player2],
      [:player2, :player1, :player2, :player1, :player2, :player1, :player2]
    ]

    assert {:draw, _updated_board} = Board.drop(board, %Cell{row: 5, col: 3}, :player1)
  end
end
