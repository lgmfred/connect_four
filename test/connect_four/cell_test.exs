defmodule ConnectFour.CellTest do
  use ExUnit.Case

  doctest ConnectFour.Cell

  alias ConnectFour.Cell

  describe "new/2" do
    test "returns {:ok, %Cell{}} for valid row and column" do
      assert {:ok, %Cell{row: 0, col: 0}} = Cell.new(0, 0)
      assert {:ok, %Cell{row: 5, col: 6}} = Cell.new(5, 6)
    end

    test "returns {:error, :invalid_cell} for invalid row" do
      assert {:error, :invalid_cell} = Cell.new(-1, 0)
      assert {:error, :invalid_cell} = Cell.new(6, 3)
    end

    test "returns {:error, :invalid_cell} for invalid column" do
      assert {:error, :invalid_cell} = Cell.new(0, -1)
      assert {:error, :invalid_cell} = Cell.new(3, 7)
    end

    test "returns {:error, :invalid_cell} for invalid row and column" do
      assert {:error, :invalid_cell} = Cell.new(-1, -1)
      assert {:error, :invalid_cell} = Cell.new(6, 7)
    end
  end
end
