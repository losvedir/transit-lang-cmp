using System.Diagnostics;
using System.Text;

namespace Trannet.Benchmark.TrannetVersions._11_StructFix;

class GTFS
{
    private const string RootDir = ".";
    public static (List<Trip>, Dictionary<string, List<int>>) LoadTrips()
    {
        var trips = new List<Trip>();
        var tripsIxByRoute = new Dictionary<string, List<int>>();
        using var fs = File.Open(Path.Join(RootDir, "MBTA_GTFS", "/trips.txt"), FileMode.Open, FileAccess.Read, FileShare.Read);
        using var reader = new StreamReader(fs, Encoding.ASCII);

        string line = reader.ReadLine();
        string[] header = line.Split(",");
        Debug.Assert(header[0] == "route_id");
        Debug.Assert(header[1] == "service_id");
        Debug.Assert(header[2] == "trip_id");

        // Process the lines in a stream instead of loading all up front, this way we utilize the processor cache better
        while ((line = reader.ReadLine()) != null)
        {
            string[] cells = line.Split(',', 4);
            string routeID = cells[0];
            trips.Add(new Trip(cells[2], routeID, cells[1]));

            if (tripsIxByRoute.TryGetValue(routeID, out var list))
            {
                list.Add(trips.Count - 1);
            }
            else
            {
                tripsIxByRoute.Add(routeID, new List<int> { trips.Count - 1 });
            }
        }


        return (trips, tripsIxByRoute);
    }

    public static (List<StopTime>, Dictionary<string, List<int>>) LoadStopTimes()
    {
        var stopTimes = new List<StopTime>();
        var stopTimesIxByTrip = new Dictionary<String, List<int>>();
        using var fs = File.Open(Path.Join(RootDir, "MBTA_GTFS", "/stop_times.txt"), FileMode.Open, FileAccess.Read, FileShare.Read);
        using var reader = new StreamReader(fs, Encoding.ASCII);

        string line = reader.ReadLine();
        string[] header = line.Split(",");
        Debug.Assert(header[0] == "trip_id");
        Debug.Assert(header[1] == "arrival_time");
        Debug.Assert(header[2] == "departure_time");
        Debug.Assert(header[3] == "stop_id");

        // Process the lines in a stream instead of loading all up front, this way we utilize the processor cache better
        while ((line = reader.ReadLine()) != null)
        {
            string[] cells = line.Split(',', 5);
            var tripID = cells[0];
            stopTimes.Add(new StopTime(tripID, cells[3], cells[1], cells[2]));

            if (stopTimesIxByTrip.TryGetValue(tripID, out var list))
            {
                list.Add(stopTimes.Count - 1);
            }
            else
            {
                stopTimesIxByTrip.Add(tripID, new List<int> { stopTimes.Count - 1 });
            }
        }



        //var watch = new System.Diagnostics.Stopwatch();
        //watch.Start();
        //string[] lines = System.IO.File.ReadAllLines(Path.Join(RootDir, "MBTA_GTFS", "stop_times.txt"));
        //string[] header = lines[0].Split(",");
        //Debug.Assert(header[0] == "trip_id");
        //Debug.Assert(header[1] == "arrival_time");
        //Debug.Assert(header[2] == "departure_time");
        //Debug.Assert(header[3] == "stop_id");

        //var stopTimes = new List<StopTime>(lines.Length);
        //var stopTimesIxByTrip = new Dictionary<String, List<int>>(100_000);

        //for (var i = 1; i < lines.Length; i++)
        //{
        //    var line = lines[i];
        //    string[] cells = line.Split(',', 5);
        //    var tripID = cells[0];
        //    stopTimes.Add(new StopTime(tripID, cells[3], cells[1], cells[2]));

        //    if (stopTimesIxByTrip.TryGetValue(tripID, out var list))
        //    {
        //        list.Add(i);
        //    }
        //    else
        //    {
        //        stopTimesIxByTrip.Add(tripID, new List<int> { i });
        //    }
        //}

        //watch.Stop();
        ////Console.WriteLine($"loaded stop_times.txt in {watch.ElapsedMilliseconds} ms");
        //Console.WriteLine(stopTimesIxByTrip.Count);
        return (stopTimes, stopTimesIxByTrip);
    }
}
