defmodule Meta.Saga.Aeon do
  defmodule Entities.Saga do
    use Helper.Core, type: :saga
  end

  defmodule Services.Owner do

    alias Wizard.Client

    #########################################################
    #
    #   Types
    #
    #########################################################

    @type saga_id :: binary()
    @type state :: map()
    @type event :: binary()
    @type owner :: binary()
    @type metadata :: keyword()
    @type result :: {:ok, term()} | {:error, term()}

    #########################################################
    #
    #   API
    #
    #########################################################

    @spec execute(saga_id(), state(), event(), owner(), metadata()) :: result()
    def execute(id, state,  event, owner, metadata) do
      [
        to: "rpc://#{owner}",
        payload: %{
          "id" => id,
          "state" => state,
          "event" => event},
        metadata: metadata
      ]
      |> Client.exec()
    end

  end
end
