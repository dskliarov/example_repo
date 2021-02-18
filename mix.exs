defmodule Meta.Saga.MixProject do
  use Mix.Project

  def project do
    [
      app: :saga2,
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
      extra_applications: [:logger, :distributed_lib ],
      mod: {Meta.Saga.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      # Runtime dependencies
      {:wizard, git: "git@gitlab.aeon.world:tools/wizard.git", branch: "dev"},
      {:grpc_transport, git: "git@gitlab.aeon.world:tools/grpc_transport.git", branch: "dev"},
      {:rabbit_transport, git: "git@gitlab.aeon.world:tools/rabbit_transport.git", branch: "dev"},
      {:codec, git: "git@gitlab.aeon.world:tools/codec.git", branch: "dev"},
      # {:distributed_lib, git: "git@gitlab.aeon.world:tools/distributed_lib.git", branch: "pseudo-async_call"},
#      {:distributed_lib, path: "/Users/dskliarov/erlang_projects/distributed_lib"},
      {:distributed_lib, git: "git@gitlab.aeon.world:tools/distributed_lib.git", branch: "pseudo-async_call"},

      # Devops dependencies
      {:dialyxir, "~> 1.0", only: [:dev, :test], runtime: false},
      {:credo, "~> 1.4", only: [:dev, :test], runtime: false},
      {:test_saga, path: "test/common_tests/client", runtime: false},
      {:core, git: "git@gitlab.aeon.world:services/service.meta.core.git", branch: "default_backend", runtime: false}
    ]
  end

  defp aliases do
    [
      ct: "cmd rebar3 ct --name saga@127.0.0.1 --setcookie aeon",
      test_shell: "cmd rebar3 as test shell  --name saga@127.0.0.1 --setcookie aeon"
    ]
  end

end
