namespace Trannet.Services;

public static class GTFSService
{
    private static List<Trip> Trips { get; }
    private static Dictionary<string, List<int>> TripsIxByRoute { get; }
    private static List<StopTime> StopTimes { get; }
    private static Dictionary<string, List<int>> StopTimesIxByTrip { get; }

    static GTFSService()
    {
        (Trips, TripsIxByRoute) = GTFS.LoadTrips();
        (StopTimes, StopTimesIxByTrip) = GTFS.LoadStopTimes();
    }

    public static List<TripResponse> SchedulesForRoute(string route)
    {
        var trips = new List<TripResponse>();
        
        if (TripsIxByRoute.TryGetValue(route, out var tripIxs))
        {
            foreach (int tripIx in tripIxs)
            {
                var trip = Trips[tripIx];
                var stopTimeIxs = StopTimesIxByTrip[trip.TripID];
                var schedules = new List<StopTimeResponse>();
                foreach (int stopTimeIx in stopTimeIxs)
                {
                    var stopTime = StopTimes[stopTimeIx];
                    schedules.Add(new StopTimeResponse(stopTime.StopID, stopTime.Arrival, stopTime.Departure));
                }
                trips.Add(new TripResponse(trip.TripID, trip.RouteID, trip.ServiceID, schedules));
            }
        }

        return trips;
    }

    internal static void EnsureLoaded()
    {
        //Will make sure the static constructor is called
        Console.WriteLine("Loaded");
        //Force-free any memory allocated during initialization
        GC.Collect(2);
    }
}
