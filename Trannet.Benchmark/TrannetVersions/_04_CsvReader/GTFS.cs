using System.Data;
using System.Diagnostics;
using System.Text;

using Sylvan.Data.Csv;

namespace Trannet.Benchmark.TrannetVersions._04_CsvReader;

class GTFS
{
    private const string RootDir = ".";
    public static (List<Trip>, Dictionary<string, List<int>>) LoadTrips()
    {
        var trips = new List<Trip>();
        var tripsIxByRoute = new Dictionary<string, List<int>>();
        var filename = Path.Join(RootDir, "MBTA_GTFS", "/trips.txt");
        var opts = new CsvDataReaderOptions { HasHeaders = true, Delimiter = ',', Culture = new System.Globalization.CultureInfo("en-US") };
        var csv = CsvDataReader.Create(filename, opts);
        csv.Read();

        // Process the lines in a stream instead of loading all up front, this way we utilize the processor cache better
        // Use CSV library that specializes in CSV handling
        while (csv.Read())
        {
            string routeID = csv.GetString(0);
            trips.Add(new Trip(csv.GetString(2), routeID, csv.GetString(1)));

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
        var filename = Path.Join(RootDir, "MBTA_GTFS", "/stop_times.txt");
        var opts = new CsvDataReaderOptions { HasHeaders = true, Delimiter = ',', Culture = new System.Globalization.CultureInfo("en-US") };
        var csv = CsvDataReader.Create(filename, opts);
        csv.Read();

        // Process the lines in a stream instead of loading all up front, this way we utilize the processor cache better
        // Use CSV library that specializes in CSV handling
        while (csv.Read())
        {

            var tripID = csv.GetString(0);
            stopTimes.Add(new StopTime(tripID, csv.GetString(3), csv.GetString(1), csv.GetString(2)));

            if (stopTimesIxByTrip.TryGetValue(tripID, out var list))
            {
                list.Add(stopTimes.Count - 1);
            }
            else
            {
                stopTimesIxByTrip.Add(tripID, new List<int> { stopTimes.Count - 1 });
            }
        }
        csv.Close();

        return (stopTimes, stopTimesIxByTrip);
    }
}
