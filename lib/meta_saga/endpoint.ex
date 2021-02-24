defmodule Meta.Saga.Endpoint do
  use Wizard.Endpoint, service: :saga2, type: :svc, namespace: :meta

  alias Meta.Saga.CommandHandlers.Handler

  command("idle", Handler, input_schema: {:json, "idle.json"})
  command("process", Handler, input_schema: {:json, "process.json"})
  command("stop", Handler, input_schema: {:json, "process.json"})
  command("get", Handler, input_schema: {:json, "get.json"})
end
