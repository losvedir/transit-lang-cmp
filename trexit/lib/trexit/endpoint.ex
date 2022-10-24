defmodule Trexit.Endpoint do
  use Plug.Router

  plug :match
  plug :dispatch

  get "/schedules/:route_id" do
    json(conn, Trexit.GTFS.schedules_for_route(route_id))
  end

  defp json(conn, json) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, Jsonrs.encode_to_iodata!(json))
  end
end
