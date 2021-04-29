import Config

config :logger,
  backends: [:console],
  compile_time_purge_matching: [
    [level_lower_than: :debug]
  ]

config :logger, :console,
  truncate: :infinity,
  format: "{ date=$date time=$time level=$level event=$message $metadata }\n",
  metadata: :all

config :distributed_lib,
  watch_topic_prefix: "saga"

if File.exists?("./config/#{Mix.env()}.exs") do
  import_config "#{Mix.env()}.exs"
end
