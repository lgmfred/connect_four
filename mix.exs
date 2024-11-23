defmodule ConnectFour.MixProject do
  use Mix.Project

  def project do
    [
      app: :connect_four,
      description: "Four-in-a-Row (Connect Four) Game Engine",
      version: "0.1.0",
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases(),
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        ci: :test,
        coveralls: :test,
        "coveralls.html": :test
      ],

      ## Docs
      name: "Four-in-a-Row",
      source_url: "https://github.com/lgmfred/connect_four",
      docs: [
        extras: ["README.md"],
        main: "readme",
        source_ref: "main"
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {ConnectFour.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:excoveralls, "~> 0.18", only: :test}
    ]
  end

  def aliases do
    [
      ci: [
        "format --check-formatted",
        "compile --warnings-as-errors --force",
        "dialyzer",
        "coveralls"
      ]
    ]
  end
end
