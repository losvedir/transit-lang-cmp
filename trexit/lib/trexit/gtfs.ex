defmodule Trexit.GTFS do
  def schedules_for_route(route_id) do
    :trips
    |> :ets.lookup(route_id)
    |> Enum.map(fn {_key, %{trip_id: trip_id} = route} ->
      schedules =
        :stop_times
        |> :ets.lookup(trip_id)
        |> Enum.map(fn {_key, schedule} -> schedule end)

      Map.merge(route, %{route_id: route_id, schedules: schedules})
    end)
  end
end
