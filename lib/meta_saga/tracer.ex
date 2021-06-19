defmodule DbgSaga do
  alias Meta.Saga.CommandHandlers.Handler
  alias Meta.Saga.Cron
  alias Meta.Saga.Processor
  alias DistributedLib.Cron.Scheduler


  @value_max_length 15

  def trace() do
    modules = [Handler, Cron, Processor]
    :dbg.stop_clear()
    :dbg.tracer(:process, {&tracer_printer(&1, &2, -1), 0})
    :dbg.p(:all, :c)
    Enum.each(modules, &trace_module/1)
  end

  defp trace_module(module) do
    result = :dbg.tpl(module, :_, :_, [{:_, [], [{:return_trace}]}])
    IO.puts("Enabel tracing of #{module} module with the result #{inspect result}")
  end

  #########################################################

  def tracer_printer(_msg, max_counter, max_counter) do
    IO.puts(String.pad_leading("", 100, "-"))
    IO.puts("The max number of trace counter had been reached. Tracing stopped")
    IO.puts(String.pad_leading("", 100, "-"))
    :dbg.stop_clear()
  end

  def tracer_printer(msg, n, _max_counter) when n > 4000 do
    IO.puts(String.pad_leading("", 100, "-"))
    tracer_printer(msg, n, n)
  end

  def tracer_printer(msg, n, max_counter) do
    {:ok, date_time} = DateTime.now("Etc/UTC")
    date_time_string = DateTime.to_string(date_time)
    formatted_date_time = "#{IO.ANSI.light_white_background()} #{date_time_string} #{IO.ANSI.reset()}"
    IO.puts(String.pad_leading("", 100, "-"))
    IO.puts("Trace #{n + 1} of #{max_counter}          #{formatted_date_time}")
    IO.puts(String.pad_leading("", 100, "-"))
    print_message(msg)
    IO.puts("#{reset()}")
    n + 1
  end

  def print_message({:trace, pid, _call_stage, {module, function, params}}) do
    indentation = Process.get({pid, :indentation}, 0)
    try do
      print_call(module, function, params, indentation, pid)
      print_params(function, params, indentation, pid)
    rescue
      exception ->
        :error
        |> Exception.format(exception, __STACKTRACE__)
        |> PrettyPrint.inspect()
    end
    Process.put({module, function, length(params), :params}, params)
    Process.put({pid, :indentation}, indentation + 1)
  end

  def print_message({:trace, pid, :return_from, {module, function, arity}, result}) do
    indentation = Process.get({pid, :indentation}, -1)
    indentation = indentation - 1
    Process.put({pid, :indentation}, indentation)
    print_return(module, function, arity, indentation, pid)
    original_params = Process.get({module, function, arity, :params})
    try do
      print_result(function, original_params, result, indentation, pid)
    rescue
      exception ->
        :error
        |> Exception.format(exception, __STACKTRACE__)
        |> PrettyPrint.inspect()
    end
  end

  defp indentation(indentation),
    do: "#{String.pad_leading("", indentation, "* ")}#{reset()}  "

  defp indentation(indentation, :call),
    do: "#{IO.ANSI.blue()}#{IO.ANSI.inverse}#{String.pad_leading("", indentation, "* ")}#{reset()}  "

  defp indentation(indentation, :result),
    do: "#{IO.ANSI.yellow()}#{IO.ANSI.inverse}#{String.pad_leading("", indentation, "* ")}#{reset()}  "

  #########################################################
  #
  # print_params
  #
  #########################################################

  defp print_params(_function, [], _indentation, _pid), do: :ok

  defp print_params(:handle_message, [uri, payload, metadata], indentation, pid) do
    IO.puts("#{indentation(indentation, :call)}#{IO.ANSI.blue}params:#{reset()}")
    print_structure("uri", uri, indentation, pid)
    print_structure("saga_payload", payload, indentation, pid)
    print_structure("metadata", metadata, indentation, pid)
  end

  defp print_params(:handle_event, [data, event, metadata], indentation, pid) do
    IO.puts("#{indentation(indentation, :call)}#{IO.ANSI.blue}params:#{reset()}")
    case data do
      %{"events_queue" => _, "owner" => _, "state" => _} ->
        print_structure("saga_payload", data, indentation, pid)
      _other ->
        print_structure("data", data, indentation, pid)
    end
    print_structure("event", event, indentation, pid)
    print_structure("metadata", metadata, indentation, pid)
  end

  defp print_params(:handle_internal_event, [id, event, metadata], indentation, pid) do
    IO.puts("#{indentation(indentation, :call)}#{IO.ANSI.blue}params:#{reset()}")
    print_structure("id", id, indentation, pid)
    print_structure("event", event, indentation, pid)
    print_structure("metadata", metadata, indentation, pid)
  end

  defp print_params(:handle, params, indentation, pid) do
    IO.puts("#{indentation(indentation, :call)}#{IO.ANSI.blue}params:#{reset()}")
    case params do
      [id, {saga_payload, event, metadata}, opts] ->
        print_structure("id", id, indentation, pid)
        print_structure("saga_payload", saga_payload, indentation, pid)
        print_structure("event", event, indentation, pid)
        print_structure("metadata", metadata, indentation, pid)
        print_structure("options", opts, indentation, pid)
      [id, {{command, saga_payload}, metadata}, opts] ->
        print_structure("id", id, indentation, pid)
        print_structure("command", command, indentation, pid)
        print_structure("saga_payload", saga_payload, indentation, pid)
        print_structure("metadata", metadata, indentation, pid)
        print_structure("options", opts, indentation, pid)
      [id, {event, metadata}, opts] ->
        print_structure("id", id, indentation, pid)
        print_structure("event", event, indentation, pid)
        print_structure("metadata", metadata, indentation, pid)
        print_structure("options", opts, indentation, pid)
    end
  end

  defp print_params(:process_saga, [id, {:ok, {id, saga_payload}}, {command, new_saga_payload}, metadata], indentation, pid) do
    IO.puts("#{indentation(indentation, :call)}#{IO.ANSI.blue}params:#{reset()}")
    print_structure("id", id, indentation, pid)
    print_structure("command", command, indentation, pid)
    print_structure("saga_payload", saga_payload, indentation, pid)
    print_structure("metadata", metadata, indentation, pid)
    print_diff_structure("new_saga_payload", new_saga_payload, saga_payload, indentation, pid)
  end

  defp print_params(:process_saga, [id, saga_payload, {command, new_saga_payload}, metadata], indentation, pid) do
    IO.puts("#{indentation(indentation, :call)}#{IO.ANSI.blue}params:#{reset()}")
    print_structure("id", id, indentation, pid)
    print_structure("command", command, indentation, pid)
    print_structure("saga_payload", saga_payload, indentation, pid)
    print_structure("metadata", metadata, indentation, pid)
    print_diff_structure("new_saga_payload", new_saga_payload, saga_payload, indentation, pid)
  end

  defp print_params(:process_saga, [id, saga_payload, event, metadata], indentation, pid) do
    IO.puts("#{indentation(indentation, :call)}#{IO.ANSI.blue}params:#{reset()}")
    print_structure("id", id, indentation, pid)
    print_structure("event", event, indentation, pid)
    print_structure("saga_payload", saga_payload, indentation, pid)
    print_structure("metadata", metadata, indentation, pid)
  end

  defp print_params(:switch_to_idle, [id, saga, idle_timeout, metadata], indentation, pid) do
    IO.puts("#{indentation(indentation, :call)}#{IO.ANSI.blue}params:#{reset()}")
    print_structure("id", id, indentation, pid)
    print_structure("saga_payload", saga, indentation, pid)
    print_structure("idle_timeout", idle_timeout, indentation, pid)
    print_structure("metadata", metadata, indentation, pid)
  end

  defp print_params(:finalize_saga, [id, saga_payload, owner, command, metadata], indentation, pid) do
    IO.puts("#{indentation(indentation, :call)}#{IO.ANSI.blue}params:#{reset()}")
    print_structure("id", id, indentation, pid)
    print_structure("saga_payload", saga_payload, indentation, pid)
    print_structure("owner", owner, indentation, pid)
    print_structure("command", command, indentation, pid)
    print_structure("metadata", metadata, indentation, pid)
  end

  defp print_params(:dispatch_event, [saga_payload, event], indentation, pid) do
    IO.puts("#{indentation(indentation, :call)}#{IO.ANSI.blue}params:#{reset()}")
    print_structure("saga_payload", saga_payload, indentation, pid)
    print_structure("event", event, indentation, pid)
  end

  defp print_params(_function, params, indentation, pid) do
    IO.puts("#{indentation(indentation, :call)}#{IO.ANSI.blue}params:#{reset()}")
    Enum.each(params, &print_params(&1, indentation, pid))
  end

  defp print_params(%{"events_queue" => _, "owner" => _, "state" => _} = saga_payload, indentation, pid),
    do: print_structure("saga_payload", saga_payload, indentation, pid)

  defp print_params(%{"call_source" => _} = metadata, indentation, pid),
    do: print_structure("metadata", metadata, indentation, pid)

  defp print_params(param, indentation, _pid) do
    prefix = prefix(indentation)
    printable_params = compact(param)
    PrettyPrint.inspect(printable_params, width: 80, prefix: prefix)
  end

  #########################################################
  #
  # print_result
  #
  #########################################################

  defp print_result(:add_timeout, [_task, id, _timeout], result, indentation, pid) do
    print_structure("result: ", result, indentation, pid)
    print_current_schedule(id, indentation)
  end

  defp print_result(:delete_timeout, [id], result, indentation, pid) do
    print_structure("result: ", result, indentation, pid)
    print_current_schedule(id, indentation)
  end

  defp print_result(_function, _original_params,
    {:ok, {id, %{"events_queue" => _, "owner" => _, "state" => _} = saga_payload}}, indentation, pid) do
    IO.puts("#{indentation(indentation)}#{IO.ANSI.blue}result: {:ok, {id, saga_payload}}")
    print_structure("id", id, indentation, pid)
    print_structure("saga_payload", saga_payload, indentation, pid)
  end

  defp print_result(_function, _original_params,
    {:execute_process, {%{"events_queue" => _, "owner" => _, "state" => _} = saga_payload, event, timeout}}, indentation, pid) do
    IO.puts("#{indentation(indentation)}#{IO.ANSI.blue}result: {:execute_process, {saga_payload, event, timeout}}")
    print_structure("saga_payload", saga_payload, indentation, pid)
    print_structure("event", event, indentation, pid)
    print_structure("timeout", timeout, indentation, pid)
  end

  defp print_result(_function, _original_params,
    {:ok, [{id, %{"events_queue" => _, "owner" => _, "state" => _} = saga_payload}]}, indentation, pid) do
    IO.puts("#{indentation(indentation)}#{IO.ANSI.blue}result: {:ok, [{id, saga_payload}]}")
    print_structure("id", id, indentation, pid)
    print_structure("saga_payload", saga_payload, indentation, pid)
  end

  defp print_result(_function, _original_params,
    {command, %{"events_queue" => _, "owner" => _, "state" => _} = saga_payload}, indentation, pid) do
    IO.puts("#{indentation(indentation)}#{IO.ANSI.blue}result: {command, saga_payload}")
    print_structure("command", command, indentation, pid)
    print_structure("saga_payload", saga_payload, indentation, pid)
  end

  defp print_result(_function, _original_params,
    {command, %{"owner" => _, "state" => _} = saga_payload, timeout}, indentation, pid) do
    IO.puts("#{indentation(indentation)}#{IO.ANSI.blue}result: {command, saga_payload}")
    print_structure("command", command, indentation, pid)
    print_structure("saga_payload", saga_payload, indentation, pid)
    print_structure("idle_timeout", timeout, indentation, pid)
  end

  defp print_result(_function, _original_params,
    %{"owner" => _, "state" => _} = saga_payload, indentation, pid) do
    IO.puts("#{indentation(indentation)}#{IO.ANSI.blue}result: saga_payload")
    print_structure("saga_payload", saga_payload, indentation, pid)
  end

  defp print_result(_function, _original_params, result, indentation, _pid) do
    prefix = prefix(indentation, "result:")
    printable_result = compact(result)
    PrettyPrint.inspect(printable_result, width: 80, prefix: prefix)
  end

  defp print_current_schedule(id, indentation) do
    schedule =
      Scheduler.get_schedule()
      |> Enum.filter(&current_schedule_filter(&1, id))
    prefix = prefix(indentation, "present item schedule:")
    PrettyPrint.inspect(schedule, width: 80, prefix: prefix)
  end

  defp current_schedule_filter({id, _timeout, _task}, id), do: true
  defp current_schedule_filter(_schedule, _id), do: false

  defp print_return(module, :handle_message, arity, indentation, _pid) do
    function = "handle_message"
    style = "#{IO.ANSI.blue()}"
    message = trace_info(module, function, arity)
    header("#{message}", style, "*", indentation)
  end

  defp print_return(module, function, arity, indentation, _pid) do
    style = "#{IO.ANSI.blue()}"
    message = trace_info(module, function, arity)
    IO.puts("#{indentation(indentation, :result)}#{style}#{message}")
  end

  defp print_call(module, :handle_message, params, indentation, _pid) do
    style = "#{IO.ANSI.green()}"
    message = trace_info(module, "handle_message", params)
    header("#{message}", style, "*", indentation)
  end

  defp print_call(module, :handle, params, indentation, _pid) do
    style = "#{IO.ANSI.magenta()}"
    message = trace_info(module, "handle", params)
    header("#{message}", style, "*", indentation)
  end

  defp print_call(module, :handle_internal_event, params, indentation, _pid) do
    style = "#{IO.ANSI.cyan()}"
    message = trace_info(module, "handle_internal_event", params)
    header("#{message}", style, "*", indentation)
  end

  defp print_call(module, function, params, indentation, _pid) do
    style = "#{IO.ANSI.blue()}"
    message = trace_info(module, function, params)
    IO.puts("#{indentation(indentation, :call)}#{style}#{message}")
  end

  defp line(style, filler, indentation),
    do: IO.puts("#{indentation(indentation)}#{style}#{IO.ANSI.inverse()}#{String.pad_leading("", 100, filler)}#{reset()}")

  defp header(message, style, filler, indentation) do
    line(style, filler, indentation)
    IO.puts("#{indentation(indentation)}#{message}")
    line(style, filler, indentation)
  end

  defp prefix(indentation, label \\ ""),
    do: "#{indentation(indentation)}#{label} #{reset()}"

  defp reset, do: IO.ANSI.reset()

  defp trace_info(module, function, params) when is_list(params) do
    arity = length(params)
    "#{IO.ANSI.green()}Call #{module}.#{function}/#{arity}"
  end

  defp trace_info(module, function, arity),
    do: "#{IO.ANSI.blue()}Return result from #{module}.#{function}/#{arity}"

  #########################################################
  #   print_structure
  #########################################################

  defp print_structure(label, {:error, _} = object, indentation, _pid) do
    label = "#{IO.ANSI.yellow()}#{label}:"
    prefix = prefix(indentation, label)
    IO.puts("#{prefix}#{IO.ANSI.red()}#{IO.ANSI.inverse()}#{inspect object}#{reset()}")
  end

  defp print_structure(label, %{} = object, indentation, pid) when label in ["saga_payload", "metadata"] do
    storage_id = "#{label}_#{inspect pid}"
    stored_object = Process.get(storage_id, %{})
    case DataUtils.maps_diff(stored_object, object) do
      [] ->
        indentation
        |> prefix("#{IO.ANSI.yellow()}#{label}: #{IO.ANSI.green()}unchanged")
        |> IO.puts()
      _diff ->
        print_diff_structure(label, stored_object, object, indentation, pid)
        Process.put(storage_id, object)
    end
    print_saga_warning(object, indentation, pid)
  end

  defp print_structure(label, object, indentation, _pid) when object in [:idle_timeout, :process_timeout] do
    style = "#{IO.ANSI.red()}"
    message = "#{IO.ANSI.red()}#{IO.ANSI.inverse()}#{label}: #{inspect object}"
    header("#{message}", style, "*", indentation)
  end

  defp print_structure(label, object, indentation, _pid) do
    printable_object = compact(object)
    label = "#{IO.ANSI.yellow()}#{label}:"
    prefix = prefix(indentation, label)
    PrettyPrint.inspect(printable_object, width: 80, prefix: prefix)
  end

  defp print_saga_warning(%{"events_queue" => events_queue, "process" => process_event}, indentation, _pid) do
    cond do
      :queue.len(events_queue) > 0 ->
        queue_list = :queue.to_list(events_queue)
        line("#{IO.ANSI.red()}", "*", 0)
        IO.puts("#{indentation(indentation)}#{IO.ANSI.red()}WARNING!!!!#{reset()}")
        IO.puts("#{indentation(indentation)}#{IO.ANSI.red()}WARNING!!!! The process queue is building up#{reset()}")
        IO.puts("#{indentation(indentation)}#{IO.ANSI.red()}WARNING!!!!#{reset()}")
        line("#{IO.ANSI.red()}", "*", 0)
        IO.puts("#{IO.ANSI.blue()}Tasks queue: #{IO.ANSI.red()}#{IO.ANSI.inverse()}#{inspect queue_list}#{reset()}")
        IO.puts("#{IO.ANSI.blue()}Currently processing: #{IO.ANSI.red()}#{IO.ANSI.inverse()}#{inspect process_event}#{reset()}")
      true ->
        :ok
    end
  end

  defp print_saga_warning(_not_saga, _indentation, _pid), do: :ok

  #########################################################
  #   print_diff_structure
  #########################################################

  defp print_diff_structure(label, original_object, object, indentation, _pid) when map_size(original_object) == 0 do
    printable_object = compact(object)
    label = "#{IO.ANSI.yellow()}#{label}:"
    prefix = prefix(indentation, label)
    PrettyPrint.inspect(printable_object, width: 80, prefix: prefix)
  end

  defp print_diff_structure(label, original_object, object, indentation, pid) when is_map(object) do
    IO.puts("#{indentation(indentation)}#{IO.ANSI.yellow()}#{label}:")
    case DataUtils.maps_diff(original_object, object) do
      [] ->
        PrettyPrint.inspect("unchanged", width: 80, prefix: indentation(indentation))
      diff ->
        Enum.each(diff, &print_diff_item(&1, indentation, pid))
    end
  end

  defp print_diff_item(%{op: :replace,
                         path: [{field, :map}],
                         original_value: original_value,
                         value: value}, indentation, _pid) do
    IO.puts("#{indentation(indentation)}#{IO.ANSI.red()}- %{#{field}: #{inspect original_value}}#{reset()}")
    IO.puts("#{indentation(indentation)}#{IO.ANSI.green()}+ %{#{field}: #{inspect value}}#{reset()}")
  end

  defp print_diff_item(%{op: :replace,
                         path: [{field, :map}, {field1, :map}],
                         original_value: original_value,
                         value: value}, indentation, _pid) do
    field_to_remove = "%{#{field1}: #{inspect original_value}}"
    field_to_add = "%{#{field1}: #{inspect value}}"
    IO.puts("#{indentation(indentation)}#{IO.ANSI.red()}- %{#{field}: #{field_to_remove}}#{reset()}")
    IO.puts("#{indentation(indentation)}#{IO.ANSI.green()}+ %{#{field}: #{field_to_add}}#{reset()}")
  end

  defp print_diff_item(%{op: :move,
                         from: [{field_from, :map}],
                         path: [{field_to, :map}],
                         value: value}, indentation, _pid) do
    IO.puts("#{indentation(indentation)}#{IO.ANSI.red()}- %{#{field_from}: #{inspect value}}#{reset()}")
    IO.puts("#{indentation(indentation)}#{IO.ANSI.green()}+ %{#{field_to}: #{inspect value}}#{reset()}")
  end

  defp print_diff_item(%{op: :remove,
                         original_value: value,
                         path: [{field, :map}]}, indentation, _pid) do
    IO.puts("#{indentation(indentation)}#{IO.ANSI.red()}- %{#{field}: #{inspect value}}#{reset()}")
  end

  defp print_diff_item(%{op: :remove,
                         original_value: value,
                         path: [{field, :map}, {field1, :map}]}, indentation, _pid) do
    field_to_remove = "%{#{field1}: #{inspect value}}"
    IO.puts("#{indentation(indentation)}#{IO.ANSI.red()}- %{#{field}: #{field_to_remove}}#{reset()}")
  end

  defp print_diff_item(%{op: :remove,
                         original_value: value,
                         path: [{field, :map}, {field1, :map}, {field2, :map}]}, indentation, _pid) do
    field_to_remove = "%{#{field2}: #{inspect value}}"
    field_to_remove1 = "%{#{field1}: #{field_to_remove}}"
    IO.puts("#{indentation(indentation)}#{IO.ANSI.red()}- %{#{field}: #{field_to_remove1}}#{reset()}")
  end

  defp print_diff_item(%{op: :add,
                         path: [{field, :map}],
                         value: value}, indentation, _pid) do
    IO.puts("#{indentation(indentation)}#{IO.ANSI.green()}+ %{#{field}: #{inspect value}}#{reset()}")
  end

  defp print_diff_item(other, indentation, _pid),
    do: PrettyPrint.inspect(other, width: 80, prefix: indentation(indentation))

  #########################################################
  #    compact
  #########################################################

  defp compact(list) when is_list(list),
    do: Enum.map(list, &compact/1)

  defp compact(map) when is_map(map) do
    map
    |> Map.keys()
    |> Enum.reduce(map, &compact_element/2)
  end

  defp compact({:ok, {id, saga}}), do: {:ok, {id, compact(saga)}}
  defp compact({:ok, object}), do: {:ok, compact(object)}
  defp compact({elem1, elem2}), do: {compact(elem1), compact(elem2)}
  defp compact({elem1, elem2, elem3}), do: {compact(elem1), compact(elem2), compact(elem3)}
  defp compact({elem1, elem2, elem3, elem4}), do: {compact(elem1), compact(elem2), compact(elem3), compact(elem4)}

  defp compact(object), do: object

  defp compact_element("server_rsa", map),
    do: Map.put(map, "server_rsa", "...")

  defp compact_element(key, map) do
    case Map.get(map, key) do
      value when is_binary(value)  ->
        if (String.length(value) > @value_max_length) do
          value_compacted = String.slice(value, 0, @value_max_length)
          Map.put(map, key, "#{value_compacted}...")
        else
          map
        end
      value when is_map(value) ->
        value_compacted = compact(value)
        Map.put(map, key, value_compacted)
      _ ->
          map
    end
  end

end
