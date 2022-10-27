defmodule Trexit.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      Trexit.GTFS.Loader,
      {Plug.Cowboy, scheme: :http, plug: Trexit.Router, options: [port: 4000]}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Trexit.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
