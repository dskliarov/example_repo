defmodule Meta.Saga.MixProject do
  use Mix.Project

  def project do
    [
      app: :saga_v2,
      version: "0.1.0",
      elixir: "~> 1.10",
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger, :distributed_lib, :wizard, :crypto],
      mod: {Meta.Saga.Application, []}
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

      # Devops dependencies
      {:dialyxir, "~> 1.0", only: [:dev, :test], runtime: false},
      {:credo, "~> 1.4", only: [:dev, :test], runtime: false},
      {:test_saga, path: "test/common_tests/client", runtime: false},
      {:core, git: "git@gitlab.aeon.world:services/service.meta.core.git", branch: "dev", runtime: false},
      {:redbug, git: "https://github.com/massemanet/redbug.git"},
      {:cowlib, "~> 2.10", override: true},
      {:data_utils, git: "git@gitlab.aeon.world:tools/data_utils.git"}
    ]
  end

  defp aliases do
    [
      ct: "cmd rebar3 ct --name saga@127.0.0.1 --setcookie aeon",
      test_shell: "cmd rebar3 as test shell  --name saga@127.0.0.1 --setcookie aeon"
    ]
  end

end
