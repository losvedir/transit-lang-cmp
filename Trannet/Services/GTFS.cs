using System.Diagnostics;
using Trannet.Helpers;

namespace Trannet.Services;
internal static class GTFS
{
  public static (List<Trip> trips, Dictionary<string, List<int>> tripsIxByRoute) LoadTrips()
  {
    using var f = File.OpenRead(@"../MBTA_GTFS/trips.txt");
    using var reader = new StreamReader(f);

    string[] header = reader.ReadLine().Split(",");

    Debug.Assert(header[0] == "route_id");
    Debug.Assert(header[1] == "service_id");
    Debug.Assert(header[2] == "trip_id");

    var trips = new List<Trip>();
    var tripsIxByRoute = new Dictionary<string, List<int>>();

    int i = 0;

    do
    {
      var line = reader.ReadLine().AsSpan();

      var parts = line.Split(',');

      parts.MoveNext();
      var routeID = new string(parts.CurrentValue);

      parts.MoveNext();
      var serviceID = new string(parts.CurrentValue);

      parts.MoveNext();
      var tripID = new string(parts.CurrentValue);

      trips.Add(new Trip(tripID, routeID, serviceID));

      if (!tripsIxByRoute.TryGetValue(routeID, out var list))
      {
        list = new List<int>();
        tripsIxByRoute[routeID] = list;
      }

      list.Add(i);
      i++;
    } while (!reader.EndOfStream);

    return (trips, tripsIxByRoute);
  }

  public static (List<StopTime> stopTimes, Dictionary<string, List<int>> stopTimesIxByTrip) LoadStopTimes()
  {
    var watch = new Stopwatch();

    using var f = File.OpenRead(@"../MBTA_GTFS/stop_times.txt");
    using var reader = new StreamReader(f);

    watch.Start();
    string[] header = reader.ReadLine().Split(",");

    Debug.Assert(header[0] == "trip_id");
    Debug.Assert(header[1] == "arrival_time");
    Debug.Assert(header[2] == "departure_time");
    Debug.Assert(header[3] == "stop_id");

    var stopTimes = new List<StopTime>(2_000_000);
    var stopTimesIxByTrip = new Dictionary<string, List<int>>(100_000);

    int i = 0;
    do
    {
      var line = reader.ReadLine().AsSpan();

      var parts = line.Split(',');
      parts.MoveNext();
      string tripID = new string(parts.CurrentValue);

      parts.MoveNext();
      string arrival = new string(parts.CurrentValue);

      parts.MoveNext();
      string departure = new string(parts.CurrentValue);

      parts.MoveNext();
      string stopID = new string(parts.CurrentValue);

      stopTimes.Add(new StopTime(tripID, stopID, arrival, departure));

      if (!stopTimesIxByTrip.TryGetValue(tripID, out var list))
      {
        list = new List<int>();
        stopTimesIxByTrip[tripID] = list;
      }

      list.Add(i);
    } while (!reader.EndOfStream);

    watch.Stop();

    Console.WriteLine($"loaded stop_times.txt in {watch.ElapsedMilliseconds} ms");

    return (stopTimes, stopTimesIxByTrip);
  }
}
