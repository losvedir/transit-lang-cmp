defmodule Trexit.GTFS do
  def schedules_for_route(route_id) do
    for %{trip_id: trip_id, service_id: service_id} <-
          lookup_trips_by_route(route_id) do
      %{
        trip_id: trip_id,
        service_id: service_id,
        route_id: route_id,
        schedules: schedules_for_trip(trip_id)
      }
    end
  end

  defp schedules_for_trip(trip_id) do
    for stop_time <- lookup_stop_times_by_trip(trip_id) do
      %{
        stop_id: stop_time.stop_id,
        arrival_time: stop_time.arrival,
        departure_time: stop_time.departure
      }
    end
  end

  defp lookup_trips_by_route(route_id) do
    :persistent_term.get({Trexit.GTFS, :trips_by_route})
    |> Map.get(route_id, [])
  end

  defp lookup_stop_times_by_trip(trip_id) do
    :persistent_term.get({Trexit.GTFS, :stop_times_by_trip})
    |> Map.get(trip_id, [])
  end
end
