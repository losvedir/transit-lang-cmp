defmodule Trexit.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      Trexit.GTFS.Loader,
      {Bandit, plug: Trexit.Endpoint}
    ]

    opts = [strategy: :one_for_one, name: Trexit.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
