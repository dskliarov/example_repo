# MetaSaga

The "Saga" service enables distributed transaction features to the system.
The Service allows managing a long-running transaction - a transaction, which potentially could take days and even months to complete.

The Service stores the state of the running `saga` into the `event store` and enable tracking of the timeout of the current step. 
The `saga` could be in 2 possible states: an **idle or a **process. 
 - The **idle state - is a state of waiting for any commands addressed to the saga.
 - When the Service processing the command addressed to the specific saga, it will read a state from the database, 
   extract the URI of the service responsible for that saga and send the command along with the state. `Process timeout` will be tracked.
   If the next idle state or finalize command will not be received within specified `process timeout`, the retry procedure will be executed, 
   and the retry counter will be decreased by 1. When the counter will be equal to 0 and in case of another timeout, 
   the saga will be completed with an exception.

The Service accepts following commands:
 - **idle
 - **process
 - **get
 - **stop
 
## The `idle` command

 The API call by using client wizard:
 
 ```
    saga = %{ "saga_current_step" => "initialize",
              "some_saga_data" => 123456789 }

    # options are optional
    # In case of some or all of 
    # the options are not present,
    # default values will be used

    options = %{"options" => %{
      "idle_timeout" => 300_000,
      "process_timeout" => 5_000,
      "retry_counter" => 10
    }}
    
    metadata = []

    payload = %{
      "id" => "some_id",
      "owner" => "svc.meta.test_saga.response",
      "state" => Map.merge(saga, options())
    }

   args = [
      to: "rpc://svc.meta.saga_v2.idle,
      payload: payload,
      metadata: metadata
    ]

  Wizard.Client.exec(args)
 ```

## The `process` command

 The API call by using client wizard:

 ```
    metadata = []

    payload = %{
      "id" => id,
      "event" => event
    }

   args = [
      to: "rpc://svc.meta.saga_v2.process,
      payload: payload,
      metadata: metadata
    ]

  Wizard.Client.exec(args)
 ```

## The `get` command

 The API call by using client wizard:

 ```
    metadata = []

    payload = %{
      "id" => id
    }

   args = [
      to: "rpc://svc.meta.saga_v2.get,
      payload: payload,
      metadata: metadata
    ]

  Wizard.Client.exec(args)
 ```

## The `stop` command

 This command will stop saga execution;
 After saga have been switched to the stop state,
 it will ignore all events, which will arrave after that.

 If saga state will be passed along with id, saga will be updated in the event store.

 The API call by using client wizard:

 ```
    metadata = []

    state = %{
      "id" => "some_id",
      "some_property" => "some_value"
    }

    payload = %{
      "id" => id,
      ## The state property is optional!!!
      "state => state
    }

   args = [
      to: "rpc://svc.meta.saga_v2.stop,
      payload: payload,
      metadata: metadata
    ]

  Wizard.Client.exec(args)
 ```

 The other way to stop saga is to send `stop` event to the process endpoint :

 ```
    metadata = []

    state = %{
      "id" => "some_id",
      "some_property" => "some_value"
    }

    payload = %{
      "id" => id,
      "event" => "stop",
      ## The state property is optional!!!
      "state => state
    }

   args = [
      to: "rpc://svc.meta.saga_v2.process,
      payload: payload,
      metadata: metadata
    ]

  Wizard.Client.exec(args)
 ```
## Debugging Saga

run 
```
rebar3 as test shell --name test@127.0.0.1 --setcookie aeon
```

In the shell, to create required environment, run:

This command will start etcd, rabbitmq, core, saga, saga_client services

```
test_helper:prelude().
```

to stop running services, run:

```
test_helper:postlude().
```

To run test workflow, run:

Sequential workflow
```
 saga_SUITE:workflow_one('saga_client@127.0.0.1').
```
 
 Async workflow (Events to process send to saga service through callbacks):
 
 ```
 saga_SUITE:workflow_two('saga_client@127.0.0.1').
 ```
