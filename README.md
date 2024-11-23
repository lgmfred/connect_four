# Four-in-a-Row (Connect Four) Game Engine

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
