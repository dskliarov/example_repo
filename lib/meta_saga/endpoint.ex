defmodule Meta.Saga.Endpoint do
  use Wizard.Endpoint, service: :saga2, type: :svc, namespace: :meta

  alias Meta.Saga.CommandHandlers.Handler

  command("idle", Handler, input_schema: {:json, "idle.json"})
  command("get", Handler, input_schema: {:json, "get.json"})
  command("stop", Handler)
  command("process", Handler)
end
