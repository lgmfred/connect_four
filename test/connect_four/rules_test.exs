defmodule ConnectFour.RulesTest do
  use ExUnit.Case

  doctest ConnectFour.Rules

  alias ConnectFour.Rules

  test "new/0 initializes the rules struct with state :initialized" do
    assert %Rules{state: :initialized} == Rules.new()
  end

  test "check/2 transitions from :initialized to :player1_turn on :add_player" do
    rules = Rules.new()
    assert {:ok, %Rules{state: :player1_turn}} == Rules.check(rules, :add_player)
  end

  test "check/2 transitions from :player1_turn to :player2_turn on {:drop_token, :player1}" do
    rules = %Rules{state: :player1_turn}
    assert {:ok, %Rules{state: :player2_turn}} == Rules.check(rules, {:drop_token, :player1})
  end

  test "check/2 transitions from :player2_turn to :player1_turn on {:drop_token, :player2}" do
    rules = %Rules{state: :player2_turn}
    assert {:ok, %Rules{state: :player1_turn}} == Rules.check(rules, {:drop_token, :player2})
  end

  test "check/2 keeps state :player1_turn on {:win_check, :no_win}" do
    rules = %Rules{state: :player1_turn}
    assert {:ok, %Rules{state: :player1_turn}} == Rules.check(rules, {:win_check, :no_win})
  end

  test "check/2 keeps state :player2_turn on {:win_check, :no_win}" do
    rules = %Rules{state: :player2_turn}
    assert {:ok, %Rules{state: :player2_turn}} == Rules.check(rules, {:win_check, :no_win})
  end

  test "check/2 transitions from :player1_turn to :game_over on {:win_check, :draw}" do
    rules = %Rules{state: :player1_turn}
    assert {:ok, %Rules{state: :game_over}} == Rules.check(rules, {:win_check, :draw})
  end

  test "check/2 transitions from :player2_turn to :game_over on {:win_check, :draw}" do
    rules = %Rules{state: :player2_turn}
    assert {:ok, %Rules{state: :game_over}} == Rules.check(rules, {:win_check, :draw})
  end

  test "check/2 transitions from :player1_turn to :game_over on {:win_check, :win}" do
    rules = %Rules{state: :player1_turn}
    assert {:ok, %Rules{state: :game_over}} == Rules.check(rules, {:win_check, :win})
  end

  test "check/2 transitions from :player2_turn to :game_over on {:win_check, :win}" do
    rules = %Rules{state: :player2_turn}
    assert {:ok, %Rules{state: :game_over}} == Rules.check(rules, {:win_check, :win})
  end

  test "check/2 returns :error for invalid actions in :initialized state" do
    rules = %Rules{state: :initialized}
    assert :error == Rules.check(rules, {:drop_token, :player1})
    assert :error == Rules.check(rules, :invalid_action)
  end

  test "check/2 returns :error for invalid actions in :player1_turn state" do
    rules = %Rules{state: :player1_turn}
    assert :error == Rules.check(rules, {:drop_token, :player2})
    assert :error == Rules.check(rules, :add_player)
  end

  test "check/2 returns :error for invalid actions in :player2_turn state" do
    rules = %Rules{state: :player2_turn}
    assert :error == Rules.check(rules, {:drop_token, :player1})
    assert :error == Rules.check(rules, :add_player)
  end

  test "check/2 returns :error for invalid actions in :game_over state" do
    rules = %Rules{state: :game_over}
    assert :error == Rules.check(rules, {:drop_token, :player1})
    assert :error == Rules.check(rules, {:win_check, :no_win})
    assert :error == Rules.check(rules, :add_player)
  end
end
