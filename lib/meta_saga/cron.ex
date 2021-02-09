defmodule Meta.Saga.Cron do

  alias DistributedLib.Cron.Scheduler
  alias Meta.Saga.Processor

  #########################################################
  #
  #   API
  #
  #########################################################

  def add_execute_timeout(id, timestamp) do
    {Processor, :handle_event, [id, :processor_timeout]}
    |> add_timeout(id, timestamp)
  end

  def add_idle_timeout(id, timestamp) do
    {Processor, :handle_event, [id, :idle_timeout]}
    |> add_timeout(id, timestamp)
  end

  def add_timeout(task, id, timestamp),
    do: Scheduler.add_schedule(id, timestamp, task)

  def delete_timeout(id),
    do: Scheduler.delete_schedule(id)

end
