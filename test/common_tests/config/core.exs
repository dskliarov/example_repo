import Config

config :wizard,
  transports: [
    {GrpcTransport, codec: Codec.Identity},
    {RabbitTransport, codec: Codec.Etf}
  ]

config :grpc_transport,
  listen: {'0.0.0.0', 9000}

config :rabbit_transport,
  conn_opts: {"localhost", 5672}

config :core,
  riak_conn_opts: {"localhost", 8087},
  riak_opts: [security_mode: false],
  pool_config: {:meta_core, [size: 50, max_overflow: 0]},
  storage_module: MetaCore.Storage.Riak,
  storage_opts: [],
  notifier: MetaCore.Notifier.Mock
