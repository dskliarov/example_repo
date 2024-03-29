import Config

config :saga_v2,
  conn_opts: [{{:system, "AEON_ETCD_SERVICE_HOST"},
               {:system, "AEON_ETCD_SERVICE_PORT"}}]

config :wizard,
  transports: [
    {GrpcTransport, codec: Codec.Identity},
    {RabbitTransport, codec: Codec.Etf}
  ]

config :distributed_lib,
  watch_topic_prefix: "saga"

config :grpc_transport,
  listen: {'0.0.0.0', 9001}

config :rabbit_transport,
  conn_opts: {{:system, "AEON_RABBITMQ_SERVICE_HOST"},
              {:system, "AEON_RABBITMQ_SERVICE_PORT"}}
