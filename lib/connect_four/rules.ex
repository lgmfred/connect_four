defmodule ConnectFour.Rules do
  @moduledoc """
  A functional state machine for the game rules.
  """
  alias __MODULE__

  defstruct state: :initialized

  @type t :: %Rules{}

  @doc """
  Create a new game rules state.

  ## Returns
  * `%ConnectFour.Rules{}`

  ## Examples

      iex> ConnectFour.Rules.new()
      %ConnectFour.Rules{state: :initialized}
  """
  @spec new() :: t()
  def new(), do: %Rules{}

  @doc """
  Check the current state of the game rules and update the state if necessary.

  ## Parameters
  * `rules` - the game rules struct
  * `action` - the action to be performed on the game that can update the state

  ## Returns
  * `{:ok, rules}` - the updated game rules struct
  * `:error` - if the action is invalid

  ## Examples

      iex> ConnectFour.Rules.check(%ConnectFour.Rules{state: :initialized}, :add_player)
      {:ok, %ConnectFour.Rules{state: :player1_turn}}

      iex> ConnectFour.Rules.check(%ConnectFour.Rules{state: :player1_turn}, {:drop_token, :player1})
      {:ok, %ConnectFour.Rules{state: :player2_turn}}

      iex> ConnectFour.Rules.check(%ConnectFour.Rules{state: :player2_turn}, {:drop_token, :player2})
      {:ok, %ConnectFour.Rules{state: :player1_turn}}

      iex> ConnectFour.Rules.check(%ConnectFour.Rules{state: :player1_turn}, {:win_check, :no_win})
      {:ok, %ConnectFour.Rules{state: :player1_turn}}

      iex> ConnectFour.Rules.check(%ConnectFour.Rules{state: :player2_turn}, {:win_check, :draw})
      {:ok, %ConnectFour.Rules{state: :game_over}}

      iex> ConnectFour.Rules.check(%ConnectFour.Rules{state: :player1_turn}, {:win_check, :win})
      {:ok, %ConnectFour.Rules{state: :game_over}}

      iex> ConnectFour.Rules.check(%ConnectFour.Rules{}, :invalid_action)
      :error
  """

  @spec check(t(), atom() | tuple()) :: {:ok, t()} | :error
  def check(%Rules{state: :initialized} = rules, :add_player) do
    {:ok, %Rules{rules | state: :player1_turn}}
  end

  def check(%Rules{state: :player1_turn} = rules, {:drop_token, :player1}) do
    {:ok, %Rules{rules | state: :player2_turn}}
  end

  def check(%Rules{state: :player2_turn} = rules, {:drop_token, :player2}) do
    {:ok, %Rules{rules | state: :player1_turn}}
  end

  def check(%Rules{state: :player1_turn} = rules, {:win_check, win_or_not}) do
    case win_or_not do
      :no_win -> {:ok, rules}
      :draw -> {:ok, %Rules{rules | state: :game_over}}
      :win -> {:ok, %Rules{rules | state: :game_over}}
    end
  end

  def check(%Rules{state: :player2_turn} = rules, {:win_check, win_or_not}) do
    case win_or_not do
      :no_win -> {:ok, rules}
      :draw -> {:ok, %Rules{rules | state: :game_over}}
      :win -> {:ok, %Rules{rules | state: :game_over}}
    end
  end

  def check(_state, _action), do: :error
end
