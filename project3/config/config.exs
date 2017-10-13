# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.
use Mix.Config

# General application configuration
config :project3,
  ecto_repos: [Project3.Repo]

# Configures the endpoint
config :project3, Project3.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "Ze4UFYBtYuxdLM1vykVlWTh1O+JPUgsku8W8EgkhVO6/HgvxLTMxCiIdvgjjOgx/",
  render_errors: [view: Project3.ErrorView, accepts: ~w(html json)],
 # username: "sheikht",
 # password: "postgres",
  pubsub: [name: Project3.PubSub,
           adapter: Phoenix.PubSub.PG2]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env}.exs"
