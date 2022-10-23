defmodule Trexit.GTFS do
  def schedules_for_route(route_id) do
    case :ets.lookup(:trips_ix_by_route, route_id) do
      [{^route_id, trip_ixs}] ->
        Enum.map(trip_ixs, fn trip_ix ->
          [{_trip_ix, trip_id, _route_id, service_id}] = :ets.lookup(:trips, trip_ix)

          [{_trip_id, st_ixs}] = :ets.lookup(:stop_times_ix_by_trip, trip_id)

          %{
            "trip_id" => trip_id,
            "service_id" => service_id,
            "route_id" => route_id,
            "schedules" =>
              :ets.select(
                :stop_times,
                for(st_ix <- st_ixs, do: {{st_ix, :_, :_, :_, :_}, [], [:"$_"]})
              )
              |> Enum.map(fn {_st_ix, _trip_id, stop_id, arrival_time, departure_time} ->
                %{
                  "stop_id" => stop_id,
                  "arrival_time" => arrival_time,
                  "departure_time" => departure_time
                }
              end)
          }
        end)

      _ ->
        []
    end
  end
end
