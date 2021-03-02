import Config

config :wizard,
  transports: [
    {GrpcTransport, codec: Codec.Identity},
    {RabbitTransport, codec: Codec.Etf}
  ]

config :grpc_transport,
  listen: {'0.0.0.0', 9002}

config :rabbit_transport,
  conn_opts: {{:system, "AEON_RABBITMQ_SERVICE_HOST"},
              {:system, "AEON_RABBITMQ_SERVICE_PORT"}}
