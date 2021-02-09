defmodule Meta.Saga.Test.Client.Handler do

  alias Meta.Saga.Processor

  require Logger

  @saga "svc.meta.test_saga"

  #########################################################
  #
  #   Handler
  #
  #########################################################

  def handle_message(@saga <> "response", request, metadata) do
    :ok
  end

  #########################################################
  #
  #  Private functions
  #
  #########################################################

end
