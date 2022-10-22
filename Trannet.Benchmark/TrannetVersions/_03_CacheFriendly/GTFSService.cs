
namespace Trannet.Benchmark.TrannetVersions._03_CacheFriendly;

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
        var trips = new List<TripResponse>();
        if (TripsIxByRoute.ContainsKey(route))
        {
            var tripIxs = TripsIxByRoute[route];
            foreach (int tripIx in tripIxs)
            {
                Trip trip = Trips[tripIx];
                var stopTimeIxs = StopTimesIxByTrip[trip.TripID];
                var schedules = new List<StopTimeResponse>();
                foreach (int stopTimeIx in stopTimeIxs)
                {
                    StopTime stopTime = StopTimes[stopTimeIx];
                    schedules.Add(new StopTimeResponse(stopTime.StopID, stopTime.Arrival, stopTime.Departure));
                }
                trips.Add(new TripResponse(trip.TripID, trip.RouteID, trip.ServiceID, schedules));
            }
        }
        return trips;
    }
}