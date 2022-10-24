defmodule Trexit.GTFS.Loader do
  use GenServer
  require Logger

  alias Trexit.GTFS.StopTime
  alias Trexit.GTFS.Trip

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
    {time, _} =
      :timer.tc(fn ->
        get_stop_times()
      end)

    Logger.warning("Parsed stop_times.txt in #{time / 1000} ms")

    {time, _} =
      :timer.tc(fn ->
        get_trips()
      end)

    Logger.warning("Parsed trips.txt in #{time / 1000} ms")
  end

  defp get_stop_times() do
    [header | rest] =
      "../MBTA_GTFS/stop_times.txt"
      |> File.read!()
      |> NimbleCSV.RFC4180.parse_string(skip_headers: false)

    # assert column order
    ["trip_id", "arrival_time", "departure_time", "stop_id" | _] = header

    rest
    |> Enum.map(fn [trip_id, arrival_time, departure_time, stop_id | _] ->
      %StopTime{
        trip_id: trip_id,
        stop_id: stop_id,
        arrival: arrival_time,
        departure: departure_time
      }
    end)
    |> Enum.group_by(& &1.trip_id)
    |> then(&:persistent_term.put({Trexit.GTFS, :stop_times_by_trip}, &1))
  end

  defp get_trips() do
    [header | rest] =
      "../MBTA_GTFS/trips.txt"
      |> File.read!()
      |> NimbleCSV.RFC4180.parse_string(skip_headers: false)

    # assert column order
    ["route_id", "service_id", "trip_id" | _] = header

    rest
    |> Enum.map(fn [route_id, service_id, trip_id | _] ->
      %Trip{
        trip_id: trip_id,
        route_id: route_id,
        service_id: service_id
      }
    end)
    |> Enum.group_by(& &1.route_id)
    |> then(&:persistent_term.put({Trexit.GTFS, :trips_by_route}, &1))
  end
end
