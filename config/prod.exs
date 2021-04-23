import Config

config :etcd_client,
  endpoints: {:system, "AEON_ETCD_CLUSTER"},
  user: {:system, "AEON_ETCD_USER"},
  password: {:system, "AEON_ETCD_PASSWORD"}

config :wizard,
  transports: [
    {GrpcTransport, codec: Codec.Identity},
    {RabbitTransport, codec: Codec.Etf}
  ],
  lrc_endpoint: [enabled: true, port: 3000, ip: "0.0.0.0", checkpoints: [], expected_app: :saga_v2]

config :grpc_transport,
  listen: {'0.0.0.0', 9000}, use_dns: true, tld: "aeon-services.svc.cluster.local"

config :rabbit_transport,
  conn_opts: {{:system, "AEON_RABBITMQ_SERVICE_HOST"},
              {:system, "AEON_RABBITMQ_SERVICE_PORT"}},
  # This is temporary credentials. Will be loaded from env_vars
  security: {"aeon", "aeon"}
