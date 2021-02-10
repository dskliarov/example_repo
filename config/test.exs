import Config

config :wizard,
  transports: [
    {GrpcTransport, codec: Codec.Identity},
    {RabbitTransport, codec: Codec.Etf}
  ]

config :grpc_transport,
  listen: {{:system, "SVC_META_SAGA2_SERVICE_HOST"}, 
            {:system, "SVC_META_SAGA2_SERVICE_PORT"}}
#   listen: {'0.0.0.0', 9001}
   
  config :rabbit_transport,
  conn_opts: {{:system, "AEON_RABBITMQ_SERVICE_HOST"},
              {:system, "AEON_RABBITMQ_SERVICE_PORT"}}
