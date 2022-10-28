using Sylvan.Data.Csv;
using System.Diagnostics;

var builder = WebApplication.CreateBuilder(args);
builder.Services.AddControllers();
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();
var app = builder.Build();

if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

app.UseAuthorization();

var (Trips, TripsIxByRoute) = LoadTrips();
var (StopTimes, StopTimesIxByTrip) = LoadStopTimes();

app.MapGet("/schedules/{routeId}", (string routeId) =>
    {
        var trips = new List<TripResponse>();
        if (TripsIxByRoute.ContainsKey(routeId))
        {
            var tripIxs = TripsIxByRoute[routeId];
            trips.Capacity = tripIxs.Count;
            foreach (var tripIx in tripIxs)
            {
                var trip = Trips[tripIx];
                var stopTimeIxs = StopTimesIxByTrip[trip.TripID];
                var schedules = new List<StopTimeResponse>(stopTimeIxs.Count);
                foreach (var stopTimeIx in stopTimeIxs)
                {
                    var stopTime = StopTimes[stopTimeIx];
                    schedules.Add(new StopTimeResponse(stopTime.StopID, stopTime.Arrival, stopTime.Departure));
                }
                trips.Add(new TripResponse(trip.TripID, trip.RouteID, trip.ServiceID, schedules));
            }
        }
        else
        {
            trips = new List<TripResponse>();
        }
        return trips;
    }
);

app.Run();

static (List<Trip>, Dictionary<string, List<int>>) LoadTrips()
{
    var watch = Stopwatch.StartNew();
    using var csvReader = CsvDataReader.Create(@"../MBTA_GTFS/trips.txt");
    csvReader.Read();
    Debug.Assert(csvReader.GetString(0) == "route_id");
    Debug.Assert(csvReader.GetString(1) == "service_id");
    Debug.Assert(csvReader.GetString(2) == "trip_id");

    var trips = new List<Trip>(80_000);
    var tripsIxByRoute = new Dictionary<string, List<int>>();

    var i = 0;
    while (csvReader.Read())
    {
        string routeID = csvReader.GetString(0);
        trips.Add(new Trip(csvReader.GetString(2), routeID, csvReader.GetString(1)));

        if (tripsIxByRoute.ContainsKey(routeID))
        {
            tripsIxByRoute[routeID].Add(i);
        }
        else
        {
            tripsIxByRoute.Add(routeID, new List<int> { i });
        }

        i++;
    }
    watch.Stop();
    Console.WriteLine($"loaded {trips.Count} trips.txt in {watch.ElapsedMilliseconds} ms");

    return (trips, tripsIxByRoute);
}

static (List<StopTime>, Dictionary<string, List<int>>) LoadStopTimes()
{
    var watch = Stopwatch.StartNew();
    using var csvReader = CsvDataReader.Create(@"../MBTA_GTFS/stop_times.txt");
    csvReader.Read();
    Debug.Assert(csvReader.GetString(0) == "trip_id");
    Debug.Assert(csvReader.GetString(1) == "arrival_time");
    Debug.Assert(csvReader.GetString(2) == "departure_time");
    Debug.Assert(csvReader.GetString(3) == "stop_id");

    var stopTimes = new List<StopTime>(2_000_000);
    var stopTimesIxByTrip = new Dictionary<string, List<int>>();

    int i = 0;
    while (csvReader.Read())
    {
        var tripID = csvReader.GetString(0)!;
        stopTimes.Add(new StopTime(tripID, csvReader.GetString(3), csvReader.GetString(1), csvReader.GetString(2)));

        if (!stopTimesIxByTrip.TryGetValue(tripID, out var list))
        {
            list = new List<int>();
            stopTimesIxByTrip.Add(tripID, list);
        }
        list.Add(i);

        i++;
    }

    watch.Stop();
    Console.WriteLine($"loaded {stopTimes.Count} stop_times.txt in {watch.ElapsedMilliseconds} ms");
    return (stopTimes, stopTimesIxByTrip);
}

public record struct StopTimeResponse(string stop_id, string arrival_time, string departure_time);
public record struct TripResponse(string trip_id, string route_id, string service_id, List<StopTimeResponse> schedules);
public record struct Trip(string TripID, string RouteID, string ServiceID);
public record struct StopTime(string TripID, string StopID, string Arrival, string Departure);