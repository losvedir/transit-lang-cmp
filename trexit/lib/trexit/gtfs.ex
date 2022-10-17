defmodule Trexit.GTFS do
  alias Trexit.GTFS.StopTime
  alias Trexit.GTFS.Trip

  def schedules_for_route(route_id) do
    case :ets.lookup(:trips_ix_by_route, route_id) do
      [{^route_id, trip_ixs}] ->
        Enum.map(trip_ixs, fn trip_ix ->
          [{^trip_ix, %Trip{trip_id: trip_id, route_id: ^route_id, service_id: service_id}}] =
            :ets.lookup(:trips, trip_ix)

          [{^trip_id, st_ixs}] = :ets.lookup(:stop_times_ix_by_trip, trip_id)

          %{
            "trip_id" => trip_id,
            "service_id" => service_id,
            "route_id" => route_id,
            "schedules" =>
              Enum.map(st_ixs, fn st_ix ->
                [{^st_ix, %StopTime{} = stop_time}] = :ets.lookup(:stop_times, st_ix)

                %{
                  "stop_id" => stop_time.stop_id,
                  "arrival_time" => stop_time.arrival,
                  "departure_time" => stop_time.departure
                }
              end)
          }
        end)

      _ ->
        []
    end
  end
end
