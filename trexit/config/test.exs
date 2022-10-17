import Config

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :trexit, TrexitWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "Rfu5oAgMlu6c/GPjwb6hdVhB38CCmCHMGyGkFQ0eX9Y4EYXJegB/mGQ9Qv1RovOx",
  server: false

# In test we don't send emails.
config :trexit, Trexit.Mailer,
  adapter: Swoosh.Adapters.Test

# Print only warnings and errors during test
config :logger, level: :warn

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime
