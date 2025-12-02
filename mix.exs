defmodule Claude.MixProject do
  use Mix.Project

  def project do
    [
      app: :claude,
      version: "0.1.0",
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env()),
      deps: deps()
    ]
  end

  # Specifies compilation paths per environment
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: application_mod(Mix.env())
    ]
  end

  # Don't start the application in test mode
  defp application_mod(:test), do: []
  defp application_mod(_), do: {Claude.Application, []}

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:nostrum, github: "Kraigie/nostrum"},
      {:req, "~> 0.5"}
    ]
  end
end
