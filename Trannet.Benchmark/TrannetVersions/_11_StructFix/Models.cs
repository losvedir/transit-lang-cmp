namespace Trannet.Benchmark.TrannetVersions._11_StructFix;

public readonly struct StopTime
{
    public StopTime(string tripID, string stopID, string arrival, string departure)
    {
        TripID = tripID;
        StopID = stopID;
        Arrival = arrival;
        Departure = departure;
    }

    public readonly string TripID;
    public readonly string StopID;
    public readonly string Arrival;
    public readonly string Departure;
}
public readonly struct StopTimeResponse
{
    public readonly string stop_id;
    public readonly string arrival_time;
    public readonly string departure_time;

    public StopTimeResponse(ref StopTime stopTime)
    {
        stop_id = stopTime.StopID;
        arrival_time = stopTime.Arrival;
        departure_time = stopTime.Departure;
    }
}

public readonly struct Trip
{
    public Trip(string tripID, string routeID, string serviceID)
    {
        TripID = tripID;
        RouteID = routeID;
        ServiceID = serviceID;
    }

    public readonly string TripID;
    public readonly string RouteID;
    public readonly string ServiceID;
}

public class TripResponse
{
    public readonly string trip_id;
    public readonly string route_id;
    public readonly string service_id;
    public readonly List<StopTimeResponse> schedules;
    public TripResponse(ref Trip trip, List<StopTimeResponse> stop_time_responses)
    {
        trip_id = trip.TripID;
        route_id = trip.RouteID;
        service_id = trip.ServiceID;
        schedules = stop_time_responses;
    }
}