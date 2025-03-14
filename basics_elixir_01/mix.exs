defmodule BasicsElixir01.MixProject do
  use Mix.Project

  def project do
    [
      app: :basics_elixir_01,
      version: "0.1.0",
      elixir: "~> 1.16",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      applications: [:amqp],
      registered: [Consumer, Publisher]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:amqp, "~> 3.3"},
      {:jason, "~> 1.2"}

    ]
  end
end
