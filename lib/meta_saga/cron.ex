defmodule Meta.Saga.Cron do

  alias DistributedLib.Cron.Scheduler
  alias Meta.Saga.Processor

  #########################################################
  #
  #   API
  #
  #########################################################

  def add_execute_timeout(id, timeout) do
    {Processor, :handle_event, [id, :processor_timeout]}
    |> add_timeout(id, timeout)
  end

  def add_idle_timeout(id, timeout) do
    {Processor, :handle_event, [id, :idle_timeout]}
    |> add_timeout(id, timeout)
  end

  def add_timeout(task, id, timeout) do
    system_time = :os.system_time(:millisecond)
    timestamp = system_time + timeout
    Scheduler.add_schedule(id, timestamp, task)
  end

  def delete_timeout(id),
    do: Scheduler.delete_schedule(id)

end
