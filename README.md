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

Use [`ConnectFour`](lib/connect_four.ex) as the application boundary:

```elixir
{:ok, _pid} = ConnectFour.create_game("game-1", "Player 1")
:ok = ConnectFour.join_game("game-1", "Player 2")
:no_win = ConnectFour.drop_token("game-1", :player1, 3)
state = ConnectFour.get_state("game-1")
:ok = ConnectFour.stop_game("game-1")
games = ConnectFour.list_games()
```

## Runtime State

[ETS](https://www.erlang.org/doc/apps/stdlib/ets.html) is used as a fast runtime cache while the application is running. [DETS](https://www.erlang.org/doc/apps/stdlib/dets.html) stores
game state on disk so active games can be recovered after the application
restarts, with [`ConnectFour.Init`](lib/connect_four/init.ex) rehydrating active games on boot.

Stopped, timed out, and finished games stay in DETS as historical records for
stats. Only active games are rehydrated into running processes on boot.

The default DETS file lives at `data/connect_four_games.dets`. For production, you 
should prefer a real database or event log for richer durability, migrations, observability,
and multi-node coordination.
