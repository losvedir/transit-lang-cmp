using System.Diagnostics;
using Sylvan.Data.Csv;

var gtfs = new GTFSService();

var app = WebApplication.Create();
app.MapGet("/", () => $"ASP.NET ({Environment.Version}) minimal transit data API.");
app.MapGet("/schedules/{routeId}", (string routeId) => gtfs.GetRoute(routeId)?.Trips);
app.Run();

class Route
{
    public Route()
    {
        this.Trips = new List<Trip>();
    }

    public List<Trip> Trips { get; }
}

record Trip(
    string trip_id,
    string route_id,
    string service_id,
    List<StopTime> Schedules
);

record StopTime(
    string stop_id,
    string arrival,
    string departure
);

class GTFSService
{
    readonly Dictionary<string, Route> routes;

    public Route? GetRoute(string route)
    {
        return routes.GetValueOrDefault(route);
    }

    public GTFSService()
    {
        this.routes = new Dictionary<string, Route>(StringComparer.OrdinalIgnoreCase);
        var trips = new Dictionary<string, Trip>();

        using var tripData = CsvDataReader.Create(@"../MBTA_GTFS/trips.txt");
        while (tripData.Read())
        {
            var routeId = tripData.GetString(0);
            var serviceId = tripData.GetString(1);
            var tripId = tripData.GetString(2);

            var trip = new Trip(tripId, routeId, serviceId, new List<StopTime>());
            trips.Add(tripId, trip);

            if (!routes.TryGetValue(routeId, out var route))
            {
                route = new Route();
                routes.Add(routeId, route);
            }
            route.Trips.Add(trip);
        }

        var sw = Stopwatch.StartNew();
        using var stopData = CsvDataReader.Create(@"../MBTA_GTFS/stop_times.txt");
        while (stopData.Read())
        {
            var tripId = stopData.GetString(0);
            var arrival = stopData.GetString(1);
            var departure = stopData.GetString(2);
            var stopId = stopData.GetString(3);

            var stop = new StopTime(stopId, arrival, departure);

            if (trips.TryGetValue(tripId, out var trip))
            {
                trip.Schedules.Add(stop);
            }
            else
            {
                throw new InvalidDataException();
            }
        }
        sw.Stop();
        Console.WriteLine($"Loaded stop_times.txt in {sw.ElapsedMilliseconds} ms.");
    }
}
