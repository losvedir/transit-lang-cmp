defmodule Trexit.GTFS.Loader do
  use GenServer

  require Logger

  def start_link(_) do
    GenServer.start_link(__MODULE__, [])
  end

  def init(_) do
    Logger.info("starting Trexit.GTFS")
    {:ok, [], {:continue, :load_gtfs}}
  end

  def handle_continue(:load_gtfs, state) do
    Logger.info("loading GTFS")
    load()
    Logger.info("finished loading GTFS")
    {:noreply, state}
  end

  def load() do
    :ets.new(:stop_times, [:named_table, :duplicate_bag, read_concurrency: true])
    :ets.new(:trips, [:named_table, :duplicate_bag, read_concurrency: true])

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

  defp get_stop_times() do
    stream =
      "../MBTA_GTFS/stop_times.txt"
      |> File.stream!()
      |> NimbleCSV.RFC4180.parse_stream(skip_headers: false)

    # assert column order
    ["trip_id", "arrival_time", "departure_time", "stop_id"] ++ _ = Enum.fetch!(stream, 0)

    stream
    |> Stream.drop(1)
    |> Enum.each(fn [trip_id, arrival_time, departure_time, stop_id] ++ _ ->
      :ets.insert(
        :stop_times,
        {trip_id, %{arrival_time: arrival_time, departure_time: departure_time, stop_id: stop_id}}
      )
    end)
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
    |> Enum.each(fn [route_id, service_id, trip_id] ++ _ ->
      :ets.insert(:trips, {route_id, %{service_id: service_id, trip_id: trip_id}})
    end)
  end
end
