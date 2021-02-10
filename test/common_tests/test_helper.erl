-module(test_helper).

-include_lib("common_test/include/ct.hrl").

-export([
         timestamp/1,
         start_app_on_nodes/1,
         stop_app_on_nodes/0,
         stop_app_on_nodes/1,
         start_nodes/2,
         start_client_node/2,
         start_node/2,
         start_app/1,
         stop_app/1,
         node_name/1,
         rpc_call/3,
         rpc_call/4,
         rpc_call/7,
         format/2,
         find_ring_node/2,
         ring_nodes/1,
         erl_elixir_dir/0
        ]).

-export([
         start_deps/0,
         start_core/0,
         stop_deps/0,
         stop_core/0,
         load_env_variables/0
        ]).

-export([
         start_app_remote/3
        ]).

-export([
         ct_run/0
        ]).

-define(COMPOSE_FILE, "ops/docker/docker-compose.yml").
-define(LIB_DIR, "_build/dev/lib").
-define(ELIXIR_BIN_DIR, "elixir/ebin/").
-define(ELIXIR_LOGGER_BIN_DIR, "logger/ebin/").
-define(HASH_RING, 'Elixir.DistributedLib.Processor.HashRing').
-define(SCHEDULER, 'Elixir.DistributedLib.Cron.Scheduler').
-define(DISTRIBUTED_LIB, 'Elixir.DistributedLib').
-define(DEFAULT_MAP, {0, sets:new()}).
-define(ELIXIR_CONFIG, 'Elixir.Config.Reader').
-define(ELIXIR_APP, 'Elixir.Application').
%%--------------------------------------------------------------------
%%  etcd
%%--------------------------------------------------------------------
start_deps() ->
    start_service("rabbitmq etcd riak_coordinator riak_member").

start_core() ->
    start_service("meta_core", "service").

stop_deps() ->
    stop_services().

stop_core() ->
    stop_services("meta_core").

start_service(Service) ->
    Command = up_command(Service),
    exec_os_command(Command).

start_service(ProjectName, Service) ->
    Command = up_command(ProjectName, Service),
    exec_os_command(Command).

stop_services() ->
    Command = down_command(),
    exec_os_command(Command).

stop_services(ProjectName) ->
    Command = down_command(ProjectName),
    exec_os_command(Command).

load_env_variables() ->
    load_env_variables_riak(),
    load_env_variables_service("CORE", "9000"),
    load_env_variables_service("SAGA2", "9001"),
    load_env_variables_service("TEST_SAGA", "9002").

load_env_variables_riak() ->
    load_env_variables_paires("AEON_RIAK_SERVICE", "8087").

load_env_variables_service(Service, Port) ->
    Prefix = service_env_var_prefix(Service),
    load_env_variables_paires(Prefix, Port).

load_env_variables_paires(Prefix, Port) ->
    HostEnvVar = env_var_name(Prefix, "HOST"),
    PortEnvVar = env_var_name(Prefix, "PORT"),
    os:putenv(HostEnvVar, "127.0.0.1"),
    os:putenv(PortEnvVar, Port).

env_var_name(Prefix, PortOrHost) ->
    format("~s_~s", [Prefix, PortOrHost]).

service_env_var_prefix(ServiceName) ->
    format("SVC_META_~s_SERVICE", [ServiceName]).

%%--------------------------------------------------------------------
%%  Reomote application
%%--------------------------------------------------------------------
start_app_on_nodes(Nodes) ->
    lists:map(fun start_app/1, Nodes).

stop_app_on_nodes() ->
    Nodes = nodes(),
    stop_app_on_nodes(Nodes).

stop_app_on_nodes(Nodes) ->
    lists:map(fun stop_app1/1, Nodes).

start_app(Node) ->
    start_app(saga2, Node).

start_app(Application, Node) when is_atom(Node) ->
    Node1 = node_name(Node),
    ct_slave:stop(Node1),
    log("Starting node ~s~n", [Node1]),
    Options = app_options(),
    StartResult = ct_slave:start(Node1, Options),
    log("Node ~p start result: ~p~n", [Node1, StartResult]),
    Node2 = node_from_result(StartResult),
    start_app_remote(Application, Node2),
    Node2.

stop_app(Node) when is_atom(Node)->
    Node1 = node_name(Node),
    Result = ct_slave:stop(Node1),
    log("Node ~p stoped with result: ~p", [Node1, Result]),
    {Node1, Result}.

stop_app1(Node) when is_atom(Node)->
    Result = ct_slave:stop(Node),
    log("Node ~p stoped with result: ~p", [Node, Result]),
    {Node, Result}.

%%--------------------------------------------------------------------
%%  Private functions
%%--------------------------------------------------------------------

node_name(Node) ->
    case persistent_term:get(Node, nil) of
        nil ->
            Node1 = atom_to_list(Node),
            IsLongName = is_long_name(Node1),
            Node2 = generate_node_name(IsLongName, Node1, Node),
            persistent_term:put(Node, Node2),
            Node2;
        CachedNode ->
            CachedNode
    end.

