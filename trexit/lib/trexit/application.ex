defmodule Trexit.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      Trexit.GTFS.Loader,
      {Plug.Cowboy,
       plug: Trexit.Endpoint,
       scheme: :http,
       port: System.get_env("PORT", "4000") |> String.to_integer(),
       # Cowboy kills the connection every 100 requests by default, so we bump it up
       protocol_options: [max_keepalive: 5_000_000]}
    ]

    opts = [strategy: :one_for_one, name: Trexit.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
