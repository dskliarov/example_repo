defmodule Meta.Saga.Endpoint do
  use Wizard.Endpoint, service: :saga2, type: :svc, namespace: :meta

  alias Meta.Saga.CommandHandlers.Handler

  command("idle", Handler, input_schema: {:json, "idle.json"})
  command("stop", Handler, input_schema: {:json, "stop.json"})
  command("get", Handler, input_schema: {:json, "get.json"})
  command("process", Handler)
end