is_long_name(Node) ->
    case string:str(Node, "@") of
        0 ->
            false;
        _ ->
            true
    end.

generate_node_name(true, _Node, NodeAtom) ->
   NodeAtom;

generate_node_name(_ShortName, Node, _NodeAtom) ->
    HostName = get_host_name(),
    Node1 = format("~s@~s",[Node, HostName]),
    list_to_atom(Node1).

get_host_name() ->
    Node = node(),
    NodeString = atom_to_list(Node),
    [_|[Host]] = string:split(NodeString, "@"),
    Host.

docker_command(Command) ->
    ComposeFile = compose_file(),
    format("docker-compose -f ~s ~s", [ComposeFile, Command]).

docker_command(ProjectName, Command) ->
    ComposeFile = compose_file(ProjectName),
    format("docker-compose -f ~s ~s", [ComposeFile, Command]).

up_command(Service) ->
    Command = format("up -d --remove-orphans ~s", [Service]),
    docker_command(Command).

up_command(ProjectName, Service) ->
    Command = format("up -d --remove-orphans ~s", [Service]),
    docker_command(ProjectName, Command).

down_command() ->
    docker_command("down").

down_command(ProjectName) ->
    docker_command(ProjectName, "down").

log(String) ->
    log("~s~n", [String]).

exec_os_command(Command) ->
    Result = os:cmd(Command),
    Result1 = string:tokens(Result, "\r\n"),
    lists:foreach(fun log/1, Result1).

compose_file() ->
    path(?COMPOSE_FILE).

compose_file(ProjectName) ->
    Prefix = format("deps/~s", [ProjectName]),
    path(Prefix, ?COMPOSE_FILE).

project_root_directory() ->
    FilePath = code:which(?MODULE),
    [ProjectDirectory|_] = string:split(FilePath, "test"),
    [ProjectDirectory1|_] = string:split(ProjectDirectory, "_build"),
    ProjectDirectory1.

erl_app_dir(LibDirectory, Application) ->
    format("-pa ~s/~s/ebin/", [LibDirectory, Application]).

erl_elixir_dir(Dir1) ->
    FilePath = os:cmd("elixir -e ':code.which(Elixir.Kernel)|> IO.write()'"),
    Dir = filename:dirname(FilePath),
    [ElixirInstallDir|_] = string:split(Dir, "bin"),
    format("-pa ~s", [filename:join([ElixirInstallDir, "lib", Dir1])]).

erl_elixir_dir() ->
    ElixirDir = erl_elixir_dir(?ELIXIR_BIN_DIR),
    LoggerDir = erl_elixir_dir(?ELIXIR_LOGGER_BIN_DIR),
    format("~s ~s", [ElixirDir, LoggerDir]).

erl_app_flags() ->
    LibDirectory = path(?LIB_DIR),
    {ok, ListDirectories} = file:list_dir(LibDirectory),
    Flags = [erl_app_dir(LibDirectory, A) || A <- ListDirectories],
    Flags1 = lists:join(" ", Flags),
    lists:flatten(Flags1).

erl_flags() ->
    App = erl_app_flags(),
    Elixir = erl_elixir_dir(),
    Flags = [App, Elixir],
    Flags1 = lists:join(" ", Flags),
    lists:flatten(Flags1).

app_env() ->
    LibDir = filename:absname(?LIB_DIR),
    {"ERL_LIBS", LibDir}.

app_options() ->
    [{boot_timeout, 3},
     {monitor_master, true},
     {env, [app_env()]},
     {erl_flags, erl_flags()}
    ].

log(Format, Parameters) ->
    ct:comment(Format, Parameters),
    ct:log(info, ?STD_IMPORTANCE, Format, Parameters).

node_from_result({error, Reason, Node}) when Reason == started_not_connected;
                                             Reason == already_stared ->
    Node;
node_from_result({ok, Node}) ->
    Node.

applications_to_start(Application) when is_atom(Application) ->
    [elixir, compiler, logger, Application].

log_rpc_call_result(_OperationDescription, _Node, Result, false) ->
    Result;
log_rpc_call_result(OperationDescription, Node, Result, _) ->
    log("The result of ~s on node ~p is ~p", [OperationDescription, Node, Result]),
    Result.

rpc_call(Node, Module, Function) ->
    rpc_call(Node, Module, Function).

rpc_call(Node, Module, Function, Arguments) ->
    Node1 = node_name(Node),
    DescriptionFormat = "RPC call to Node: ~p, Module: ~p, Function: ~p, Arguments: ~p~n",
    DescriptionArgs = [Node1, Module, Function, Arguments],
    rpc_call(Node1, Module, Function, Arguments, DescriptionFormat, DescriptionArgs, true).

