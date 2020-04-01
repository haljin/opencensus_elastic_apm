defmodule OpencensusElasticApm.MixProject do
  use Mix.Project

  def project do
    [
      app: :opencensus_elastic_apm,
      version: "0.1.0",
      elixir: "~> 1.10",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:jason, "~> 1.1"},
      {:httpoison, "~> 1.5"},
      {:opencensus, "~> 0.9.0"},
      {:opencensus_elixir, "~> 0.4.0"}
    ]
  end
end
