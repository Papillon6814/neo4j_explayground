import Config

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :neo4j_explayground, Neo4jExplaygroundWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "D17LRz4VbMxDVFYgGf5k4bYJHIgSkRVlikR/D0FDSJ+2dArbzzOPxpMIurg9AVKo",
  server: false

# In test we don't send emails.
config :neo4j_explayground, Neo4jExplayground.Mailer,
  adapter: Swoosh.Adapters.Test

# Print only warnings and errors during test
config :logger, level: :warn

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

config :bolt_sips, Bolt,
  url: "bolt://localhost:7687",
  basic_auth: [username: "neo4j", password: "Killer123?"]
