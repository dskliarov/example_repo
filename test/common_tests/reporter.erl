-module(reporter).
-behaviour(gen_server).

-include_lib("common_test/include/ct.hrl").
-include_lib("eunit/include/eunit.hrl").

-export([
         init/1,
         handle_continue/2,
         handle_call/3,
         handle_cast/2,
         handle_info/2,
         terminate/2,
         code_change/3
        ]).

-export([
         start_link_safe/0,
         start_link/0,
         send_transactions/2,
         send_async_transaction/3,
         send_async_transaction_response/1,
         async_response/0,
         process_log/3,
         process_cron_log/2
        ]).

-define(CLIENT_ASYNC_PROCESSOR, 'Elixir.DistributedLib.Processor.ClientAsyncProcessor').
-define(DEFAULT_MAP, {0, sets:new()}).
-define(TIMEOUT, 15000).
-define(RESPONSE, #{"response" => "TestResponse"}).

%%--------------------------------------------------------------------
%%
%%  API
%%
%%--------------------------------------------------------------------

start_link_safe() ->
    case whereis(reporter) of
        undefined ->
            start_link();
        Pid ->
            {ok, Pid}
    end.

start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

send_transactions(Nodes, Key) ->
    gen_server:call(?MODULE, {send_transactions, Nodes, Key}, ?TIMEOUT).

send_async_transaction(RequestNode, ResponseNode, TransactionLatency) ->
    Action = {async_task,  async_task},
    Payload = #{"test" => "TestValue"},
    Metadata = [{reporter_node, node()},
                {response_node, ResponseNode},
                {transaction_latency, TransactionLatency}],
    Request = #{payload => Payload, metadata => Metadata},
    Args = [Action, Request, TransactionLatency * 2],
    test_helper:rpc_call(RequestNode, ?CLIENT_ASYNC_PROCESSOR, exec_async, Args).

send_async_transaction_response(Metadata) ->
    ResponseNode = proplists:get_value(response_node, Metadata),
    Args = [?RESPONSE, Metadata],
    test_helper:rpc_call(ResponseNode, ?CLIENT_ASYNC_PROCESSOR, process_response, Args).

async_response() -> ?RESPONSE.

process_log(Key, NodeId, WorkerId) ->
    gen_server:cast(?MODULE, {log, Key, NodeId, WorkerId}).

process_cron_log(Key, NodeId) ->
    gen_server:cast(?MODULE, {cronlog, Key, NodeId}).

%%--------------------------------------------------------------------
%%
%%  Callbacks
%%
%%--------------------------------------------------------------------

init(_Args) ->
    {ok, #{}}.

%%--------------------------------------------------------------------
%%  Continue handling Callbacks
%%--------------------------------------------------------------------

handle_continue(complete, #{sent := Cntr,
                            get := Cntr,
                            set := Set,
                            from := From}) ->
    case sets:size(Set) of
        1 ->
            gen_server:reply(From, ok);
        0 ->
            gen_server:reply(From, {error, "Report set is empty"});
        _ ->
            ReportData = sets:to_list(Set),
            gen_server:reply(From, {error, {duplicates, ReportData}})
    end,
    {noreply, #{}};

handle_continue(timeout, #{sent := Cntr,
                           get := Cntr} = State) ->
    {noreply, State, {continue, complete}};

handle_continue(timeout, #{sent := SentCntr,
                            get := GetCntr,
                            key := Key,
                            from := From} = State) ->
    Error = test_helper:format("Key ~p; Requests ~p; Responses ~p", [Key, SentCntr, GetCntr]),
    gen_server:reply(From, {error, {timeout, Error}}),
    {noreply, State};

handle_continue(_, State) ->
    {noreply, State}.

%%--------------------------------------------------------------------
%%  Call handling Callbacks
%%--------------------------------------------------------------------

 handle_call({send_transactions, Nodes, Key}, From, State) ->
    case test_helper:exec_test_transaction(Nodes, Key) of
        ok ->
            Cntr = length(Nodes),
            NewState = #{sent => Cntr,
                         get => 0,
                         key => Key,
                         set => sets:new(),
                         from => From},
            {noreply, NewState};
        error ->
            {reply, error, State}
    end.

%%--------------------------------------------------------------------
%%  Cast handling Callbacks
%%--------------------------------------------------------------------

handle_cast({log, Key1, NodeId, WorkerId},
            #{get := Cntr, key := Key, set := Set} = State) ->
    test_helper:log("Log key ~p node_id ~p worker_id ~p", [Key1, NodeId, WorkerId]),
    if
        Key =:= Key1 ->
            Set1 = sets:add_element({NodeId, WorkerId}, Set),
            NewState = State#{get => Cntr + 1, set => Set1},
            {noreply, NewState, {continue, complete}};
        true ->
            {noreply, State, {continue, complete}}
    end;

handle_cast(_Message, State) ->
    {noreply, State}.

%%--------------------------------------------------------------------
%%  Other messages handling Callbacks
%%--------------------------------------------------------------------

handle_info(_Info, State) ->
    {noreply, State}.

%%--------------------------------------------------------------------
%%  Other Callbacks
%%--------------------------------------------------------------------

terminate(_Reason, _State) ->
    ok.

code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

%%--------------------------------------------------------------------
%%
%%  Private functions
%%
%%--------------------------------------------------------------------
