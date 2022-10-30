using System.Diagnostics;

namespace Trannet.Benchmark.TrannetVersions._02_ListAndDictionaryUse;

class GTFS
{
    private const string RootDir = ".";
    public static (List<Trip>, Dictionary<string, List<int>>) LoadTrips()
    {
        string[] lines = System.IO.File.ReadAllLines(Path.Join(RootDir, "MBTA_GTFS", "/trips.txt"));
        string[] header = lines[0].Split(",");
        Debug.Assert(header[0] == "route_id");
        Debug.Assert(header[1] == "service_id");
        Debug.Assert(header[2] == "trip_id");

        var trips = new List<Trip>(lines.Length);
        var tripsIxByRoute = new Dictionary<string, List<int>>(100_000);

        for (var i = 1; i < lines.Length; i++)
        {
            var line = lines[i];

            string[] cells = line.Split(',', 4);
            string routeID = cells[0];
            trips.Add(new Trip(cells[2], routeID, cells[1]));

            if (tripsIxByRoute.TryGetValue(routeID, out var list))
            {
                list.Add(i);
            }
            else
            {
                tripsIxByRoute.Add(routeID, new List<int> { i });
            }
            
        }

        return (trips, tripsIxByRoute);
    }

    public static (List<StopTime>, Dictionary<string, List<int>>) LoadStopTimes()
    {
        var watch = new System.Diagnostics.Stopwatch();
        watch.Start();
        string[] lines = System.IO.File.ReadAllLines(Path.Join(RootDir, "MBTA_GTFS", "stop_times.txt"));
        string[] header = lines[0].Split(",");
        Debug.Assert(header[0] == "trip_id");
        Debug.Assert(header[1] == "arrival_time");
        Debug.Assert(header[2] == "departure_time");
        Debug.Assert(header[3] == "stop_id");

        var stopTimes = new List<StopTime>(lines.Length);
        var stopTimesIxByTrip = new Dictionary<String, List<int>>(100_000);

        for (var i = 1; i < lines.Length; i++)
        {
            var line = lines[i];
            string[] cells = line.Split(',', 5);
            var tripID = cells[0];
            stopTimes.Add(new StopTime(tripID, cells[3], cells[1], cells[2]));

            if (stopTimesIxByTrip.TryGetValue(tripID, out var list))
            {
                list.Add(i);
            }
            else
            {
                stopTimesIxByTrip.Add(tripID, new List<int> { i });
            }
        }

        watch.Stop();
        //Console.WriteLine($"loaded stop_times.txt in {watch.ElapsedMilliseconds} ms");
        return (stopTimes, stopTimesIxByTrip);
    }
}
