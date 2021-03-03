defmodule Meta.Saga.Cron do

  @moduledoc "Cron jobs helper"

  alias DistributedLib.Cron.Scheduler
  alias Meta.Saga.Processor

  #########################################################
  #
  #   Types
  #
  #########################################################

  @type saga_id :: binary()
  @type timestamp :: timeout()
  @type task :: Scheduler.task()

  #########################################################
  #
  #   API
  #
  #########################################################

  @spec add_execute_timeout(saga_id(), timestamp()) :: :ok
  def add_execute_timeout(id, timestamp) do
    {Processor, :handle_event, [id, :process_timeout]}
    |> add_timeout(id, timestamp)
  end

  @spec add_idle_timeout(saga_id(), timeout()) :: :ok
  def add_idle_timeout(id, timeout) do
    {Processor, :handle_event, [id, :idle_timeout]}
    |> add_timeout(id, timeout)
  end

  @spec add_timeout(task(), saga_id(), timeout()) :: :ok
  def add_timeout(task, id, timeout) do
    system_time = :os.system_time(:millisecond)
    timestamp = system_time + timeout

    with {:ok, _id} <- Scheduler.add_schedule(id, timestamp, task),
      do: :ok
  end

  @spec delete_timeout(saga_id()) :: :ok
  def delete_timeout(id),
    do: Scheduler.delete_schedule(id)

end
