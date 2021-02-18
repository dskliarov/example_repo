defmodule Meta.Saga.Test.Client.Handler do

  alias Meta.Saga.Test.WorkflowOne

  require Logger

  @saga "svc.meta.test_saga."

  #########################################################
  #
  #   Handler
  #
  #########################################################

  def handle_message(@saga <> "response", %{"id" => id,
                                            "event" => event,
                                            "state" => state}, metadata) do
    WorkflowOne.process(id, event, state, metadata)
  end

  #########################################################
  #
  #  Private functions
  #
  #########################################################

end
