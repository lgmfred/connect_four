# Four-in-a-Row (Connect Four) Game Engine

![CI](https://github.com/lgmfred/connect_four/actions/workflows/ci.yml/badge.svg)

This is a two-player game played on a 6x7 grid (6 rows and 7 columns). Players take turns dropping their tokens into one of the columns. The token falls to the lowest available position in that column.

The first player to align four of their tokens consecutively—horizontally, vertically, or diagonally—wins the game.

If the grid is completely filled without a winner, the game ends in a draw.

## Running Locally

To run this project locally, follow these steps:

```
git clone https://github.com/lgmfred/connect_four.git
cd connect_four
mix compile
iex -S mix
```

## Public API

Use `ConnectFour` as the application boundary:

```elixir
{:ok, _pid} = ConnectFour.create_game("game-1", "Player 1")
:ok = ConnectFour.join_game("game-1", "Player 2")
:no_win = ConnectFour.drop_token("game-1", :player1, 3)
state = ConnectFour.get_state("game-1")
:ok = ConnectFour.stop_game("game-1")
```

## Runtime State

The ETS cache is just for fast runtime access while the application is running. Durable
recovery across deploys should come from a database or event log, with
`ConnectFour.Init` rehydrating active games on boot.