rpc_call(Node, Module, Function, Arguments, DescriptionFormat, DescriptionArgs, ProcessPrint) ->
    Node1 = node_name(Node),
    OperationDescription = format(DescriptionFormat, DescriptionArgs),
    rpc_call(Node1, Module, Function, Arguments, OperationDescription, ProcessPrint).

rpc_call(Node, Module, Function, Arguments, OperationDescription, ProcessPrint) ->
    Node1 = node_name(Node),
    Result = rpc:call(Node1, Module, Function, Arguments),
    log_rpc_call_result(OperationDescription, Node1, Result, ProcessPrint).

start_app_remote(Application, Node) ->
    Config = rpc_call(Node, ?ELIXIR_CONFIG, 'read!', [<<"config/test.exs">>],
                  "application ~p read config", [Application], false),
    log("Read config result ~p",[Config]),
    Config1 = rpc_call(Node, ?ELIXIR_APP, put_all_env, [Config],
                   "application ~p load env", [Application], false),
    log("Load environment result ~p",[Config1]),
    Applications = applications_to_start(Application),
    start_app_remote(Node, Applications, []).

start_app_remote(Node, [], Results) ->
    log("Applications start on Node ~p with result ~p",
        [Node, Results]),
    ok;
start_app_remote(Node, [Application | Applications], Results) ->
    Result = rpc_call(Node, application, ensure_all_started, [Application],
                      "application start ~p", [Application], false),
    start_app_remote(Node, Applications, [{Application, Result} | Results]).

start_nodes([], Acc) ->
    Acc;

start_nodes([Node|Nodes], Acc) ->
    Acc1 = start_node(Node, Acc),
    start_nodes(Nodes, Acc1).

start_node(Node, Acc) ->
    start_node(saga2, Node, Acc).

start_client_node(Node, Acc) ->
    start_node(test_saga, Node, Acc).

start_node(Application, Node, Acc) ->
    Node1 = start_app(Application, Node),
    wait_for_node(Node1, Application),
    wait_for_ready(Node1),
    {ok, NodeId} = node_id(Node1),
    Acc1 = maps:put(Node, NodeId, Acc),
    Acc2 = maps:put(NodeId, Node, Acc1),
    Acc3 = maps:put(Node1, NodeId, Acc2),
    maps:put(NodeId, Node1, Acc3).

find_ring_node(Node, Key) ->
    rpc_call(Node, ?HASH_RING, find_ring_node, [Key]).

is_ready(Node) ->
    rpc_call(Node, ?DISTRIBUTED_LIB, is_ready, []).

ring_nodes(Node) ->
    rpc_call(Node, ?HASH_RING, ring_nodes, []).

node_id(Node) ->
    rpc_call(Node, ?HASH_RING, local_node_id, []).

timestamp(TimeSpanSeconds) ->
    os:system_time(millisecond) + TimeSpanSeconds.

wait_for_node_delayed(Node, Application) ->
    timer:sleep(2000),
    wait_for_node(Node, Application).

wait_for_ready_delayed(Node, Counter) ->
    timer:sleep(2000),
    wait_for_ready(Node, Counter - 1).

wait_for_ready(Node) ->
    wait_for_ready(Node, 10).

wait_for_ready(Node, Counter) when Counter < 0 ->
    log("Node ~p is not ready~n", [Node]),
    {error, not_ready};

wait_for_ready(Node, Counter) ->
    case is_ready(Node) of
        ready ->
            ok;
        {not_ready, _} ->
            wait_for_ready_delayed(Node, Counter)
    end.

wait_for_node(Application, Node) ->
    Nodes = nodes(),
    case lists:member(Node, Nodes) of
        true ->
            is_application_started(Application, Node);
        false ->
            wait_for_node_delayed(Node, Application)
    end.

is_application_started(Application, Node) ->
    case rpc_call(Node, application, which_applications, []) of
        {badrpc, nodedown} ->
            wait_for_node_delayed(Node, Application);
        Applications ->
            StartedDistributedLib = lists:any(
                                       fun(AppTuple) ->
                                               is_app_started(AppTuple, Application)
                                       end, Applications),
            check_node_status(StartedDistributedLib, Applications, Application)
    end.

check_node_status(true, _Node, _Application) ->
    ok;
check_node_status(_NotStarted, Node, Application) ->
    wait_for_node_delayed(Node, Application).

is_app_started({Application, _Description, _Version}, Application) ->
    true;
is_app_started(_, _) ->
    false.

path(Prefix, RelativePath) ->
    RelativePath1 = format("~s/~s", [Prefix, RelativePath]),
    path(RelativePath1).

path("deps/" ++ _ = RelativePath) ->
    ProjectDirectory = project_root_directory(),
    format("~s~s", [ProjectDirectory, RelativePath]);

path(RelativePath) ->
    ProjectDirectory = project_root_directory(),
    format("~s~s", [ProjectDirectory, RelativePath]).

format(FormatString, Data) ->
    String = io_lib:format(FormatString, Data),
    lists:flatten(String).

ct_run() ->
    ct:run("test/common_tests/", saga_SUITE).
