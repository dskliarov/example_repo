# MetaSaga

The "Saga" service add distributed transaction features to the system.
The Service allow to manage a long running transaction - a transaction, which potentially could take days and even months to complete.

The Service stores the state of the running `saga` into the `event store` and enable tracking of the timeout of the current step. 
The `saga` could be in 2 possible states: an **idle or a **process. 
 - The **idle state - is a state of waiting for any commands addressed to the saga.
 - When the Service processing the command addressed to the specific saga, it will read a state from the database, 
   extract the uri of the service which responsible for that saga and send the command along with the state. `Process timeout` will be tracked.
   If next idle state or finalize command will not be received within specified `process timeout`, retry procedure will be executed and 
   retry counter will be decreased by 1. When counter will be equal to 0 and in case of the another timeout, the saga will be completed 
   with an exception. The exception completion and handling is not done yet - wip. 

The Service accepts following commands:
 - **idle
 - **process
 - **get
 
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
      to: "rpc://svc.meta.saga2.idle,
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
      to: "rpc://svc.meta.saga2.process,
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
      to: "rpc://svc.meta.saga2.get,
      payload: payload,
      metadata: metadata
    ]

  Wizard.Client.exec(args)
 ```
