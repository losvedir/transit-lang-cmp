defmodule TrexitWeb.ScheduleController do
  use TrexitWeb, :controller

  def show(conn, %{"route_id" => route_id}) do
    json(conn, Trexit.GTFS.schedules_for_route(route_id))
  end
end
