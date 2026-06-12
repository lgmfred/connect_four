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
{:ok, _pid} = ConnectFour.create_game("game-1", "Player 1", :red)
:ok = ConnectFour.join_game("game-1", "Player 2", :yellow)
:no_win = ConnectFour.drop_token("game-1", :player1, 3)
state = ConnectFour.get_state("game-1")
:ok = ConnectFour.stop_game("game-1")
games = ConnectFour.list_games()
```

## Runtime State

[ETS](https://www.erlang.org/doc/apps/stdlib/ets.html) is used as a fast runtime
cache while the application is running. [DETS](https://www.erlang.org/doc/apps/stdlib/dets.html)
stores game state on disk so active games can be recovered after the application
restarts, with [`ConnectFour.Init`](lib/connect_four/init.ex) rehydrating active
games on boot.

Stopped, timed out, and finished games stay in DETS as historical records for
stats. Only active games are rehydrated into running processes on boot.

The default DETS file lives at `data/connect_four_games.dets`. For production, you
should prefer a real database or event log for richer durability, migrations, observability,
and multi-node coordination.

## Board Shape

The board is a list of six rows. Each row has seven columns.

Rows are indexed from top to bottom. Columns are indexed from left to right.

```text
          c0  c1  c2  c3  c4  c5  c6
row 0    [ ] [ ] [ ] [ ] [ ] [ ] [ ]
row 1    [ ] [ ] [ ] [ ] [ ] [ ] [ ]
row 2    [ ] [ ] [ ] [ ] [ ] [ ] [ ]
row 3    [ ] [ ] [ ] [ ] [ ] [ ] [ ]
row 4    [ ] [ ] [ ] [ ] [ ] [ ] [x]  deliberate crash cell
row 5    [ ] [ ] [ ] [ ] [ ] [ ] [ ]
```

When a token is dropped into a column, it falls to the lowest empty row. So the
first token dropped into column `6` lands at `row 5, col 6`. The next token in
that same column lands at `row 4, col 6`.

## Process Shape

The application starts this supervision tree:

```text
ConnectFour.Supervisor (:one_for_one)
|-- ConnectFour.CacheRestore
|-- ConnectFour.Store
|-- ConnectFour.Cache
|-- ConnectFour.Registry
|-- ConnectFour.GameSupervisor
|   |-- ConnectFour.Game "game-1"
|   `-- ConnectFour.Game "game-2"
`-- ConnectFour.Init
```

Each process has one small job:

- `ConnectFour.Store` owns DETS and writes game history to disk.
- `ConnectFour.Cache` owns ETS and serves fast spectator reads.
- `ConnectFour.CacheRestore` keeps the ETS table alive if the cache process restarts.
- `ConnectFour.Registry` maps a `game_id` to the running game process.
- `ConnectFour.GameSupervisor` starts and restarts game processes.
- `ConnectFour.Init` runs on boot, finds active games in DETS, and starts them again.
- `ConnectFour.Game` owns one game's rules, board, players, and moves.

## Failure Drills

Start IEx with a temporary DETS file so these demos do not pollute your normal
game history:

```sh
CONNECT_FOUR_STORE_PATH="/tmp/connect_four_demo_$(date +%s).dets" iex -S mix
```

### Crash One Game With a Bug

The demo bug lives in `ConnectFour.Game`: if *Player 2* lands at `row 4, col 6`,
the game process raises.

Run this in IEx:

```elixir
game_id = "crash-demo-#{System.unique_integer([:positive])}"

{:ok, pid_before} = ConnectFour.create_game(game_id, "Player 1", :red)
:ok = ConnectFour.join_game(game_id, "Player 2", :yellow)

ConnectFour.drop_token(game_id, :player1, 6)

ConnectFour.drop_token(game_id, :player2, 6)

{:ok, pid_after} = ConnectFour.Registry.lookup_game(game_id)
pid_before != pid_after
ConnectFour.get_state(game_id)
```

*Player 1* fills `row 5, col 6`. *Player 2* then falls into `row 4, col 6`, hits
the fake bug, and the supervisor restarts the game.

### Kill a Game Process

This skips the fake bug and kills the game directly:

```elixir
game_id = "kill-game-#{System.unique_integer([:positive])}"

{:ok, pid_before} = ConnectFour.create_game(game_id, "Player 1", :red)
:ok = ConnectFour.join_game(game_id, "Player 2", :yellow)
ConnectFour.drop_token(game_id, :player1, 3)

Process.exit(pid_before, :kill)

{:ok, pid_after} = ConnectFour.Registry.lookup_game(game_id)
pid_before != pid_after
ConnectFour.get_state(game_id)
```

The PID should change, but the game state should still be there.

### Kill a Registered Infrastructure Process

This picks one named support process and kills it. The top-level supervisor
brings it back.

```elixir
process = Enum.random([ConnectFour.Cache, ConnectFour.CacheRestore])
pid_before = Process.whereis(process)

Process.exit(pid_before, :kill)
Process.sleep(100)

pid_after = Process.whereis(process)
{process, pid_before != pid_after}
```

The PID should be different. If you kill `ConnectFour.Cache`, the ETS table is
handed to `ConnectFour.CacheRestore` and then handed back to the new cache
process.

> You may have noticed that `ConnectFour.GameSupervisor` is
> missing from the random kill list above. That was deliberate. A tiny bit of
> mischief, if you like. What happens if `ConnectFour.GameSupervisor` dies while
> it has many active game children? Don't just read the question. Try it. If at 
> all you notice any problem, how would address it?

## Stress Testing

Start an Elixir shell for the application:

```sh
CONNECT_FOUR_STORE_PATH="/tmp/connect_four_stress_$(date +%s).dets" iex -S mix
```

Using a temporary DETS file keeps stress-test records out of your normal game
history.

You can quiet the teaching logs while benchmarking:

```elixir
Logger.put_application_level(:connect_four, :warning)
```

### 1. Player moves through one game process

Hit one game process with a lot of player moves.

```elixir
game_id = "stress-single-#{System.unique_integer([:positive])}"
{:ok, _pid} = ConnectFour.create_game(game_id, "Player 1", :red)
:ok = ConnectFour.join_game(game_id, "Player 2", :yellow)

total_requests = 10_000

move = fn num ->
  player = if rem(num, 2) == 1, do: :player1, else: :player2
  column = rem(num - 1, 6)
  ConnectFour.drop_token(game_id, player, column)
end

{exec_time, results} =
  :timer.tc(fn ->
    1..total_requests
    |> Enum.map(fn num -> Task.async(fn -> move.(num) end) end)
    |> Task.await_many(:infinity)
  end)

Enum.frequencies(results)
reqs_per_second = 1_000_000 / exec_time * total_requests
```

### 2. Spectator reads from ETS

Do the same thing through the spectator path: ETS only, no game process.

```elixir
total_requests = 10_000

read_cache = fn ->
  ConnectFour.get_game(game_id)
  :ok
end

{exec_time, results} =
  :timer.tc(fn ->
    1..total_requests
    |> Enum.map(fn _num -> Task.async(fn -> read_cache.() end) end)
    |> Task.await_many(:infinity)
  end)

Enum.frequencies(results)
reqs_per_second = 1_000_000 / exec_time * total_requests
```

### 3. Many games in parallel

For the last one, start a lot of games at once. For each game, join Player 2 and
fire some moves at the board. I've left this out on purpose, too.

> The examples in the stress tests above use columns `0..5` to avoid the
> deliberate crash column. Some `:error` results are fine once a game is already
> over.
