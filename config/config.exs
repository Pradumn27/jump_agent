# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :jump_agent,
  ecto_repos: [JumpAgent.Repo],
  generators: [timestamp_type: :utc_datetime]

# Configures the endpoint
config :jump_agent, JumpAgentWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: JumpAgentWeb.ErrorHTML, json: JumpAgentWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: JumpAgent.PubSub,
  live_view: [signing_salt: "HAcsUTJ2"]

# Configures the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :jump_agent, JumpAgent.Mailer, adapter: Swoosh.Adapters.Local

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.17.11",
  jump_agent: [
    args:
      ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "3.4.3",
  jump_agent: [
    args: ~w(
      --config=tailwind.config.js
      --input=css/app.css
      --output=../priv/static/assets/app.css
    ),
    cd: Path.expand("../assets", __DIR__)
  ]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

config :ueberauth, Ueberauth,
  providers: [
    google: {
      Ueberauth.Strategy.Google,
      [
        default_scope:
          "email profile https://www.googleapis.com/auth/gmail.readonly https://www.googleapis.com/auth/calendar",
        access_type: "offline",
        prompt: "consent"
      ]
    }
  ]

config :ueberauth, Ueberauth.Strategy.Google.OAuth,
  client_id: "530016174947-s1n491d8ab8e5dsifhkgiqdj90njo1dk.apps.googleusercontent.com",
  client_secret: "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",
  redirect_uri: "http://localhost:4000/auth/google/callback"

config :jump_agent, :hubspot,
  client_id: "c5520986-8dca-4fe4-8998-aa9fbd39467c",
  client_secret: "fbfd499b-aec0-4e4a-ab72-2fb417866427",
  redirect_uri: "http://localhost:4000/auth/hubspot/callback"

config :jump_agent, :openai,
  api_key:
    "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"

config :jump_agent, JumpAgent.Repo, types: JumpAgent.PostgrexTypes

config :jump_agent, Oban,
  repo: JumpAgent.Repo,
  plugins: [
    Oban.Plugins.Pruner,
    {Oban.Plugins.Cron,
     crontab: [
       {"*/10 * * * *", JumpAgent.Workers.SyncIntegrationsWorker}
     ]}
  ],
  queues: [default: 10]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
