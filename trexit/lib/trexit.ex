defmodule StopTime do
  defstruct [:trip_id, :stop_id, :arrival, :departure]
end

defmodule Trip do
  defstruct [:trip_id, :route_id, :service_id]
end

defmodule Trexit do
  def main(route) do
    :ets.new(:stop_times, [:named_table, {:read_concurrency, true}])
    :ets.new(:ix_stop_times_by_trip, [:named_table, {:read_concurrency, true}])
    :ets.new(:trips, [:named_table, {:read_concurrency, true}])
    :ets.new(:ix_trips_by_route, [:named_table, {:read_concurrency, true}])

    {time, _} =
      :timer.tc(fn ->
        get_stop_times()
      end)

    IO.puts("Parsed stop_times.txt in #{time / 1000} ms")

    {time, _} =
      :timer.tc(fn ->
        get_trips()
      end)

    IO.puts("Parsed trips.txt in #{time / 1000} ms")

    {time, schedule_count} =
      :timer.tc(fn ->
        case :ets.lookup(:ix_trips_by_route, route) do
          [{^route, trip_ixs}] ->
            Enum.reduce(trip_ixs, 0, fn trip_ix, acc ->
              [{^trip_ix, %Trip{trip_id: trip_id, route_id: ^route}}] =
                :ets.lookup(:trips, trip_ix)

              [{^trip_id, sts}] = :ets.lookup(:ix_stop_times_by_trip, trip_id)
              acc + length(sts)
            end)

          _ ->
            0
        end
      end)

    IO.puts("Found #{schedule_count} schedules for #{route} in #{time / 1000} ms")
  end

  defp get_stop_times() do
    [header | rest] =
      "../MBTA_GTFS/stop_times.txt"
      |> File.read!()
      |> NimbleCSV.RFC4180.parse_string(skip_headers: false)

    # assert column order
    ["trip_id", "arrival_time", "departure_time", "stop_id" | _] = header

    Enum.with_index(rest, fn [trip_id, arrival_time, departure_time, stop_id | _], i ->
      case :ets.lookup(:ix_stop_times_by_trip, trip_id) do
        [] -> :ets.insert(:ix_stop_times_by_trip, {trip_id, [i]})
        [{_, sts}] -> :ets.insert(:ix_stop_times_by_trip, {trip_id, [i | sts]})
      end

      :ets.insert(
        :stop_times,
        {i,
         %StopTime{
           trip_id: trip_id,
           stop_id: stop_id,
           arrival: arrival_time,
           departure: departure_time
         }}
      )
    end)
  end

  defp get_trips() do
    [header | rest] =
      "../MBTA_GTFS/trips.txt"
      |> File.read!()
      |> NimbleCSV.RFC4180.parse_string(skip_headers: false)

    # assert column order
    ["route_id", "service_id", "trip_id" | _] = header

    Enum.with_index(rest, fn [route_id, service_id, trip_id | _], i ->
      case :ets.lookup(:ix_trips_by_route, route_id) do
        [] -> :ets.insert(:ix_trips_by_route, {route_id, [i]})
        [{_, trips}] -> :ets.insert(:ix_trips_by_route, {route_id, [i | trips]})
      end

      :ets.insert(
        :trips,
        {i,
         %Trip{
           trip_id: trip_id,
           route_id: route_id,
           service_id: service_id
         }}
      )
    end)
  end
end
