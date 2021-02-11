defmodule Meta.Saga.Test.Client.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  alias Meta.Saga.Test.Client.Endpoint

  def start(_type, _args) do
    Application.put_env(:grpc_transport, :listen, {'127.0.0.1', 9002})
    children = [
      Endpoint.child_spec([]),
      %{
        :id => Meta.Saga.Test.WorkflowOne,
        :start => {Meta.Saga.Test.WorkflowOne, :start_link, []}
      }
    ]
    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Meta.Saga.Test.Client.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
