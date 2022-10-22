using System.Runtime.InteropServices;
using System.Linq;

namespace Trannet.Benchmark.TrannetVersions._11_StructFix;

public static class GTFSService
{
    static List<Trip> Trips { get; }
    static Dictionary<string, List<int>> TripsIxByRoute { get; }
    static List<StopTime> StopTimes { get; }
    static Dictionary<string, List<int>> StopTimesIxByTrip { get; }

    static GTFSService()
    {
        (Trips, TripsIxByRoute) = GTFS.LoadTrips();
        (StopTimes, StopTimesIxByTrip) = GTFS.LoadStopTimes();
    }

    public static List<TripResponse> SchedulesForRoute(string route)
    {
        var ret = new List<TripResponse>(10_000);
        if (TripsIxByRoute.TryGetValue(route, out var tripIxs))
        {
            var stopTimes = CollectionsMarshal.AsSpan(StopTimes);
            var trips = CollectionsMarshal.AsSpan(Trips);

            foreach (var tripIx in CollectionsMarshal.AsSpan(tripIxs))
            {
                ref var trip = ref trips[tripIx];
                var stopTimeIxs = StopTimesIxByTrip[trip.TripID];

                var schedules = new List<StopTimeResponse>(stopTimeIxs.Count);
                foreach (int stopTimeIx in CollectionsMarshal.AsSpan(stopTimeIxs))
                {
                    schedules.Add(new StopTimeResponse(ref stopTimes[stopTimeIx]));
                }

                ret.Add(new TripResponse(ref trip, schedules));
            }
        }
        return ret;
    }
}