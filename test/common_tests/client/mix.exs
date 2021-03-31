defmodule Meta.Saga.Test.Client.MixProject do
  use Mix.Project

  def project do
    [
      app: :test_saga,
      version: "0.1.0",
      elixir: "~> 1.10",
      elixirc_paths: ["./"],
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger, :common_test, :wizard],
      mod: {Meta.Saga.Test.Client.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      # Runtime dependencies
      {:wizard, git: "git@gitlab.aeon.world:tools/wizard.git", branch: "dev"},
      {:grpc_transport, git: "git@gitlab.aeon.world:tools/grpc_transport_v2.git", branch: "dev"},
      {:rabbit_transport, git: "git@gitlab.aeon.world:tools/rabbit_transport.git", branch: "dev"},
      {:codec, git: "git@gitlab.aeon.world:tools/codec.git", branch: "dev"},
      {:helper, git: "git@gitlab.aeon.world:tools/helper.git", branch: "dev"},
      {:distributed_lib, git: "git@gitlab.aeon.world:tools/distributed_lib.git", branch: "dev"},
    ]
  end

end
