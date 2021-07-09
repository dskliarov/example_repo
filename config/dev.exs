import Config

config :etcd_client,
       endpoints: "172.20.0.4:2379"

config :wizard,
  transports: [
    {GrpcTransport, codec: Codec.Identity},
    {RabbitTransport, codec: Codec.Etf}
  ]

config :grpc_transport,
  listen: {'0.0.0.0', 9000}

config :rabbit_transport, :conn_opts, {'172.20.0.2', 5672}


