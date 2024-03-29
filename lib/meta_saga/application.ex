defmodule Meta.Saga.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  alias Meta.Saga.Aeon.Endpoint

  def start(_type, _args) do
    children = [
      Endpoint.child_spec([])
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Meta.Saga.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
