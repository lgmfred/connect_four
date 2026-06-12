import Config

config :logger, level: :warning

store_dir =
  Path.join(System.tmp_dir!(), "connect_four_test_#{System.unique_integer([:positive])}")

config :connect_four, :store_path, Path.join(store_dir, "games.dets")
