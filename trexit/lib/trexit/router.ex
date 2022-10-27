defmodule Trexit.Router do
  use Plug.Router

  require Logger

  def init(opts) do
    Logger.info("Initialized #{__MODULE__}")
    opts
  end

  plug :match

  if Mix.env() == :dev do
    plug Plug.Logger
  end

  plug :dispatch

  get "/schedules/:route" do
    payload =
      route
      |> Trexit.GTFS.schedules_for_route()
      |> Jsonrs.encode!(lean: true)

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, payload)
  end
end
