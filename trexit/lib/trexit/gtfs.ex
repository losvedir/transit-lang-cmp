defmodule Trexit.GTFS do
  @compile :inline_list_funcs

  def schedules_for_route(route_id) do
    :lists.map(
      fn %{trip_id: trip_id, service_id: service_id} ->
        %{
          trip_id: trip_id,
          service_id: service_id,
          route_id: route_id,
          schedules: schedules_for_trip(trip_id)
        }
      end,
      lookup_trips_by_route(route_id)
    )
  end

  defp schedules_for_trip(trip_id) do
    :lists.map(
      fn %{
           stop_id: stop_id,
           arrival: arrival,
           departure: departure
         } ->
        %{
          stop_id: stop_id,
          arrival_time: arrival,
          departure_time: departure
        }
      end,
      lookup_stop_times_by_trip(trip_id)
    )
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
