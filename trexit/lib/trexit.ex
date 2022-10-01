defmodule StopTime do
  defstruct [:trip_id, :stop_id, :arrival, :departure]
end

defmodule Trip do
  defstruct [:trip_id, :route_id, :service_id]
end

defmodule Trexit do
  def main(route) do
    {time, stop_times} =
      :timer.tc(fn ->
        get_stop_times()
      end)

    IO.puts("Parsed stop_times.txt in #{time / 1000} ms")

    {time, trips} =
      :timer.tc(fn ->
        get_trips()
      end)

    IO.puts("Parsed trips.txt in #{time / 1000} ms")

    {time, schedule_count} =
      :timer.tc(fn ->
        route_trips =
          Enum.reduce(trips, MapSet.new(), fn t, acc ->
            if t.route_id == route, do: MapSet.put(acc, t.trip_id), else: acc
          end)

        Enum.reduce(stop_times, 0, fn st, acc ->
          if st.trip_id in route_trips, do: acc + 1, else: acc
        end)
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

    Enum.map(rest, fn [trip_id, arrival_time, departure_time, stop_id | _] ->
      %StopTime{
        trip_id: trip_id,
        stop_id: stop_id,
        arrival: arrival_time,
        departure: departure_time
      }
    end)
  end

  defp get_trips() do
    [header | rest] =
      "../MBTA_GTFS/trips.txt"
      |> File.read!()
      |> NimbleCSV.RFC4180.parse_string(skip_headers: false)

    # assert column order
    ["route_id", "service_id", "trip_id" | _] = header

    Enum.map(rest, fn [route_id, service_id, trip_id | _] ->
      %Trip{
        trip_id: trip_id,
        route_id: route_id,
        service_id: service_id
      }
    end)
  end
end
