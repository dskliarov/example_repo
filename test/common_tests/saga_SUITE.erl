-module(saga_SUITE).

-compile(nowarn_export_all).
-compile(export_all).

-include_lib("common_test/include/ct.hrl").
-include_lib("eunit/include/eunit.hrl").

-define(WORKFLOW, "Elixir.Meta.Saga.Test.WorkflowOne").
%%--------------------------------------------------------------------
%%  COMMON TEST CALLBACK FUNCTIONS
%%
%%  Suite Level Setup
%%--------------------------------------------------------------------

suite() ->
    [
     {timetrap, {minutes, 10}}
    ].

init_per_suite(_Config) ->
    test_helper:start_deps(),
    test_helper:start_core(),
    test_helper:load_env_variables(),
    Nodes = [dev1, dev2, dev3, dev4, dev5],
    SagaNode = saga,
    SortedNodes = lists:sort(Nodes),
    [
     {nodes, SortedNodes},
     {saga_node, SagaNode}
    ].

end_per_suite(_Config) ->
    test_helper:stop_deps(),
    test_helper:stop_core(),
    ok.

%%--------------------------------------------------------------------
%%  Group level Setup
%%--------------------------------------------------------------------

init_per_group(GroupName, Config) ->
    ?MODULE:GroupName({prelude, Config}).

end_per_group(GroupName, Config) ->
    ?MODULE:GroupName({postlude, Config}).

%%--------------------------------------------------------------------
%%  Test level Setup
%%--------------------------------------------------------------------

init_per_test_case(TestCase, Config) ->
    ?MODULE:TestCase({prelude, Config}).

end_per_test_case(TestCase, Config) ->
    ?MODULE:TestCase({poslude, Config}).

%%--------------------------------------------------------------------
%%  Group
%%--------------------------------------------------------------------

groups() ->
    [{saga_group,
      [{repeat_until_any_fail, 1}],
      [
       saga_happy_path
      ]
     }].

all() ->
    [
     {group, saga_group}
    ].

%%--------------------------------------------------------------------
%% TEST CASES
%%--------------------------------------------------------------------

%%--------------------------------------------------------------------
%% Function: TestCase(Config0) ->
%%               ok | exit() | {skip,Reason} | {comment,Comment} |
%%               {save_config,Config1} | {skip_and_save,Reason,Config1}
%%
%% Config0 = Config1 = [tuple()]
%%   A list of key/value pairs, holding the test case configuration.
%% Reason = term()
%%   The reason for skipping the test case.
%% Comment = term()
%%   A comment about the test case that will be printed in the html log.
%%
%% Description: Test case function. (The name of it must be specified in
%%              the all/0 list or in a test case group for the test case
%%              to be executed).
%%--------------------------------------------------------------------

saga_group({prelude, Config}) ->
    Nodes = proplists:get_value(nodes, Config),
    SagaNode = proplists:get_value(saga_node, Config),
    ClusterInfo = test_helper:start_nodes(Nodes, #{}),
    SagaInfo = test_helper:start_client_node(SagaNode, #{}),
    [{cluster_info, ClusterInfo}, {saga_info, SagaInfo}|Config];
saga_group({postlude, Config}) ->
    Nodes = proplists:get_value(nodes, Config),
    test_helper:stop_app_on_nodes(Nodes),
    ok.

saga_happy_path({info, _Config}) ->
    ["Test to validate base saga functionality.",
     "Run Saga state machine: Happy Path"];
saga_happy_path(suite) ->
    [];
saga_happy_path({prelude, Config}) ->
    Config;
saga_happy_path({postlude, _Config}) ->
    ok;
saga_happy_path(Config) ->
    SagaNode = proplists:get_value(saga_node, Config),
    workflow_one(SagaNode).

%%--------------------------------------------------------------------
%% Private functions
%%--------------------------------------------------------------------

workflow_one(Node) ->
    SagaResult = test_helper:rpc_call(Node, ?WORKFLOW, exec_saga),
    ExpectedResult = test_helper:rpc_call(Node, ?WORKFLOW, expected_history),
    ?assertMatch(ExpectedResult, SagaResult).
