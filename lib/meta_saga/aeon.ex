defmodule Meta.Saga.Aeon do

  @moduledoc "Inter-cervice communication setup"

  defmodule Endpoint do

    @moduledoc "Wizard Endpoint setup"

    use Wizard.Endpoint, service: :saga_v2, type: :svc, namespace: :meta

    alias Meta.Saga.CommandHandlers.Handler

    command("idle", Handler, input_schema: {:json, "idle.json"})
    command("get", Handler, input_schema: {:json, "get.json"})
    command("continue", Handler, input_schema: {:json, "get.json"})
    command("stop", Handler)
    command("process", Handler)
    command("process_callback", Handler)
  end

  defmodule Entities.Saga do

    @moduledoc "Saga Entity setup"

    use Helper.Core,
      type: :saga,
      subset_fields: ["error", "error_history", "events_queue", "owner", "process", "state", "id", "timestamp"]
  end

  defmodule Services.Owner do

    @moduledoc "Communication with owners services"

    alias Wizard.Client

    #########################################################
    #
    #   Types
    #
    #########################################################

    @type saga_id :: binary()
    @type state :: map()
    @type event :: term()
    @type owner :: binary()
    @type metadata :: map()
    @type result :: {:ok, term()} | {:error, term()}

    #########################################################
    #
    #   API
    #
    #########################################################

    @spec execute(saga_id(), state(), event(), owner(), metadata()) :: result()
    def execute(id, state,  event, owner, metadata) do
      [
        to: owner,
        payload: %{
          "id" => id,
          "state" => state,
          "event" => event},
        metadata: metadata,
        callback: "rpc://svc.meta.saga_v2.process_callback"
      ]
      |> Client.exec()
    end

  end
end
