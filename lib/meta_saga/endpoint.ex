defmodule Meta.Saga.Endpoint do
  use Wizard.Endpoint, service: :saga, type: :svc, namespace: :meta

  alias Meta.Saga.CommandHandlers, as: Command

  command("idle", Command.Handler, input_schema: {:json, "idle.json"})
  command("process", Command.Handler, input_schema: {:json, "process.json"})
  command("get", Command.Handler, input_schema: {:json, "get.json"})
end
