defmodule Trexit.MixProject do
  use Mix.Project

  def project do
    [
      app: :trexit,
      version: "0.1.0",
      elixir: "~> 1.12",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {Trexit.Application, []},
      extra_applications: [:logger]
    ]
  end

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:plug, "~> 1.13"},
      {:plug_cowboy, "~> 2.5"},
      {:nimble_csv, "~> 1.2"},
      {:jsonrs, "~> 0.2"}
    ]
  end
end
