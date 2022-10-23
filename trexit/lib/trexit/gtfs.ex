defmodule Trexit.GTFS do
  alias Trexit.GTFS.StopTime
  alias Trexit.GTFS.Trip

  def schedules_for_route(route_id) do
    :ets.lookup_element(:trips_by_route, route_id, 2)
    |> Enum.map(fn %Trip{trip_id: trip_id, route_id: ^route_id, service_id: service_id} ->
      stop_times = :ets.lookup_element(:stop_times_by_trip, trip_id, 2)

      %{
        "trip_id" => trip_id,
        "service_id" => service_id,
        "route_id" => route_id,
        "schedules" =>
          Enum.map(stop_times, fn %StopTime{} = stop_time ->
            %{
              "stop_id" => stop_time.stop_id,
              "arrival_time" => stop_time.arrival,
              "departure_time" => stop_time.departure
            }
          end)
      }
    end)
  end
end
