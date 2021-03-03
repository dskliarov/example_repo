import Config

config :saga2,
  conn_opts: [{{:system, "AEON_ETCD_SERVICE_HOST"},
               {:system, "AEON_ETCD_SERVICE_PORT"}}]

config :wizard,
  transports: [
    {GrpcTransport, codec: Codec.Identity},
    {RabbitTransport, codec: Codec.Etf}
  ],
  lrc_endpoint: [enabled: true, port: 3000, ip: "127.0.0.1", checkpoints: [], expected_app: :saga]

config :grpc_transport,
  listen: {'0.0.0.0', 9000}, use_dns: true, tld: "aeon-services.svc.cluster.local"

config :rabbit_transport,
  conn_opts: {{:system, "AEON_RABBITMQ_SERVICE_HOST"},
              {:system, "AEON_RABBITMQ_SERVICE_PORT"}},
  # This is temporary credentials. Will be loaded from env_vars
  security: {"aeon", "aeon"}
