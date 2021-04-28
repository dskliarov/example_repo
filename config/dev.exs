import Config

config :saga_v2,
  conn_opts: [{'127.0.0.1', 2379}]

config :wizard,
  transports: [
    {GrpcTransport, codec: Codec.Identity},
    {RabbitTransport, codec: Codec.Etf}
  ]

config :grpc_transport,
  listen: {'0.0.0.0', 9104}

config :rabbit_transport, :conn_opts, {'127.0.0.1', 5672}


