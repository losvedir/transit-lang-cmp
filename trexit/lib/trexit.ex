defmodule Trexit do
  alias :persistent_term, as: PersistentTerm

  require Logger

  @stop_times_key {__MODULE__, :stop_times}
  @trips_key {__MODULE__, :trips}

  def schedules_for_route(route_id) do
    stop_times = PersistentTerm.get(@stop_times_key)

    @trips_key
    |> PersistentTerm.get()
    |> Map.get(route_id, [])
    |> Enum.map(fn %{trip_id: trip_id} = route ->
      schedules = Map.get(stop_times, trip_id, [])

      Map.merge(route, %{route_id: route_id, schedules: schedules})
    end)
  end

  def load() do
    {time, _} =
      :timer.tc(fn ->
        get_stop_times()
      end)

    Logger.info("Parsed stop_times.txt in #{time / 1000} ms")

    {time, _} =
      :timer.tc(fn ->
        get_trips()
      end)

    Logger.info("Parsed trips.txt in #{time / 1000} ms")
  end

  def unload() do
    PersistentTerm.erase(@stop_times_key)
    PersistentTerm.erase(@trips_key)
  end

  defp get_stop_times() do
    stream =
      "../MBTA_GTFS/stop_times.txt"
      |> File.stream!()
      |> NimbleCSV.RFC4180.parse_stream(skip_headers: false)

    # assert column order
    ["trip_id", "arrival_time", "departure_time", "stop_id"] ++ _ = Enum.fetch!(stream, 0)

    stream
    |> Stream.drop(1)
    |> Stream.map(fn [trip_id, arrival_time, departure_time, stop_id] ++ _ ->
      {trip_id,
       %{
         arrival_time: arrival_time,
         departure_time: departure_time,
         stop_id: stop_id
       }}
    end)
    |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
    |> then(&PersistentTerm.put(@stop_times_key, &1))
  end

  defp get_trips() do
    stream =
      "../MBTA_GTFS/trips.txt"
      |> File.stream!()
      |> NimbleCSV.RFC4180.parse_stream(skip_headers: false)

    # assert column order
    ["route_id", "service_id", "trip_id"] ++ _ = Enum.fetch!(stream, 0)

    stream
    |> Stream.drop(1)
    |> Stream.map(fn [route_id, service_id, trip_id] ++ _ ->
      {route_id,
       %{
         service_id: service_id,
         trip_id: trip_id
       }}
    end)
    |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
    |> then(&PersistentTerm.put(@trips_key, &1))
  end
end
