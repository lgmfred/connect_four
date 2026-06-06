ExUnit.start()

ExUnit.after_suite(fn _suite_result ->
  :connect_four
  |> Application.get_env(:store_path)
  |> Path.dirname()
  |> File.rm_rf()
end)
